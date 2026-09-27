; =====================================================================
;  BUILDINGS - static data describing every placeable service building
; =====================================================================

BK_COAL      equ 0
BK_WIND      equ 1
BK_SOLAR     equ 2
BK_NUCLEAR   equ 3
BK_PUMP      equ 4
BK_WTOWER    equ 5
BK_POLICE    equ 6
BK_FIRE      equ 7
BK_CLINIC    equ 8
BK_HOSPITAL  equ 9
BK_SCHOOL    equ 10
BK_UNIV      equ 11
BK_PARK      equ 12
BK_PLAZA     equ 13
BK_STADIUM   equ 14
BK_CITYHALL  equ 15
BK_LANDMARK  equ 16
BK_COUNT     equ 17

; coverage kinds
CV_NONE      equ 0
CV_POLICE    equ 1
CV_FIRE      equ 2
CV_HEALTH    equ 3
CV_EDU       equ 4
CV_PARK      equ 5

; record layout (32 bytes)
BI_SIZE      equ 0      ; footprint in tiles
BI_COV       equ 1      ; coverage kind
BI_RADIUS    equ 2      ; coverage radius in tiles
BI_POLL      equ 3      ; pollution emitted
BI_COST      equ 4      ; dword build cost
BI_UPKEEP    equ 8      ; dword monthly upkeep
BI_POWER     equ 12     ; dword power produced (units)
BI_WATER     equ 16     ; dword water produced
BI_UNLOCK    equ 20     ; dword population needed
BI_NAME      equ 24     ; qword name string

%macro BINFO 10
    db %1, %2, %3, %4
    dd %5, %6, %7, %8, %9
    dq %10
%endmacro

section .data
align 8
bld_info:
    ;       size cov        rad pol  cost   upk  power water unlock name
    BINFO   3, CV_NONE,     0, 90,  3000,   60,  1400,   0,     0, nm_coal
    BINFO   1, CV_NONE,     0,  0,   400,    8,    70,   0,     0, nm_wind
    BINFO   2, CV_NONE,     0,  0,  1800,   20,   400,   0,   800, nm_solar
    BINFO   3, CV_NONE,     0, 10, 12000,  180,  5000,   0,  3500, nm_nuclear
    BINFO   1, CV_NONE,     0,  0,   500,   10,     0, 900,     0, nm_pump
    BINFO   1, CV_NONE,     0,  0,   250,    5,     0, 250,     0, nm_wtower
    BINFO   2, CV_POLICE,  14,  0,  1000,   40,     0,   0,     0, nm_police
    BINFO   2, CV_FIRE,    14,  0,  1000,   40,     0,   0,     0, nm_fire
    BINFO   1, CV_HEALTH,  10,  0,   800,   30,     0,   0,     0, nm_clinic
    BINFO   2, CV_HEALTH,  20,  0,  3500,   90,     0,   0,  1500, nm_hospital
    BINFO   2, CV_EDU,     16,  0,  1500,   50,     0,   0,   250, nm_school
    BINFO   3, CV_EDU,     28,  0,  6000,  150,     0,   0,  2500, nm_univ
    BINFO   1, CV_PARK,     6,  0,   150,    3,     0,   0,     0, nm_park
    BINFO   2, CV_PARK,    10,  0,   700,   10,     0,   0,   600, nm_plaza
    BINFO   3, CV_PARK,    24,  0,  8000,  100,     0,   0,  4000, nm_stadium
    BINFO   2, CV_PARK,    16,  0,  5000,   40,     0,   0,  2000, nm_cityhall
    BINFO   2, CV_PARK,    40,  0, 25000,   50,     0,   0,  8000, nm_landmark

nm_coal      db "Coal Power Plant", 0
nm_wind      db "Wind Turbine", 0
nm_solar     db "Solar Farm", 0
nm_nuclear   db "Nuclear Plant", 0
nm_pump      db "Water Pump", 0
nm_wtower    db "Water Tower", 0
nm_police    db "Police Station", 0
nm_fire      db "Fire Station", 0
nm_clinic    db "Clinic", 0
nm_hospital  db "Hospital", 0
nm_school    db "School", 0
nm_univ      db "University", 0
nm_park      db "Park", 0
nm_plaza     db "Plaza", 0
nm_stadium   db "Stadium", 0
nm_cityhall  db "City Hall", 0
nm_landmark  db "Asm Tower", 0

section .text
; bld_rec(edi kind) -> rax record pointer
bld_rec:
    mov eax, edi
    shl eax, 5
    lea rax, [bld_info+rax]
    ret
