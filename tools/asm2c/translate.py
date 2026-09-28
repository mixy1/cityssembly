#!/usr/bin/env python3
"""
asm2c - static translation of CITYSSEMBLY's x86-64 object file into C.

The game is assembled by NASM exactly as for Linux (ELF64 relocatable,
SysV calling convention). This tool reads that object file - code, data,
symbols and relocations - and emits C that behaves the same:

  * every region between two non-local .text symbols becomes a C function;
    registers live in locals (so the compiler can keep them in registers)
    and are written back to the global CPU state around calls - only the
    ones the callee (or anything it calls) can read before the call, and
    only the ones it can write after (see Translator.finish)
  * a function's own stack locals ([rbp - n] of its frame) live in C
    locals too when nothing else can reach them (see frame_plan)
  * flags are kept lazily (last operation + operands) and only evaluated
    by the instruction that reads them
  * the stack is an emulated byte array with the same layout as native
    (every call pushes a return slot), so rbp/rsp arithmetic is unchanged
  * data keeps NASM's exact layout; pointers inside data are relocated at
    start-up; code addresses become small ids dispatched through switches
  * calls to SDL / libc go to wrappers in web/runtime.c

Usage: translate.py build/web.o build/web/game.c
"""
import sys, collections
from elftools.elf.elffile import ELFFile
from elftools.elf.relocation import RelocationSection
from capstone import Cs, CS_ARCH_X86, CS_MODE_64
from capstone import x86_const as X

# ---------------------------------------------------------------------------
REG64 = ['rax', 'rcx', 'rdx', 'rbx', 'rsp', 'rbp', 'rsi', 'rdi',
         'r8', 'r9', 'r10', 'r11', 'r12', 'r13', 'r14', 'r15']
RSP = 4
SUB = {}
for i, n in enumerate(REG64):
    SUB[n] = (i, 64, 0)
for i, (d, w, b) in enumerate([('eax', 'ax', 'al'), ('ecx', 'cx', 'cl'), ('edx', 'dx', 'dl'),
                              ('ebx', 'bx', 'bl'), ('esp', 'sp', 'spl'), ('ebp', 'bp', 'bpl'),
                              ('esi', 'si', 'sil'), ('edi', 'di', 'dil')]):
    SUB[d] = (i, 32, 0); SUB[w] = (i, 16, 0); SUB[b] = (i, 8, 0)
SUB['ah'] = (0, 8, 8); SUB['ch'] = (1, 8, 8); SUB['dh'] = (2, 8, 8); SUB['bh'] = (3, 8, 8)
for i in range(8, 16):
    SUB[f'r{i}d'] = (i, 32, 0); SUB[f'r{i}w'] = (i, 16, 0); SUB[f'r{i}b'] = (i, 8, 0)

UT = {8: 'uint8_t', 16: 'uint16_t', 32: 'uint32_t', 64: 'uint64_t'}
ST = {8: 'int8_t', 16: 'int16_t', 32: 'int32_t', 64: 'int64_t'}

CC = {  # condition suffix -> expression over lazy flags
    'e': 'ZF', 'z': 'ZF', 'ne': '!ZF', 'nz': '!ZF',
    'l': '(SF!=OF)', 'nge': '(SF!=OF)', 'ge': '(SF==OF)', 'nl': '(SF==OF)',
    'le': '(ZF||(SF!=OF))', 'ng': '(ZF||(SF!=OF))', 'g': '(!ZF&&(SF==OF))', 'nle': '(!ZF&&(SF==OF))',
    'b': 'CF', 'c': 'CF', 'nae': 'CF', 'ae': '!CF', 'nb': '!CF', 'nc': '!CF',
    'be': '(CF||ZF)', 'na': '(CF||ZF)', 'a': '(!CF&&!ZF)', 'nbe': '(!CF&&!ZF)',
    's': 'SF', 'ns': '!SF', 'o': 'OF', 'no': '!OF', 'p': 'PF', 'np': '!PF',
}


class TranslateError(Exception):
    pass


# ---------------------------------------------------------------------------
class Obj:
    def __init__(self, path):
        self.f = ELFFile(open(path, 'rb'))
        self.secs = list(self.f.iter_sections())
        self.text = self.f.get_section_by_name('.text')
        self.data = self.f.get_section_by_name('.data')
        self.bss = self.f.get_section_by_name('.bss')
        self.idx = {s.name: i for i, s in enumerate(self.secs)}
        st = self.f.get_section_by_name('.symtab')
        self.syms = list(st.iter_symbols())
        self.relocs = {}          # section name -> {offset: (type, sym, addend)}
        for s in self.secs:
            if isinstance(s, RelocationSection):
                target = self.secs[s['sh_info']].name
                d = {}
                for r in s.iter_relocations():
                    d[r['r_offset']] = (r['r_info_type'], self.syms[r['r_info_sym']], r['r_addend'])
                self.relocs[target] = d

    def sec_name(self, shndx):
        if isinstance(shndx, str):
            return shndx
        return self.secs[shndx].name


# ---------------------------------------------------------------------------
class Translator:
    def __init__(self, obj):
        self.o = obj
        self.md = Cs(CS_ARCH_X86, CS_MODE_64)
        self.md.detail = True
        self.code = self.o.text.data()
        self.insns = list(self.md.disasm(self.code, 0))
        self.at = {i.address: k for k, i in enumerate(self.insns)}
        self.text_idx = self.o.idx['.text']
        # symbols in .text
        tsyms = [(s['st_value'], s.name) for s in self.o.syms
                 if s['st_shndx'] == self.text_idx and s.name and s['st_info']['type'] != 'STT_SECTION']
        tsyms.sort()
        self.label_at = {}
        for v, n in tsyms:
            self.label_at.setdefault(v, n)
        # function regions: non-local symbols
        starts = sorted(set(v for v, n in tsyms if '.' not in n))
        if 0 not in starts:
            starts.insert(0, 0)
        self.regions = []
        for k, s in enumerate(starts):
            e = starts[k + 1] if k + 1 < len(starts) else len(self.code)
            self.regions.append((s, e, self.label_at.get(s, f'sub_{s:x}')))
        self.region_of = {}
        for s, e, n in self.regions:
            self.region_of[s] = (s, e, n)
        self.entry_names = {s: self.cname(n) for s, e, n in self.regions}
        # code ids: .text offsets whose address is taken (data or imm relocs)
        self.code_ids = {}
        for sec in ('.data', '.text'):
            for off, (typ, sym, add) in self.o.relocs.get(sec, {}).items():
                if sym['st_shndx'] == self.text_idx and sec == '.data':
                    self.code_id(sym['st_value'] + add)
        self.externs = set()
        self.helpers = []
        self.info = {}      # per function: registers, calls (see finish)

    def cname(self, n):
        return 'F_' + ''.join(c if c.isalnum() else '_' for c in n)

    def code_id(self, off):
        if off not in self.code_ids:
            self.code_ids[off] = len(self.code_ids) + 1
        return self.code_ids[off]

    def region_for(self, off):
        for s, e, n in self.regions:
            if s <= off < e:
                return (s, e, n)
        raise TranslateError(f'no region for {off:x}')

    # ------------------------------------------------------------ symbols
    def sym_addr(self, sym, add):
        """C expression for the address sym+add (data) or a code id."""
        shn = sym['st_shndx']
        if shn == 'SHN_UNDEF':
            raise TranslateError(f'address of extern {sym.name}')
        sec = self.o.sec_name(shn)
        val = sym['st_value'] + add
        if sec == '.data':
            return f'(D_BASE+{val}ull)'
        if sec == '.bss':
            return f'(B_BASE+{val}ull)'
        if sec == '.text':
            return f'{self.code_id(val)}ull'
        raise TranslateError(f'symbol in {sec}')

    def reloc_in(self, ins, lo, hi):
        r = self.o.relocs.get('.text', {})
        for off in range(ins.address + lo, ins.address + hi):
            if off in r:
                return r[off]
        return None

    # ------------------------------------------------------------ operands
    def reg(self, name):
        if name not in SUB:
            raise TranslateError(f'register {name}')
        return SUB[name]

    def rd_reg(self, name):
        i, w, sh = self.reg(name)
        self.used.add(i)
        if w == 64:
            return f'r{i}'
        if sh:
            return f'(uint8_t)(r{i}>>8)'
        return f'({UT[w]})r{i}'

    def wr_reg(self, name, val):
        i, w, sh = self.reg(name)
        self.used.add(i)
        self.written.add(i)
        if w == 64:
            return f'r{i} = (uint64_t)({val});'
        if w == 32:
            return f'r{i} = (uint32_t)({val});'
        if sh:
            return f'r{i} = (r{i} & ~0xff00ull) | ((uint64_t)(uint8_t)({val}) << 8);'
        m = (1 << w) - 1
        return f'r{i} = (r{i} & ~{m:#x}ull) | (uint64_t)({UT[w]})({val});'

    def mem_addr(self, ins, op):
        m = op.mem
        parts = []
        if m.base:
            bn = ins.reg_name(m.base)
            if bn == 'rip':
                raise TranslateError('rip-relative')
            parts.append(self.rd_reg(bn))
        if m.index:
            parts.append(f'{self.rd_reg(ins.reg_name(m.index))}*{m.scale}')
        enc = ins.disp_offset
        rel = None
        if enc:
            rel = self.reloc_in(ins, enc, enc + ins.disp_size)
        if rel:
            typ, sym, add = rel
            parts.append(self.sym_addr(sym, add))
        elif m.disp:
            parts.append(f'(uint64_t)({m.disp}ll)')
        if not parts:
            return '0ull'
        return '(' + '+'.join(parts) + ')'

    def imm(self, ins, op, size):
        if ins.imm_offset:
            rel = self.reloc_in(ins, ins.imm_offset, ins.imm_offset + ins.imm_size)
            if rel:
                typ, sym, add = rel
                return self.sym_addr(sym, add)
        v = op.imm & ((1 << size) - 1)
        return f'{v:#x}ull'

    def rd(self, ins, op, size=None):
        size = size or op.size * 8
        if op.type == X.X86_OP_REG:
            return self.rd_reg(ins.reg_name(op.reg))
        if op.type == X.X86_OP_IMM:
            return self.imm(ins, op, size)
        if op.type == X.X86_OP_MEM:
            sl = self.slot(ins, op)
            if sl is not None:
                if size != sl[1]:
                    raise TranslateError('slot size')
                return f'({UT[size]})S{sl[0]}'
            return f'LD{size}({self.mem_addr(ins, op)})'
        raise TranslateError('operand')

    def wr(self, ins, op, val, size=None):
        size = size or op.size * 8
        if op.type == X.X86_OP_REG:
            return self.wr_reg(ins.reg_name(op.reg), val)
        if op.type == X.X86_OP_MEM:
            sl = self.slot(ins, op)
            if sl is not None:
                if size != sl[1]:
                    raise TranslateError('slot size')
                return f'S{sl[0]} = ({UT[size]})({val});'
            return f'ST{size}({self.mem_addr(ins, op)}, {val});'
        raise TranslateError('write operand')

    def xreg(self, ins, op):
        n = ins.reg_name(op.reg)
        if not n.startswith('xmm'):
            raise TranslateError(f'xmm {n}')
        k = int(n[3:])
        self.xused.add(k)
        return f'x{k}'

    def slot(self, ins, op):
        """(name, bits) if this memory operand is a promoted frame slot"""
        if not self.slots or not op.mem.base or op.mem.index:
            return None
        if ins.reg_name(op.mem.base) != 'rbp':
            return None
        d = op.mem.disp
        if d in self.slots:
            return (-d, self.slots[d])
        return None

    SLOT_OPS = {'mov', 'movzx', 'movsx', 'movsxd', 'add', 'sub', 'cmp', 'and', 'or', 'xor', 'test',
                'inc', 'dec', 'neg', 'not', 'imul', 'shl', 'shr', 'sar', 'sal', 'div', 'idiv', 'mul',
                'xchg', 'push', 'pop'}

    def frame_plan(self, s, e):
        """The stack slots of a function's frame that can live in C locals:
        the function builds a frame (push rbp; mov rbp, rsp), rbp never
        escapes (no copies, no lea of a local, no rsp-relative memory), and
        every access to the slot is a plain read or write of one size that
        no other access overlaps.  -> {disp: bits}, or {} for none"""
        insns = []
        k = self.at[s]
        while k < len(self.insns) and self.insns[k].address < e:
            insns.append(self.insns[k])
            k += 1
        if len(insns) < 2 or insns[0].mnemonic != 'push' or insns[0].op_str != 'rbp' \
                or insns[1].mnemonic != 'mov' or insns[1].op_str != 'rbp, rsp':
            return {}
        acc = collections.defaultdict(set)     # disp -> {bits}
        bad = set()
        spans = []                              # (lo, hi) of every frame access
        for idx, ins in enumerate(insns):
            m = ins.mnemonic
            for op in ins.operands:
                if op.type == X.X86_OP_REG and ins.reg_name(op.reg) in ('rbp', 'ebp', 'bp', 'bpl'):
                    if (idx == 0 and m == 'push') or (idx == 1 and m == 'mov') or m == 'pop':
                        continue
                    return {}
                if op.type != X.X86_OP_MEM or not op.mem.base:
                    continue
                bn = ins.reg_name(op.mem.base)
                if bn in ('rsp', 'esp'):
                    return {}
                if bn != 'rbp':
                    continue
                if op.mem.index:
                    return {}
                if m == 'lea':
                    if ins.op_str == 'rsp, [rbp - 0x28]':
                        continue
                    return {}
                d = op.mem.disp
                spans.append((d, d + op.size))
                if d > -44 or m not in self.SLOT_OPS:
                    bad.add(d)
                else:
                    acc[d].add(op.size * 8)
        slots = {}
        for d, sizes in acc.items():
            if d in bad or len(sizes) != 1:
                continue
            w = next(iter(sizes))
            lo, hi = d, d + w // 8
            if any(a != d and a < hi and b > lo for a, b in spans):
                continue
            if any(a == d and b != hi for a, b in spans):
                continue
            slots[d] = w
        return slots

    def slot_spill(self):
        return ' '.join(f'ST{w}(r5+(uint64_t)({d}ll), S{-d});' for d, w in sorted(self.slots.items()))

    def slot_reload(self):
        return ' '.join(f'S{-d} = LD{w}(r5+(uint64_t)({d}ll));' for d, w in sorted(self.slots.items()))

    def implicit(self, *regs):
        """registers an instruction reads and writes without naming them"""
        self.used.update(regs)
        self.written.update(regs)

    # ------------------------------------------------------------ flags
    def flags(self, op, size, a, b, r):
        return (f'fop = {op}; fsz = {size}; fa = (uint64_t)({a}); '
                f'fb = (uint64_t)({b}); fr = (uint64_t)({r});')

    # ------------------------------------------------------------ control
    def spill(self):
        s = ' '.join(f'R.r[{i}] = r{i};' for i in sorted(self.used))
        s += ' ' + ' '.join(f'R.x[{k}] = x{k};' for k in sorted(self.xused))
        s += ' R.fop = fop; R.fsz = fsz; R.fa = fa; R.fb = fb; R.fr = fr;'
        return s

    def reload(self):
        s = ' '.join(f'r{i} = R.r[{i}];' for i in sorted(self.used))
        s += ' ' + ' '.join(f'x{k} = R.x[{k}];' for k in sorted(self.xused))
        s += ' fop = R.fop; fsz = R.fsz; fa = R.fa; fb = R.fb; fr = R.fr;'
        return s

    def goto_or_tail(self, target, region):
        s, e, n = region
        if s < target < e or (target == s and self.self_loop_ok):
            self.targets.add(target)
            return f'goto L_{target:x};'
        if target in self.entry_names:
            self.calls.add(target)
            return f'{{ SPILL; {self.entry_names[target]}(); return; }}'
        raise TranslateError(f'jump into another function at {target:x} ({self.label_at.get(target)})')

    # ------------------------------------------------------------ one insn
    def insn(self, ins, region):
        m = ins.mnemonic
        ops = ins.operands
        s, e, name = region
        o0 = ops[0] if len(ops) > 0 else None
        o1 = ops[1] if len(ops) > 1 else None

        def sz(op):
            return op.size * 8

        # ---- data movement
        if m in ('mov', 'movabs'):
            if o0.type == X.X86_OP_REG and ins.reg_name(o0.reg).startswith('xmm'):
                raise TranslateError('mov xmm')
            return self.wr(ins, o0, self.rd(ins, o1, sz(o0)))
        if m == 'movzx':
            return self.wr(ins, o0, self.rd(ins, o1))
        if m in ('movsx', 'movsxd'):
            return self.wr(ins, o0, f'(int64_t)({ST[sz(o1)]})({self.rd(ins, o1)})')
        if m == 'lea':
            return self.wr(ins, o0, self.mem_addr(ins, o1))
        if m == 'push':
            v = self.rd(ins, o0, 64)
            if o0.type == X.X86_OP_IMM:
                v = f'(uint64_t)(int64_t)(int32_t)({v})'
            self.implicit(RSP)
            return f'{{ uint64_t _v = {v}; r4 -= 8; ST64(r4, _v); }}'
        if m == 'pop':
            self.implicit(RSP)
            return f'{{ uint64_t _v = LD64(r4); r4 += 8; {self.wr(ins, o0, "_v", 64)} }}'
        if m == 'xchg':
            a = self.rd(ins, o0); b = self.rd(ins, o1)
            return f'{{ uint64_t _a = {a}, _b = {b}; {self.wr(ins, o0, "_b")} {self.wr(ins, o1, "_a")} }}'
        if m == 'cdq':
            self.implicit(0, 2)
            return 'r2 = (uint32_t)((int32_t)(uint32_t)r0 >> 31);'
        if m == 'cqo':
            self.implicit(0, 2)
            return 'r2 = (uint64_t)((int64_t)r0 >> 63);'
        if m == 'cdqe':
            self.implicit(0)
            return 'r0 = (uint64_t)(int64_t)(int32_t)r0;'

        # ---- arithmetic
        if m in ('add', 'sub', 'cmp', 'and', 'or', 'xor', 'test'):
            w = sz(o0)
            a = self.rd(ins, o0)
            b = self.rd(ins, o1, w)
            if o1.type == X.X86_OP_IMM and o1.size * 8 < w:
                b = f'(uint64_t)(int64_t)({o1.imm}ll)'
            opn = {'add': '+', 'sub': '-', 'cmp': '-', 'and': '&', 'or': '|', 'xor': '^', 'test': '&'}[m]
            fop = {'add': 'F_ADD', 'sub': 'F_SUB', 'cmp': 'F_SUB'}.get(m, 'F_LOGIC')
            out = f'{{ uint64_t _a = {a}, _b = {b}; uint64_t _r = ({UT[w]})(_a {opn} _b); '
            out += self.flags(fop, w, '_a', '_b', '_r')
            if m not in ('cmp', 'test'):
                out += ' ' + self.wr(ins, o0, '_r')
            return out + ' }'
        if m in ('inc', 'dec', 'neg', 'not'):
            w = sz(o0)
            a = self.rd(ins, o0)
            expr = {'inc': '_a + 1', 'dec': '_a - 1', 'neg': '0 - _a', 'not': '~_a'}[m]
            out = f'{{ uint64_t _a = {a}; uint64_t _r = ({UT[w]})({expr}); '
            if m != 'not':
                out += self.flags({'inc': 'F_INC', 'dec': 'F_DEC', 'neg': 'F_NEG'}[m], w, '_a', '0', '_r')
            return out + ' ' + self.wr(ins, o0, '_r') + ' }'
        if m == 'imul':
            if len(ops) == 1:
                w = sz(o0)
                if w == 32:
                    self.implicit(0, 2)
                    return (f'{{ int64_t _p = (int64_t)(int32_t)r0 * (int64_t)(int32_t){self.rd(ins, o0)}; '
                            f'r0 = (uint32_t)_p; r2 = (uint32_t)((uint64_t)_p >> 32); '
                            + self.flags('F_LOGIC', 32, '0', '0', '_p') + ' }')
                raise TranslateError('imul 1-op size')
            w = sz(o0)
            if len(ops) == 2:
                a, b = self.rd(ins, o0), self.rd(ins, o1)
            else:
                a, b = self.rd(ins, o1), f'(uint64_t)(int64_t)({ops[2].imm}ll)'
            return (f'{{ uint64_t _r = ({UT[w]})(({ST[w]}){a} * ({ST[w]})({b})); '
                    + self.flags('F_LOGIC', w, '0', '0', '_r') + ' ' + self.wr(ins, o0, '_r') + ' }')
        if m == 'mul':
            w = sz(o0)
            self.implicit(0, 2)
            if w == 32:
                return (f'{{ uint64_t _p = (uint64_t)(uint32_t)r0 * (uint64_t)(uint32_t){self.rd(ins, o0)}; '
                        f'r0 = (uint32_t)_p; r2 = (uint32_t)(_p >> 32); }}')
            raise TranslateError('mul size')
        if m in ('div', 'idiv'):
            w = sz(o0)
            self.implicit(0, 2)
            d = self.rd(ins, o0)
            if w == 32:
                if m == 'div':
                    return (f'{{ uint64_t _n = ((r2 & 0xffffffffull) << 32) | (uint32_t)r0; uint32_t _d = {d}; '
                            f'if (!_d) cpu_trap("div by zero"); r0 = (uint32_t)(_n / _d); r2 = (uint32_t)(_n % _d); }}')
                return (f'{{ int64_t _n = (int64_t)(((r2 & 0xffffffffull) << 32) | (uint32_t)r0); int32_t _d = (int32_t){d}; '
                        f'if (!_d) cpu_trap("idiv by zero"); r0 = (uint32_t)(int32_t)(_n / _d); r2 = (uint32_t)(int32_t)(_n % _d); }}')
            if w == 64:
                if m == 'div':
                    return (f'{{ uint64_t _d = {d}; if (!_d) cpu_trap("div by zero"); '
                            f'unsigned __int128 _n = ((unsigned __int128)r2 << 64) | r0; r0 = (uint64_t)(_n / _d); r2 = (uint64_t)(_n % _d); }}')
                return (f'{{ int64_t _d = (int64_t){d}; if (!_d) cpu_trap("idiv by zero"); '
                        f'__int128 _n = (__int128)(((unsigned __int128)r2 << 64) | r0); r0 = (uint64_t)(int64_t)(_n / _d); r2 = (uint64_t)(int64_t)(_n % _d); }}')
            raise TranslateError('div size')
        if m in ('shl', 'shr', 'sar', 'sal'):
            w = sz(o0)
            a = self.rd(ins, o0)
            if len(ops) == 1:
                cnt = '1'
            else:
                cnt = self.rd(ins, o1, 8)
            mask = 63 if w == 64 else 31
            if m in ('shl', 'sal'):
                expr = '_a << _c'
                cf = f'((_a >> ({w} - _c)) & 1)'
            elif m == 'shr':
                expr = '_a >> _c'
                cf = '((_a >> (_c - 1)) & 1)'
            else:
                expr = f'(uint64_t)(({ST[w]})_a >> _c)'
                cf = f'(((uint64_t)(({ST[w]})_a >> (_c - 1))) & 1)'
            return (f'{{ uint64_t _a = {a}; unsigned _c = ({cnt}) & {mask}; if (_c) {{ '
                    f'uint64_t _r = ({UT[w]})({expr}); fop = F_SHIFT; fsz = {w}; fa = {cf}; fb = 0; fr = _r; '
                    + self.wr(ins, o0, '_r') + ' } }')
        if m in ('bt', 'bts', 'btr', 'btc'):
            w = sz(o0)
            if o0.type == X.X86_OP_MEM and o1.type == X.X86_OP_REG:
                # bit-string addressing
                base = self.mem_addr(ins, o0)
                off = self.rd(ins, o1, 64)
                bitexpr = f'(int64_t)({ST[w]})({self.rd(ins, o1)})'
                out = (f'{{ int64_t _o = {bitexpr}; uint64_t _p = {base} + (uint64_t)(_o >> 3); '
                       f'unsigned _b = _o & 7; uint8_t _v = LD8(_p); fop = F_BT; fa = (_v >> _b) & 1; fsz = 8; fb = 0; fr = 1; ')
                if m == 'bts':
                    out += 'ST8(_p, _v | (1u << _b)); '
                elif m == 'btr':
                    out += 'ST8(_p, _v & ~(1u << _b)); '
                elif m == 'btc':
                    out += 'ST8(_p, _v ^ (1u << _b)); '
                return out + '}'
            a = self.rd(ins, o0)
            b = self.rd(ins, o1)
            out = f'{{ uint64_t _a = {a}; unsigned _b = ({b}) & {w - 1}; fop = F_BT; fsz = {w}; fa = (_a >> _b) & 1; fb = 0; fr = 1; '
            if m != 'bt':
                expr = {'bts': '_a | (1ull << _b)', 'btr': '_a & ~(1ull << _b)', 'btc': '_a ^ (1ull << _b)'}[m]
                out += self.wr(ins, o0, expr)
            return out + ' }'
        if m == 'popcnt':
            w = sz(o0)
            return (f'{{ uint64_t _s = {self.rd(ins, o1)}; uint64_t _r = __builtin_popcountll(_s); '
                    + self.flags('F_LOGIC', w, '0', '0', '_s') + ' ' + self.wr(ins, o0, '_r') + ' }')
        if m in ('bsf', 'bsr'):
            w = sz(o0)
            fn = '__builtin_ctzll(_s)' if m == 'bsf' else f'(63 - __builtin_clzll(_s))'
            return (f'{{ uint64_t _s = {self.rd(ins, o1)}; ' + self.flags('F_LOGIC', w, '0', '0', '_s') +
                    f' if (_s) {{ {self.wr(ins, o0, fn)} }} }}')
        if m.startswith('set'):
            c = CC[m[3:]]
            return self.wr(ins, o0, f'({c}) ? 1 : 0')
        if m.startswith('cmov'):
            c = CC[m[4:]]
            w = sz(o0)
            if w == 32:   # 32-bit cmov always zero-extends the destination
                return f'if ({c}) {{ {self.wr(ins, o0, self.rd(ins, o1))} }} else {{ {self.wr(ins, o0, self.rd(ins, o0))} }}'
            return f'if ({c}) {{ {self.wr(ins, o0, self.rd(ins, o1))} }}'

        # ---- strings
        if m.startswith('rep '):
            op = m[4:]
            self.implicit(1, 6, 7, 0)
            if op.startswith('stos'):
                w = {'stosb': 8, 'stosw': 16, 'stosd': 32, 'stosq': 64}[op]
                return (f'{{ uint64_t _n = r1; {UT[w]} _v = ({UT[w]})r0; uint8_t *_p = (uint8_t*)(uintptr_t)r7; '
                        f'for (uint64_t _i = 0; _i < _n; _i++) memcpy(_p + _i*{w // 8}, &_v, {w // 8}); '
                        f'r7 += _n*{w // 8}; r1 = 0; }}')
            if op.startswith('movs'):
                w = {'movsb': 8, 'movsw': 16, 'movsd': 32, 'movsq': 64}[op]
                return (f'{{ uint64_t _n = r1; uint8_t *_d = (uint8_t*)(uintptr_t)r7; const uint8_t *_s = (const uint8_t*)(uintptr_t)r6; '
                        f'for (uint64_t _i = 0; _i < _n*{w // 8}; _i++) _d[_i] = _s[_i]; '
                        f'r7 += _n*{w // 8}; r6 += _n*{w // 8}; r1 = 0; }}')
            raise TranslateError(m)

        # ---- SSE (scalar single)
        if m == 'movss':
            if o0.type == X.X86_OP_REG and o1.type == X.X86_OP_REG:
                return f'{self.xreg(ins, o0)}.f[0] = {self.xreg(ins, o1)}.f[0];'
            if o0.type == X.X86_OP_REG:
                x = self.xreg(ins, o0)
                return f'{{ uint32_t _v = LD32({self.mem_addr(ins, o1)}); {x}.u64[0] = _v; {x}.u64[1] = 0; }}'
            return f'ST32({self.mem_addr(ins, o0)}, {self.xreg(ins, o1)}.u32[0]);'
        if m == 'movaps':
            if o0.type == X.X86_OP_REG and o1.type == X.X86_OP_REG:
                return f'{self.xreg(ins, o0)} = {self.xreg(ins, o1)};'
            if o0.type == X.X86_OP_REG:
                return f'memcpy(&{self.xreg(ins, o0)}, (void*)(uintptr_t){self.mem_addr(ins, o1)}, 16);'
            return f'memcpy((void*)(uintptr_t){self.mem_addr(ins, o0)}, &{self.xreg(ins, o1)}, 16);'
        if m in ('xorps', 'andps'):
            a = self.xreg(ins, o0)
            if o1.type == X.X86_OP_REG:
                b = self.xreg(ins, o1)
                src = f'{b}.u64[0], {b}.u64[1]'
                bb = f'{b}'
                return (f'{{ xmm_t _b = {b}; {a}.u64[0] {"^" if m == "xorps" else "&"}= _b.u64[0]; '
                        f'{a}.u64[1] {"^" if m == "xorps" else "&"}= _b.u64[1]; }}')
            addr = self.mem_addr(ins, o1)
            return (f'{{ xmm_t _b; memcpy(&_b, (void*)(uintptr_t){addr}, 16); {a}.u64[0] {"^" if m == "xorps" else "&"}= _b.u64[0]; '
                    f'{a}.u64[1] {"^" if m == "xorps" else "&"}= _b.u64[1]; }}')
        if m in ('addss', 'subss', 'mulss', 'divss', 'maxss', 'minss'):
            a = self.xreg(ins, o0)
            if o1.type == X.X86_OP_REG:
                b = f'{self.xreg(ins, o1)}.f[0]'
            else:
                b = f'f32(LD32({self.mem_addr(ins, o1)}))'
            if m == 'maxss':
                return f'{{ float _b = {b}; {a}.f[0] = ({a}.f[0] > _b) ? {a}.f[0] : _b; }}'
            if m == 'minss':
                return f'{{ float _b = {b}; {a}.f[0] = ({a}.f[0] < _b) ? {a}.f[0] : _b; }}'
            opn = {'addss': '+', 'subss': '-', 'mulss': '*', 'divss': '/'}[m]
            return f'{a}.f[0] = {a}.f[0] {opn} {b};'
        if m == 'cvtsi2ss':
            a = self.xreg(ins, o0)
            w = sz(o1)
            return f'{a}.f[0] = (float)({ST[w]})({self.rd(ins, o1)});'
        if m in ('cvtss2si', 'cvttss2si'):
            w = sz(o0)
            if o1.type == X.X86_OP_REG:
                src = f'{self.xreg(ins, o1)}.f[0]'
            else:
                src = f'f32(LD32({self.mem_addr(ins, o1)}))'
            fn = 'lrintf' if m == 'cvtss2si' else '(int64_t)'
            return self.wr(ins, o0, f'({ST[w]}){fn}({src})')
        if m in ('comiss', 'ucomiss'):
            a = f'{self.xreg(ins, o0)}.f[0]'
            b = f'{self.xreg(ins, o1)}.f[0]' if o1.type == X.X86_OP_REG else f'f32(LD32({self.mem_addr(ins, o1)}))'
            return (f'{{ float _a = {a}, _b = {b}; fop = F_COMI; fsz = 32; '
                    f'fa = (_a != _a || _b != _b) ? 2 : (_a < _b ? 1 : (_a == _b ? 3 : 0)); fb = 0; fr = 0; }}')
        raise TranslateError(f'unsupported instruction: {m} {ins.op_str}')

    # ------------------------------------------------------------ region
    def region(self, region):
        s, e, name = region
        fname = self.entry_names[s]
        self.slots = self.frame_plan(s, e)
        self.used = set([RSP])
        self.written = set([RSP])
        self.xused = set()
        self.calls = set()          # functions this one calls (or tail-calls)
        self.unknown = False        # calls through a pointer
        self.ext = False            # calls SDL / libc
        self.targets = set()
        self.self_loop_ok = True
        body = []
        local_calls = []   # (site_id, return_offset)
        k = self.at[s]
        # local-label targets of jump tables (code ids inside this region)
        table_targets = [off for off in self.code_ids if s < off < e]
        for off in table_targets:
            self.targets.add(off)
        has_table_jump = False
        while k < len(self.insns) and self.insns[k].address < e:
            ins = self.insns[k]
            m = ins.mnemonic
            a = ins.address
            body.append((a, None))
            ops = ins.operands
            try:
                if m == 'ret':
                    body.append((a, 'RET'))
                elif m == 'call':
                    op = ops[0]
                    if op.type == X.X86_OP_IMM:
                        rel = self.reloc_in(ins, 1, 5)
                        if rel and rel[1]['st_shndx'] == 'SHN_UNDEF':
                            self.externs.add(rel[1].name)
                            self.ext = True
                            body.append((a, f'r4 -= 8; SPILL; ext_{rel[1].name}(); RELOAD; r4 += 8;'))
                        else:
                            t = op.imm
                            if rel:
                                t = rel[1]['st_value'] + rel[2] + 4
                            if s < t < e:
                                # call to a local subroutine
                                site = len(local_calls) + 1
                                local_calls.append((site, a + ins.size))
                                self.targets.add(t)
                                self.targets.add(a + ins.size)
                                body.append((a, f'r4 -= 8; ST64(r4, 0); lrs[lcd++] = {site}; goto L_{t:x};'))
                            elif t in self.entry_names:
                                self.calls.add(t)
                                body.append((a, f'r4 -= 8; ST64(r4, 0); @@CALL{t}@@'))
                            else:
                                raise TranslateError(f'call into middle of {self.label_at.get(t)}')
                    else:
                        # indirect call through a code id
                        self.unknown = True
                        v = self.rd(ins, op, 64)
                        body.append((a, f'{{ uint64_t _t = {v}; r4 -= 8; ST64(r4, 0); SPILL; dispatch_call(_t); RELOAD; }}'))
                elif m == 'jmp':
                    op = ops[0]
                    if op.type == X.X86_OP_IMM:
                        t = op.imm
                        rel = self.reloc_in(ins, 1, 5)
                        if rel and rel[1]['st_shndx'] == 'SHN_UNDEF':
                            self.externs.add(rel[1].name)
                            self.ext = True
                            body.append((a, f'SPILL; ext_{rel[1].name}(); RELOAD; RET_NOW;'))
                        else:
                            body.append((a, self.goto_or_tail(t, region)))
                    else:
                        v = self.rd(ins, op, 64)
                        has_table_jump = True
                        self.unknown = True     # the table's default dispatches
                        body.append((a, f'{{ uint64_t _t = {v}; JUMP_TABLE(_t); }}'))
                elif m.startswith('j'):
                    c = CC[m[1:]]
                    t = ops[0].imm
                    body.append((a, f'if ({c}) {self.goto_or_tail(t, region)}'))
                else:
                    body.append((a, self.insn(ins, region)))
                    if self.slots and k == self.at[s] + 1:
                        # after mov rbp, rsp: the frame's slots (whatever the
                        # memory held, as the machine code would read it)
                        body.append((a, self.slot_reload()))
            except TranslateError as ex:
                raise TranslateError(f'{name}+{a - s:#x} ({a:#x}) {m} {ins.op_str}: {ex}')
            k += 1
        # emit
        out = [f'static void {fname}(void) {{']
        regs = sorted(self.used)
        out.append('  ' + ' '.join(f'uint64_t r{i} = R.r[{i}];' for i in regs))
        if self.xused:
            out.append('  ' + ' '.join(f'xmm_t x{k} = R.x[{k}];' for k in sorted(self.xused)))
        out.append('  uint32_t fop = R.fop, fsz = R.fsz; uint64_t fa = R.fa, fb = R.fb, fr = R.fr;')
        if self.slots:
            out.append('  ' + ' '.join(f'{UT[w]} S{-d} = 0;' for d, w in sorted(self.slots.items())))
        if local_calls:
            out.append('  int lcd = 0; int lrs[64];')
        spill = self.spill()
        reload = self.reload()
        if self.slots:
            spill = self.slot_spill() + ' ' + spill
            reload = reload + ' ' + self.slot_reload()
        out.append(f'#define SPILL {spill}')
        out.append(f'#define RELOAD {reload}')
        if local_calls:
            sw = ' '.join(f'case {site}: goto L_{ret:x};' for site, ret in local_calls)
            out.append(f'#define RET_NOW {{ if (lcd) {{ lcd--; r4 += 8; switch (lrs[lcd]) {{ {sw} }} }} r4 += 8; @@RETSPILL@@ return; }}')
        else:
            out.append('#define RET_NOW { r4 += 8; @@RETSPILL@@ return; }')
        if has_table_jump:
            cases = ' '.join(f'case {self.code_ids[t]}: goto L_{t:x};' for t in table_targets)
            out.append(f'#define JUMP_TABLE(t) switch (t) {{ {cases} default: {{ SPILL; dispatch_call(t); return; }} }}')
        if s in self.targets:
            out.append(f'L_{s:x}: ;')
        last = None
        for a, stmt in body:
            if stmt is None:
                if a in self.targets and a != s:
                    out.append(f'L_{a:x}: ;')
                continue
            if stmt == 'RET':
                out.append('  RET_NOW')
            else:
                out.append('  ' + stmt)
        # fall through into the next function
        nxt = e
        if nxt in self.entry_names:
            self.calls.add(nxt)
            out.append(f'  SPILL; {self.entry_names[nxt]}(); return;')
        else:
            out.append('  cpu_trap("fell off the end");')
        out.append('#undef SPILL')
        out.append('#undef RELOAD')
        out.append('#undef RET_NOW')
        if has_table_jump:
            out.append('#undef JUMP_TABLE')
        out.append('}')
        # silence unused-label warnings: nothing to do, labels are only emitted when targeted
        self.info[s] = dict(used=set(self.used), written=set(self.written), xused=set(self.xused),
                            calls=set(self.calls), unknown=self.unknown, ext=self.ext,
                            fr=self.reads_flags_first(s, e), slots=dict(self.slots),
                            framed=self.frame_builds(s, e), rbpmem=self.touches_rbp_mem(s, e))
        return out

    def frame_builds(self, s, e):
        k = self.at[s]
        a = self.insns[k]
        b = self.insns[k + 1] if k + 1 < len(self.insns) else None
        return (a.mnemonic == 'push' and a.op_str == 'rbp' and b is not None and b.address < e
                and b.mnemonic == 'mov' and b.op_str == 'rbp, rsp')

    def touches_rbp_mem(self, s, e):
        k = self.at[s]
        while k < len(self.insns) and self.insns[k].address < e:
            ins = self.insns[k]
            for op in ins.operands:
                if op.type == X.X86_OP_MEM and op.mem.base and ins.reg_name(op.mem.base) == 'rbp':
                    return True
            k += 1
        return False

    # ------------------------------------------------------------ calls
    FLAG_WRITERS = {'add', 'sub', 'cmp', 'and', 'or', 'xor', 'test', 'inc', 'dec', 'neg', 'imul',
                    'bt', 'bts', 'btr', 'btc', 'popcnt', 'bsf', 'bsr', 'comiss', 'ucomiss'}

    def reads_flags_first(self, s, e):
        """may the function read the flags it was called with?  Only the
        straight run of instructions from its entry is looked at: a flag
        write there (before any branch) means every path overwrites them"""
        k = self.at[s]
        while k < len(self.insns) and self.insns[k].address < e:
            ins = self.insns[k]
            m = ins.mnemonic
            if m.startswith('set') or m.startswith('cmov') or m.startswith('j') or m.startswith('rep'):
                return True
            if m in ('call', 'ret', 'loop'):
                return True
            if m in self.FLAG_WRITERS:
                return False
            if m in ('shl', 'shr', 'sar', 'sal'):
                ops = ins.operands
                if len(ops) == 1 or (ops[1].type == X.X86_OP_IMM and ops[1].imm & 63):
                    return False
            k += 1
        return True

    def finish(self, funcs):
        """Fill in the calls.  For every function: the registers it or
        anything it calls may touch (U) and may change (W), over the whole
        call graph.  A call then writes back only the caller's registers in
        U(callee), and reads back only those in W(callee); a return writes
        back only what the function itself changed.  Calls through
        pointers, to SDL / libc, and tail calls keep the full exchange."""
        ALL = set(range(16))
        EXT_R = {0, 1, 2, 4, 6, 7, 8, 9}        # args, rsp (stack args), al (varargs)
        EXT_X = set(range(8))
        U, W, XU = {}, {}, {}
        for off, inf in self.info.items():
            if inf['unknown']:
                U[off], W[off], XU[off] = set(ALL), set(ALL), set(ALL)
                continue
            U[off] = set(inf['used']) | (EXT_R if inf['ext'] else set())
            W[off] = set(inf['written']) | ({0} if inf['ext'] else set())
            XU[off] = set(inf['xused']) | (EXT_X if inf['ext'] else set())
        changed = True
        while changed:
            changed = False
            for off, inf in self.info.items():
                for c in inf['calls']:
                    for S in (U, W, XU):
                        if not S[c] <= S[off]:
                            S[off] |= S[c]
                            changed = True
        # can a call reach the caller's frame through rbp?  A function that
        # builds its own frame can't; one that doesn't can, if it or a
        # frameless function it calls touches [rbp + n]
        FA = {}
        for off, inf in self.info.items():
            FA[off] = (not inf['framed']) and (inf['unknown'] or inf['rbpmem'])
        changed = True
        while changed:
            changed = False
            for off, inf in self.info.items():
                if FA[off] or inf['framed']:
                    continue
                if any(FA[c] for c in inf['calls']):
                    FA[off] = True
                    changed = True
        for (s, e, n), fn in zip(self.regions, funcs):
            inf = self.info[s]
            used, xused = inf['used'], inf['xused']
            ret = ' '.join(f'R.r[{i}] = r{i};' for i in sorted(inf['written'] | {RSP}))
            ret += ' ' + ' '.join(f'R.x[{k}] = x{k};' for k in sorted(xused))
            ret += ' R.fop = fop; R.fsz = fsz; R.fa = fa; R.fb = fb; R.fr = fr;'
            for li, line in enumerate(fn):
                if '@@' not in line:
                    continue
                line = line.replace('@@RETSPILL@@', ret)
                while '@@CALL' in line:
                    a = line.index('@@CALL')
                    b = line.index('@@', a + 2)
                    t = int(line[a + 6:b])
                    ti = self.info[t]
                    sp = ' '.join(f'R.r[{i}] = r{i};' for i in sorted(used & U[t]))
                    sp += ' ' + ' '.join(f'R.x[{k}] = x{k};' for k in sorted(xused & XU[t]))
                    if ti['fr']:
                        sp += ' R.fop = fop; R.fsz = fsz; R.fa = fa; R.fb = fb; R.fr = fr;'
                    rl = ' '.join(f'r{i} = R.r[{i}];' for i in sorted(used & W[t]))
                    rl += ' ' + ' '.join(f'x{k} = R.x[{k}];' for k in sorted(xused & XU[t]))
                    rl += ' fop = R.fop; fsz = R.fsz; fa = R.fa; fb = R.fb; fr = R.fr;'
                    if inf['slots'] and FA[t]:
                        sl = sorted(inf['slots'].items())
                        sp = ' '.join(f'ST{w}(r5+(uint64_t)({d}ll), S{-d});' for d, w in sl) + ' ' + sp
                        rl += ' ' + ' '.join(f'S{-d} = LD{w}(r5+(uint64_t)({d}ll));' for d, w in sl)
                    line = line[:a] + f'{sp} {self.entry_names[t]}(); {rl}' + line[b + 2:]
                fn[li] = line

    # ------------------------------------------------------------ program
    def run(self, overrides):
        funcs = []
        protos = []
        errors = []
        for region in self.regions:
            s, e, name = region
            fname = self.entry_names[s]
            protos.append(f'static void {fname}(void);')
            if name in overrides:
                funcs.append([f'static void {fname}(void) {{', overrides[name], '}'])
                self.info[s] = dict(used={RSP}, written={RSP}, xused={0}, calls=set(),
                                    unknown=False, ext=False, fr=True, slots={},
                                    framed=False, rbpmem=False)
                continue
            try:
                funcs.append(self.region(region))
            except TranslateError as ex:
                errors.append(str(ex))
        if errors:
            for x in errors[:40]:
                print('ERROR', x, file=sys.stderr)
            raise SystemExit(f'{len(errors)} translation errors')
        self.finish(funcs)
        return protos, funcs

    def data_image(self):
        d = self.o.data.data()
        relocs = []
        for off, (typ, sym, add) in sorted(self.o.relocs.get('.data', {}).items()):
            shn = sym['st_shndx']
            sec = self.o.sec_name(shn)
            val = sym['st_value'] + add
            size = 8 if typ == 1 else 4   # R_X86_64_64 = 1, R_X86_64_32 = 10
            if typ not in (1, 10, 11):
                raise SystemExit(f'data reloc type {typ}')
            if sec == '.data':
                relocs.append((off, 0, val, size))
            elif sec == '.bss':
                relocs.append((off, 1, val, size))
            elif sec == '.text':
                relocs.append((off, 2, self.code_id(val), size))
            else:
                raise SystemExit(f'data reloc to {sec}')
        return d, relocs


# ---------------------------------------------------------------------------
OVERRIDES = {
    # x87 e^x -> C
    'fexp': '  R.x[0].f[0] = expf(R.x[0].f[0]); R.r[4] += 8;',
}


def main():
    src, dst = sys.argv[1], sys.argv[2]
    o = Obj(src)
    t = Translator(o)
    data, drel = t.data_image()
    protos, funcs = t.run(OVERRIDES)
    main_off = None
    for s in o.syms:
        if s.name == 'main' and s['st_shndx'] == t.text_idx:
            main_off = s['st_value']
    with open(dst, 'w') as f:
        f.write('// generated by tools/asm2c/translate.py - do not edit\n')
        f.write('#include "cpu.h"\n\n')
        f.write(f'#define DATA_SIZE {len(data)}\n#define BSS_SIZE {o.bss["sh_size"]}\n')
        f.write('static const uint8_t data_init[DATA_SIZE] = {')
        f.write(','.join(str(b) for b in data))
        f.write('};\n')
        f.write('uint8_t g_data[DATA_SIZE] __attribute__((aligned(64)));\n')
        f.write('uint8_t g_bss[BSS_SIZE] __attribute__((aligned(64)));\n')
        f.write('#define D_BASE ((uint64_t)(uintptr_t)g_data)\n#define B_BASE ((uint64_t)(uintptr_t)g_bss)\n')
        f.write('static const uint32_t data_relocs[][4] = {\n')
        for off, kind, val, size in drel:
            f.write(f'  {{{off}, {kind}, {val}, {size}}},\n')
        f.write('  {0xffffffff, 0, 0, 0}};\n\n')
        for ext in sorted(t.externs):
            f.write(f'void ext_{ext}(void);\n')
        f.write('\n'.join(protos) + '\n')
        f.write('void dispatch_call(uint64_t id);\n\n')
        for fn in funcs:
            f.write('\n'.join(fn) + '\n\n')
        # code id dispatch
        f.write('void dispatch_call(uint64_t id) {\n  switch (id) {\n')
        for off, cid in sorted(t.code_ids.items(), key=lambda x: x[1]):
            if off in t.entry_names:
                f.write(f'  case {cid}: {t.entry_names[off]}(); return;\n')
        f.write('  default: cpu_trap("bad code id");\n  }\n}\n\n')
        f.write('void game_init_memory(void) {\n  memcpy(g_data, data_init, DATA_SIZE);\n'
                '  for (int i = 0; data_relocs[i][0] != 0xffffffffu; i++) {\n'
                '    uint64_t v = data_relocs[i][1] == 0 ? D_BASE + data_relocs[i][2] :\n'
                '                 data_relocs[i][1] == 1 ? B_BASE + data_relocs[i][2] : data_relocs[i][2];\n'
                '    if (data_relocs[i][3] == 8) memcpy(g_data + data_relocs[i][0], &v, 8);\n'
                '    else { uint32_t w = (uint32_t)v; memcpy(g_data + data_relocs[i][0], &w, 4); }\n  }\n}\n\n')
        f.write(f'void game_main(void) {{ {t.entry_names[main_off]}(); }}\n')
    print(f'translated {len(funcs)} functions, {len(t.insns)} instructions, '
          f'{len(t.code_ids)} code ids, externs: {" ".join(sorted(t.externs))}')


if __name__ == '__main__':
    main()
