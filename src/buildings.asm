; =====================================================================
;  BUILDINGS - static data describing every placeable service building
; =====================================================================

BK_COAL      equ 0
BK_WIND      equ 1
BK_SOLAR     equ 2
BK_NUCLEAR   equ 3
BK_PUMP      equ 4
BK_WTOWER    equ 5
BK_SEWAGE    equ 6
BK_LANDFILL  equ 7
BK_INCIN     equ 8
BK_POLICE    equ 9
BK_FIRE      equ 10
BK_CLINIC    equ 11
BK_HOSPITAL  equ 12
BK_ELEM      equ 13
BK_HIGH      equ 14
BK_UNIV      equ 15
BK_BUSDEPOT  equ 16
BK_PARK      equ 17
BK_PLAZA     equ 18
BK_STADIUM   equ 19
BK_CITYHALL  equ 20
BK_LANDMARK  equ 21
BK_FIRST_BETA equ 22        ; kinds from here on are only in ?beta
BK_METRO     equ 22         ; beta
BK_RAILSTN   equ 23         ; beta
BK_FREIGHT   equ 24         ; beta
BK_AIRPORT   equ 25         ; beta
BK_PORT      equ 26         ; beta
BK_PLOW      equ 27         ; beta
BK_GCENTRAL  equ 28         ; beta: wonders ..
BK_EXCHANGE  equ 29
BK_OPERA     equ 30
BK_SPACE     equ 31
BK_EXPO      equ 32         ; .. beta
BK_TREAT     equ 33         ; beta
BK_CEMETERY  equ 34         ; beta
BK_CREM      equ 35         ; beta
BK_TRAMDEPOT equ 36         ; beta
BK_HOTEL     equ 37         ; beta
BK_ICSTN     equ 38         ; beta
BK_PIER      equ 39         ; beta
BK_WAREHOUSE equ 40         ; beta
BK_COUNT     equ 41
BK_MAX       equ 48         ; room for more kinds (svc_count, tables)

; coverage kinds
CV_NONE      equ 0
CV_POLICE    equ 1
CV_FIRE      equ 2
CV_HEALTH    equ 3
CV_ELEM      equ 4
CV_HIGH      equ 5
CV_UNIV      equ 6
CV_PARK      equ 7
CV_GARBAGE   equ 8      ; truck service area
CV_TRANSIT   equ 9      ; bus depot
CV_COUNT     equ 10

; record layout (48 bytes)
BI_SIZE      equ 0      ; footprint in tiles
BI_COV       equ 1      ; coverage kind
BI_RADIUS    equ 2      ; coverage / service radius in tiles
BI_POLL      equ 3      ; ground pollution emitted
BI_COST      equ 4      ; dword build cost
BI_UPKEEP    equ 8      ; dword monthly upkeep
BI_POWER     equ 12     ; dword power produced
BI_WATER     equ 16     ; dword water pumped (or sewage treated for outlets)
BI_UNLOCK    equ 20     ; dword population needed
BI_NAME      equ 24     ; qword name string
BI_VEHICLES  equ 32     ; byte: vehicles (fire trucks, garbage trucks, buses)
BI_NOISE     equ 33     ; byte: noise emitted
BI_NEEDWATER equ 34     ; byte: must touch water when placed
BI_CATEGORY  equ 35     ; byte: CAT_*
BI_CAPACITY  equ 36     ; dword: landfill capacity / patients
BI_DESC      equ 40     ; qword one-line description

CAT_POWER    equ 0
CAT_WATER    equ 1
CAT_GARBAGE  equ 2
CAT_SAFETY   equ 3
CAT_HEALTH   equ 4
CAT_EDU      equ 5
CAT_TRANSIT  equ 6
CAT_LEISURE  equ 7

%macro BINFO 16
    db %1, %2, %3, %4
    dd %5, %6, %7, %8, %9
    dq %10
    db %11, %12, %13, %14
    dd %15
    dq %16
%endmacro

section .data
align 8
bld_info:
    ;      size cov         rad pol  cost   upk  power water unlock name      veh noise needw cat          cap   desc
    BINFO  3, CV_NONE, 0, 90, 3000, 180, 1400, 0, 0, nm_coal, 0, 60, 0, CAT_POWER, 0, ds_coal
    BINFO  1, CV_NONE, 0, 0, 400, 24, 70, 0, 0, nm_wind, 0, 20, 0, CAT_POWER, 0, ds_wind
    BINFO  2, CV_NONE, 0, 0, 1800, 60, 400, 0, 1200, nm_solar, 0, 0, 0, CAT_POWER, 0, ds_solar
    BINFO  3, CV_NONE, 0, 10, 12000, 540, 5000, 0, 9000, nm_nuclear, 0, 30, 0, CAT_POWER, 0, ds_nuclear
    BINFO  1, CV_NONE, 0, 0, 500, 30, 0, 900, 0, nm_pump, 0, 0, 1, CAT_WATER, 0, ds_pump
    BINFO  1, CV_NONE, 0, 0, 250, 15, 0, 250, 0, nm_wtower, 0, 0, 0, CAT_WATER, 0, ds_wtower
    BINFO  1, CV_NONE, 0, 0, 400, 24, 0, 1000, 0, nm_sewage, 0, 10, 1, CAT_WATER, 0, ds_sewage
    BINFO  2, CV_GARBAGE, 40, 40, 1200, 90, 0, 0, 60, nm_landfill, 8, 30, 0, CAT_GARBAGE, 40000, ds_landfill
    BINFO  2, CV_GARBAGE, 48, 70, 4500, 240, 150, 0, 2500, nm_incin, 10, 40, 0, CAT_GARBAGE, 0, ds_incin
    BINFO  2, CV_POLICE, 14, 0, 1000, 120, 0, 0, 250, nm_police, 3, 20, 0, CAT_SAFETY, 0, ds_police
    BINFO  2, CV_FIRE, 14, 0, 1000, 120, 0, 0, 250, nm_fire, 3, 20, 0, CAT_SAFETY, 0, ds_fire
    BINFO  1, CV_HEALTH, 10, 0, 800, 90, 0, 0, 60, nm_clinic, 0, 0, 0, CAT_HEALTH, 0, ds_clinic
    BINFO  2, CV_HEALTH, 20, 0, 3500, 270, 0, 0, 1200, nm_hospital, 0, 10, 0, CAT_HEALTH, 0, ds_hospital
    BINFO  1, CV_ELEM, 12, 0, 700, 75, 0, 0, 60, nm_elem, 0, 8, 0, CAT_EDU, 0, ds_elem
    BINFO  2, CV_HIGH, 18, 0, 2000, 180, 0, 0, 600, nm_high, 0, 10, 0, CAT_EDU, 0, ds_high
    BINFO  3, CV_UNIV, 30, 0, 7000, 480, 0, 0, 2500, nm_univ, 0, 10, 0, CAT_EDU, 0, ds_univ
    BINFO  2, CV_TRANSIT, 0, 0, 1500, 150, 0, 0, 600, nm_busdepot, 5, 20, 0, CAT_TRANSIT, 0, ds_busdepot
    BINFO  1, CV_PARK, 6, 0, 150, 9, 0, 0, 0, nm_park, 0, 0, 0, CAT_LEISURE, 0, ds_park
    BINFO  2, CV_PARK, 10, 0, 700, 30, 0, 0, 600, nm_plaza, 0, 5, 0, CAT_LEISURE, 0, ds_plaza
    BINFO  3, CV_PARK, 24, 0, 8000, 300, 0, 0, 5000, nm_stadium, 0, 60, 0, CAT_LEISURE, 0, ds_stadium
    BINFO  2, CV_PARK, 16, 0, 5000, 120, 0, 0, 2500, nm_cityhall, 0, 5, 0, CAT_LEISURE, 0, ds_cityhall
    BINFO  2, CV_PARK, 40, 0, 25000, 150, 0, 0, 16000, nm_landmark, 0, 20, 0, CAT_LEISURE, 0, ds_landmark
    BINFO  1, CV_NONE, 6, 0, 3000, 150, 0, 0, 5000, nm_metro, 0, 5, 0, CAT_TRANSIT, 0, ds_metro
    BINFO  2, CV_NONE, 8, 0, 6000, 300, 0, 0, 9000, nm_railstn, 0, 25, 0, CAT_TRANSIT, 0, ds_railstn
    BINFO  3, CV_NONE, 10, 20, 8000, 350, 0, 0, 9000, nm_freight, 0, 40, 0, CAT_TRANSIT, 0, ds_freight
    BINFO  3, CV_NONE, 0, 10, 30000, 900, 0, 0, AP_UNLOCK, nm_airport, 0, 60, 0, CAT_TRANSIT, 0, ds_airport
    BINFO  3, CV_NONE, 0, 15, 15000, 400, 0, 0, 9000, nm_port, 0, 40, 1, CAT_TRANSIT, 0, ds_port
    BINFO  2, CV_NONE, 20, 0, 2000, 120, 0, 0, 2500, nm_plow, 0, 10, 0, CAT_SAFETY, 0, ds_plow
    BINFO  3, CV_NONE, 0, 0, 60000, 800, 0, 0, 50000, nm_gcentral, 0, 30, 0, CAT_TRANSIT, 0, ds_gcentral
    BINFO  2, CV_NONE, 0, 0, 45000, 600, 0, 0, 50000, nm_exchange, 0, 10, 0, CAT_LEISURE, 0, ds_exchange
    BINFO  3, CV_PARK, 22, 0, 50000, 700, 0, 0, 50000, nm_opera, 0, 10, 0, CAT_LEISURE, 0, ds_opera
    BINFO  3, CV_NONE, 0, 10, 90000, 1200, 0, 0, 80000, nm_space, 0, 50, 0, CAT_EDU, 0, ds_space
    BINFO  3, CV_NONE, 0, 0, 80000, 1000, 0, 0, 80000, nm_expo, 0, 30, 0, CAT_LEISURE, 0, ds_expo
    BINFO  2, CV_NONE, 0, 0, 6000, 300, 0, 3000, 2500, nm_treat, 0, 15, 1, CAT_WATER, 0, ds_treat
    BINFO  3, CV_NONE, 30, 0, 4000, 150, 0, 0, 1200, nm_cemetery, 0, 0, 0, CAT_HEALTH, 0, ds_cemetery
    BINFO  2, CV_NONE, 30, 15, 6000, 250, 0, 0, 5000, nm_crem, 0, 10, 0, CAT_HEALTH, 0, ds_crem
    BINFO  2, CV_NONE, 0, 0, 2500, 150, 0, 0, 2500, nm_tramdepot, 0, 20, 0, CAT_TRANSIT, 0, ds_tramdepot
    BINFO  2, CV_NONE, 0, 0, 8000, 60, 0, 0, 5000, nm_hotel, 0, 15, 0, CAT_LEISURE, 0, ds_hotel
    BINFO  3, CV_NONE, 8, 0, 20000, 600, 0, 0, 30000, nm_icstn, 0, 30, 0, CAT_TRANSIT, 0, ds_icstn
    BINFO  1, CV_NONE, 6, 0, 3000, 100, 0, 0, 5000, nm_pier, 0, 5, 1, CAT_TRANSIT, 0, ds_pier
    BINFO  2, CV_NONE, WH_REACH, 10, 3000, 120, 0, 0, 1200, nm_wh, 0, 25, 0, CAT_TRANSIT, 0, ds_wh

nm_coal      db "Coal Power Plant", 0
nm_wind      db "Wind Turbine", 0
nm_solar     db "Solar Farm", 0
nm_nuclear   db "Nuclear Plant", 0
nm_pump      db "Water Pump", 0
nm_wtower    db "Water Tower", 0
nm_sewage    db "Sewage Outlet", 0
nm_landfill  db "Landfill", 0
nm_incin     db "Incinerator", 0
nm_police    db "Police Station", 0
nm_fire      db "Fire Station", 0
nm_clinic    db "Clinic", 0
nm_hospital  db "Hospital", 0
nm_elem      db "Elementary School", 0
nm_high      db "High School", 0
nm_univ      db "University", 0
nm_busdepot  db "Bus Depot", 0
nm_park      db "Park", 0
nm_plaza     db "Plaza", 0
nm_stadium   db "Stadium", 0
nm_cityhall  db "City Hall", 0
nm_landmark  db "Asm Tower", 0
nm_metro     db "Metro Station", 0
nm_railstn   db "Railway Station", 0
nm_freight   db "Freight Yard", 0
nm_treat     db "Water Treatment", 0
ds_treat     db "Takes sewage like an outlet, but cleans it.", 0
hb_treat     db "Must touch water. Takes the sewage", 10
             db "of the pipes touching it and lets", 10
             db "clean water out: nothing downstream", 10
             db "gets dirty. Needs power.", 0

ds_coal      db "Cheap, strong power. Very polluting.", 0
ds_wind      db "Clean but weak. Output varies by season.", 0
ds_solar     db "Clean, steady power.", 0
ds_nuclear   db "Huge clean output. Expensive.", 0
ds_pump      db "Pumps water into pipes. Must touch water.", 0
ds_wtower    db "Small water supply, anywhere.", 0
ds_sewage    db "Drains pipes into water. Pollutes downstream!", 0
ds_landfill  db "Garbage trucks collect waste. Fills up.", 0
ds_incin     db "Burns garbage, makes power. Pollutes.", 0
ds_police    db "Lowers crime. Patrol cars.", 0
ds_fire      db "Fire trucks drive to fires.", 0
ds_clinic    db "Small health coverage.", 0
ds_hospital  db "Wide health coverage.", 0
ds_elem      db "Basic education.", 0
ds_high      db "Educated workers for offices.", 0
ds_univ      db "Highly educated workers. Hi-tech jobs.", 0
ds_busdepot  db "Buses run between all bus stops.", 0
ds_park      db "Raises land value, cleans air.", 0
ds_plaza     db "Bigger park with a fountain.", 0
ds_stadium   db "City-wide happiness boost.", 0
ds_cityhall  db "Civic pride. Land value boost.", 0
ds_landmark  db "Tourists! Monthly income.", 0
ds_metro     db "Trains under the city, between stations.", 0
ds_railstn   db "Trains between stations, and from the region.", 0
ds_freight   db "Ships industry's exports by train.", 0

section .text
; bld_rec(edi kind) -> rax record pointer
bld_rec:
    mov eax, edi
    imul eax, eax, 48
    lea rax, [bld_info+rax]
    ret
