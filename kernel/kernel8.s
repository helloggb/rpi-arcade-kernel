; =========================================================
; 
; Aracde Kernel Kit
; AArch64 Assembly Language
;
; About:
;
;
;
; Contact Information:
;
;   Jeff Panici
;   Email: jeff@nybbles.io
;   Website: https://nybbles.io
;   Live Stream: https://twitch.tv/nybblesio
;
; Copyright (C) 2018 Jeff Panici
; All rights reserved.
;
; This is free software available under the MIT license.
;
; See the LICENSE file in the root directory 
; for details about this license.
;
; =========================================================

code64
processor   cpu64_v8
format      binary as 'img'

org     $0000

        b   start

include 'constants.s'
include 'macros.s'
include 'pool.s'
include 'timer.s'
include 'dma.s'
include 'mailbox.s'
include 'uart.s'
include 'joy.s'
include 'font.s'
include 'video.s'

; =========================================================
;
; entry point
;
; stack:
;   (none)
;
; registers:
;   (none)
;
; =========================================================
align 16
start:
        mrs     x0, MPIDR_EL1
        mov     x1, #$ff000000
        bic     x0, x0, x1
        cbz     x0, kernel_core
        sub     x1, x0, #1
        cbz     x1, watchdog_core
        sub     x1, x0, #2
        cbz     x1, core_two
        sub     x1, x0, #3
        cbz     x1, core_three        
.hang:  b       .hang

; =========================================================
;
; irq_isr
;
; stack:
;   (none)
;   
; registers:
;   (none)
;
; =========================================================
irq_isr:
        eret

; =========================================================
;
; fir_isr
;
; stack:
;   (none)
;   
; registers:
;   (none)
;
; =========================================================
firq_isr:
        eret

; =========================================================
;
; cmd_clear_func
;
; stack:
;   (none)
;   
; registers:
;   (none)
;
; =========================================================
cmd_clear_func:
        sub     sp, sp, #16
        stp     x0, x30, [sp]
        uart_str   clr_screen
        bl      new_prompt
        ldp     x0, x30, [sp]
        add     sp, sp, #16
        ret

; =========================================================
;
; cmd_reset_func
;
; stack:
;   (none)
;   
; registers:
;   (none)
;
; =========================================================
cmd_reset_func:
        sub     sp, sp, #16
        stp     x0, x30, [sp]
        bl      send_welcome
        bl      new_prompt
        ldp     x0, x30, [sp]
        add     sp, sp, #16
        ret

; =========================================================
;
; fill_buffer
;
; stack:
;   (none)
;   
; registers:
;   w1 is character to fill
;   w2 is the length
;   x3 is buffer address
;
; =========================================================
fill_buffer:
        sub     sp, sp, #16
        stp     x0, x30, [sp]
.empty: strb    w1, [x3], 1
        subs    w2, w2, 1
        b.ne    .empty
        ldp     x0, x30, [sp]
        add     sp, sp, #16
        ret
; =========================================================
;
; find_command
;
; stack:
;   (none)
;   
; registers:
;   (none)
;
; =========================================================
find_command:
        sub     sp, sp, #16
        stp     x0, x30, [sp]
        adr     x0, parse_buffer
        mov     w1, 0
        adr     x2, commands
        ldr     w4, [x2], 4     ; size of the command def
        ldr     w5, [x2], 4     ; size of the name string
.next:  cmp     w1, PARSE_BUFFER_LENGTH
        b.eq    .fail
        ldrb    w3, [x0], 1
        ldrb    w6, [x2]
        cmp     w3, w6
        b.eq    .maybe
.cmd:   add     x2, x2, x4
        ldr     w4, [x2], 4     ; size of the command def
        cbz     w4, .fail
        ldr     w5, [x2], 4     ; size of the name string
.more:  add     w1, w1, 1
        b       .next
.maybe: subs    w5, w5, 1
        b.eq    .cmd
        add     x2, x2, 1 
        b       .more
.fail:  mov     x2, 0
        ldp     x0, x30, [sp]
        add     sp, sp, #16
        ret

; =========================================================
;
; send_parse_error
;
; stack:
;   (none)
;   
; registers:
;   (none)
;
; =========================================================
send_parse_error:
        sub     sp, sp, #16
        stp     x0, x30, [sp]
        uart_str    parse_error
        uart_str    bold_attr
        uart_str    underline_attr
        uart_str    parse_buffer_str
        uart_str    no_attr
        uart_newline
        ldp     x0, x30, [sp]
        add     sp, sp, #16
        ret

; =========================================================
;
; send_welcome
;
; stack:
;   (none)
;
; registers:
;   (none)
;
; =========================================================
send_welcome:
        sub     sp, sp, #16
        stp     x0, x30, [sp]
        uart_str clr_screen
        uart_str kernel_title
        uart_str kernel_copyright
        uart_str kernel_license1
        uart_str kernel_license2
        uart_str kernel_help
        ldp     x0, x30, [sp]
        add     sp, sp, #16
        ret

; =========================================================
;
; new_prompt
;
; stack:
;   (none)
;
; registers:
;   (none)
;
; =========================================================
new_prompt:
        sub     sp, sp, #16
        stp     x0, x30, [sp]
        mov     w1, CHAR_SPACE
        mov     w2, TERMINAL_CHARS_PER_LINE
        adr     x3, command_buffer
        bl      fill_buffer
        mov     w1, 0 
        pstore  x0, w1, command_buffer_offset
        uart_char   '>'
        uart_space
        ldp     x0, x30, [sp]
        add     sp, sp, #16
        ret

; =========================================================
;
; kernel_core (core #0)
;
; stack:
;   (none)
;
; registers:
;   (none)
;
; =========================================================
kernel_core:        
        mov     sp, kernel_stack

        bl      dma_init
        bl      timer_init
        bl      uart_init
        bl      joy_init
        bl      video_init
        bl      cmd_reset_func
        
.loop:
        bl      uart_recv
        cbz     w1, .console
       
        cmp     w1, ESC_CHAR
        b.eq    .esc
        cmp     w1, RETURN_CHAR
        b.eq    .echo
        cmp     w1, LINEFEED_CHAR
        b.eq    .return
        cmp     w1, BACKSPACE_CHAR
        b.eq    .back

        pload   x3, w3, command_buffer_offset
        cmp     w3, TERMINAL_CHARS_PER_LINE
        b.eq    .console
        adr     x2, command_buffer
        add     x2, x2, x3
        strb    w1, [x2]
        add     w3, w3, 1
        pstore  x2, w3, command_buffer_offset
.echo:  bl      uart_send
        b       .console

.return:
        adr     x2, command_buffer
        adr     x3, parse_buffer       
        mov     w4, 0
        pload   x5, w5, command_buffer_offset
.char:  cmp     w4, w5
        b.eq    .done
        ldrb    w1, [x2], 1
        cmp     w1, CHAR_SPACE
        b.eq    .done
        strb    w1, [x3], 1
        cmp     w4, PARSE_BUFFER_LENGTH
        b.eq    .err
        add     w4, w4, 1
        b       .char

.done:  uart_char   LINEFEED_CHAR
        b       .reset

.err:   uart_char   LINEFEED_CHAR
        bl      send_parse_error

.reset: mov     w1, CHAR_SPACE
        mov     w2, PARSE_BUFFER_LENGTH
        adr     x3, parse_buffer
        bl      fill_buffer
        bl      new_prompt
        b       .console

.back:  pload   x3, w3, command_buffer_offset
        cbz     w3, .console
        sub     w3, w3, 1
        pstore  x2, w3, command_buffer_offset
        uart_char   BACKSPACE_CHAR
        uart_str    delete_char
        b       .console

.esc:   bl      uart_recv_block
        cmp     w1, LEFT_BRACKET
        b.ne    .console
        bl      uart_recv_block
        cmp     w1, CHAR_A
        b.eq    .up
        cmp     w1, CHAR_B
        b.eq    .down
        cmp     w1, CHAR_C
        b.eq    .right
        cmp     w1, CHAR_D
        b.eq    .left
        b       .console
.up:    b       .console
.down:  b       .console
.left:  b       .console
.right: b       .console

;
;
;
;

.console:        
        ;this isn't causing a problem, but i'm commenting it out for now
        ;bl       joy_read
        lbb
         
;        adr     x10, console_buffer
;        mov     w1, 0               ; y position
;        mov     w2, 0               ; x position
;        mov     w16, LINES_PER_PAGE 
;.row:   adr     x3, line_buffer
;        adr     x5, nitram_micro_font
;        mov     w4, 0
;        mov     w15, 0              ; last color
;        mov     w11, CHARS_PER_LINE
;.char:  ldrb    w13, [x10], 1       ; character
;        ldrb    w14, [x10], 1       ; color
;        cmp     w14, w15
;        b.ne    .span
;.span:  mov     w15, w14
;        bl      draw_string
;        adr     x3, line_buffer
;        mov     w4, 0
;        subs    w11, w11, 1
;        b.ne    .char
;        add     w1, w1, FONT_HEIGHT + 1
;        subs    w16, w16, 1
;        b.ne    .loop
 
        bl      page_swap
        b       .loop

; =========================================================
;
; watchdog_core (core #1)
;
; stack:
;   (none)
;
; registers:
;   (none)
;
; =========================================================
watchdog_core:
        mov     sp, kernel_stack
        sub     sp, sp, CORE_STACK_SIZE * 1
.loop:  b       .loop

; =========================================================
;
; core_two
;
; stack:
;   (none)
;
; registers:
;   (none)
;
; =========================================================
core_two:
        mov     sp, kernel_stack
        sub     sp, sp, CORE_STACK_SIZE * 2
.loop:  b       .loop

; =========================================================
;
; core_three
;
; stack:
;   (none)
;
; registers:
;   (none)
;
; =========================================================
core_three:
        mov     sp, kernel_stack
        sub     sp, sp, CORE_STACK_SIZE * 3
.loop:  b       .loop

; =========================================================
;
; Data Section
;
; =========================================================
ESC_CHAR        = $1b
BACKSPACE_CHAR  = $08
RETURN_CHAR     = $0d
LINEFEED_CHAR   = $0a
LEFT_BRACKET    = $5b
CHAR_A          = $41
CHAR_B          = $42
CHAR_C          = $43
CHAR_D          = $44
CHAR_SPACE      = $20

CHARS_PER_LINE = SCREEN_WIDTH / 8
LINES_PER_PAGE = SCREEN_HEIGHT / 8

TERMINAL_CHARS_PER_LINE = 76
PARSE_BUFFER_LENGTH = 32

align 4
console_buffer:
        db  (LINES_PER_PAGE * CHARS_PER_LINE) * 2 dup (0, 4)

align 4
con_line_buffer:
        db CHARS_PER_LINE dup (0)

align 4        
con_line_buffer_offset: db  0

align 4
command_buffer:
        db TERMINAL_CHARS_PER_LINE dup (CHAR_SPACE)

align 4        
command_buffer_offset:  dw  0

align 4
parse_buffer_str:
        dw PARSE_BUFFER_LENGTH
parse_buffer:
        db PARSE_BUFFER_LENGTH dup (CHAR_SPACE)

struc caret_t {
        .y      db  0
        .x      db  0
        .color  db  $f
        .show   db  0
}

align 8
caret   caret_t

TERM_CLS        equ ESC_CHAR, "[2J"
TERM_CURPOS11   equ ESC_CHAR, "[1;1H"
TERM_REVERSE    equ ESC_CHAR, "[7m"
TERM_NOATTR     equ ESC_CHAR, "[m"
TERM_UNDERLINE  equ ESC_CHAR, "[4m"
TERM_BLINK      equ ESC_CHAR, "[5m"
TERM_BOLD       equ ESC_CHAR, "[1m"
TERM_DELCHAR    equ ESC_CHAR, "[1P"
TERM_NEWLINE    equ $0d, $0a
TERM_NEWLINE2   equ $0d, $0a, $0d, $0a
TERM_BLACK      equ ESC_CHAR, "[30m"
TERM_RED        equ ESC_CHAR, "[31m"
TERM_GREEN      equ ESC_CHAR, "[32m"
TERM_YELLOW     equ ESC_CHAR, "[33m"
TERM_BLUE       equ ESC_CHAR, "[34m"
TERM_MAGENTA    equ ESC_CHAR, "[35m"
TERM_CYAN       equ ESC_CHAR, "[36m"
TERM_WHITE      equ ESC_CHAR, "[37m"
TERM_BG_BLACK   equ ESC_CHAR, "[40m"
TERM_BG_RED     equ ESC_CHAR, "[41m"
TERM_BG_GREEN   equ ESC_CHAR, "[42m"
TERM_BG_YELLOW  equ ESC_CHAR, "[43m"
TERM_BG_BLUE    equ ESC_CHAR, "[44m"
TERM_BG_MAGENTA equ ESC_CHAR, "[45m"
TERM_BG_CYAN    equ ESC_CHAR, "[46m"
TERM_BG_WHITE   equ ESC_CHAR, "[47m"

strdef  no_attr, TERM_NOATTR

strdef  bold_attr, TERM_BOLD

strdef  underline_attr, TERM_UNDERLINE

strdef  delete_char, TERM_DELCHAR

strdef  clr_screen, TERM_CLS, TERM_CURPOS11

strdef  kernel_title, TERM_REVERSE, \
    "                Arcade Kernel Kit, v0.1              ", \ 
    TERM_NOATTR, TERM_NEWLINE

strdef  kernel_copyright, "Copyright (C) 2018 Jeff Panici.  All rights reserved.", TERM_NEWLINE

strdef  kernel_license1, "This software is licensed under the MIT license.", TERM_NEWLINE

strdef  kernel_license2, "See the LICENSE file for details.", TERM_NEWLINE2

strdef  kernel_help, "Use the ", TERM_BOLD, TERM_UNDERLINE, "help", TERM_NOATTR, \
        " command to learn more about how the", TERM_NEWLINE, \
        "serial console works.", TERM_NEWLINE2

strdef  parse_error, TERM_BLINK, TERM_REVERSE, TERM_BOLD, " ERROR: ", TERM_NOATTR, \
        " Unable to parse command: "

F_PARAM_TYPE_REGISTER = 00000001b
F_PARAM_TYPE_NUMBER   = 00000010b
F_PARAM_TYPE_BOOLEAN  = 00000100b
F_PARAM_TYPE_STRING   = 00001000b

macro paramdef lbl, name, type, required {
align 4
label lbl
    local   .end, .start
    dw      .end - .start
.start:        
    db  name
.end:
    dw  type
    db  required
}

macro cmddef lbl, name, desc, func, param_count {
align 4
label lbl
    local   .def_end, .def_start
    local   .name_end, .name_start

.def_start:
    dw      .def_end - .def_start       ; length of command definiton
    dw      .name_end - .name_start     ; length of name string

.name_start:        
    db  name
.name_end:

    local   .desc_end, .desc_start
    dw      .desc_end - .desc_start     ; length of desc string

.desc_start:        
    db  desc
.desc_end:

    dw  func
    dw  param_count

.def_end:    
}

commands:
    cmddef      cmd_clear, "clear", \
        "Clears the terminal and places the next command line at the top.", \
        cmd_clear_func, \
        0

    cmddef      cmd_reset, "reset", \
        "Clears the terminal and displays the welcome banner.", \
        cmd_reset_func, \
        0

    cmddef      cmd_dump_reg, "reg", "Dump the value of the specified register.", 0, 1
    paramdef    cmd_dump_reg_param, "register", F_PARAM_TYPE_REGISTER, TRUE

    ; end sentinel
    dw          0

; =========================================================
;
; Game Interface Section
;
; =========================================================

include 'game_abi.s'

org GAME_ABI_BOTTOM

game_init_vector    dw  0
game_tick_vector    dw  0

; =========================================================
;
; Stack Section
;
; The kernel stack frame starts at $10000000 and ends at
; $ffc0000, which is the last 256kb of the first 256MB of RAM
; on the Raspberry Pi 3.
;
; Each processor core gets a 64kb stack frame within this
; block of RAM.
;
; =========================================================
STACK_TOP = $10000000
CORE_STACK_SIZE = $10000
CORE_COUNT = 4
STACK_SIZE = CORE_STACK_SIZE * CORE_COUNT

org STACK_TOP - STACK_SIZE

        db  STACK_SIZE dup(0)

kernel_stack:
