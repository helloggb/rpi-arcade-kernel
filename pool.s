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

; =========================================================
;
; Constant Pool Data Section
;
; =========================================================
align 4
aux_base:   
    dw  PERIPHERAL_BASE + AUX_BASE

gpio_base:  
    dw  PERIPHERAL_BASE + GPIO_BASE

mail_base:  
    dw  PERIPHERAL_BASE + MAIL_BASE

arm_timer_controller:
    dw  PERIPHERAL_BASE + ARM_TIMER_CTL

arm_timer_counter:
    dw  PERIPHERAL_BASE + ARM_TIMER_CNT

gpio_sel1_uart_mask1:
    dw  $fffd2fff
