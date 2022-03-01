{{CM2302 Device Driver

┌──────────────────────────────────────────┐
│ CM2302 PASM Driver                       │
│ Author: James Rike                       │
│ Copyright (c) 2020 Seapoint Software     │
│ See end of file for terms of use.        │
└──────────────────────────────────────────┘

<object details, schematics, etc.>

}}

CON
  _clkmode = xtal1 + pll16x    'Standard clock mode * crystal frequency = 80 MHz
  _xinfreq = 5_000_000

VAR
  byte cog
  long ThVar[2]
  long tc_sign
  long tf_sign


OBJ
  num   :       "Simple_Numbers"
'  dbg   :       "PASDebug"      '<---- Add for Debugger
  pst   :       "Parallax Serial Terminal"

PUB Start                       'Cog start method
    Stop
    cog := cognew(@entry, @ThVar) + 1

'    dbg.start(31,30,@entry)     '<---- Add for Debugger
    PrintData

PUB Stop                        'Cog stop method
    if cog
        cogstop(cog~ - 1)

PUB gettempf | tf
    tf_sign := FALSE            'Initialize the global sign variable for farenheit

    if (ThVar[0] => $80b2)      'Check if 17.8 celcius or 0 farenheit
      tf_sign := TRUE           'If sign bit set then set global variable to true
    else
      tf_sign := FALSE

    tf := ThVar[0] & $7FFF      'clear the sign bit

    if (ThVar[0] => $8000)      'check negative celcius temperature reading
      tf := ||(tf * 9 / 5 - 320)
    else
      tf := ThVar[0] * 9 / 5 + 320

    return tf

PUB gettempc | tc, tmp
    tc_sign := FALSE            'Initialize the global sign variable for celsius
    tmp := ThVar[0] & $8000     'Get the sign bit

    if (tmp == $8000)           'Check if the sign bit is set (negative temperature)
      tc_sign := TRUE           'If sign bit set then set global variable to true
    else
      tc_sign := FALSE

    tc := ThVar[0] & $7FFF      'clear the sign bit
    return tc

PRI PrintData  | tf,tc,th

    pst.Start(115_200)

    repeat
        pst.char(0)
        if (tf_sign == FALSE)
          pst.str(string("Temp:    "))
        else
          pst.str(string("Temp:  - "))
        tf := gettempf
        pst.str(num.decf(tf / 10, 3))
        pst.char(".")
        pst.str(num.dec(tf // 10))
        pst.str(string(" degrees F"))
        pst.NewLine

        if (tc_sign == FALSE)
          pst.str(string("         "))
        else
          pst.str(string("       - "))
        tc := gettempc
        pst.str(num.decf(ThVar[0] / 10, 3))
        pst.char(".")
        pst.str(num.dec(tf // 10))
        pst.str(string(" degrees C"))
        pst.NewLine
        pst.str(string("Humidity: "))
        th := ThVar[1]
        pst.str(num.decf(th / 10, 3))
        pst.char(".")
        pst.str(num.dec(th // 10))
        pst.str(string(" %"))
        waitcnt (clkfreq * 3 + cnt)

DAT

        org 0
entry

'  --------- Debugger Kernel add this at Entry (Addr 0) ---------
'   long $34FC1202,$6CE81201,$83C120B,$8BC0E0A,$E87C0E03,$8BC0E0A
'   long $EC7C0E05,$A0BC1207,$5C7C0003,$5C7C0003,$7FFC,$7FF8
'  --------------------------------------------------------------

'
' Test code with modify, MainRAM access, jumps, subroutine and waitcnt.
'

        rdlong sfreq, #0        'Get clock frequency
        mov dpin, #1
        shl dpin, data_pin

read    mov Delay, sfreq
        shl Delay, #1           'Times 2
        mov Time, cnt           'Get current time
        add Time, Delay         'Adjust by 2 seconds
        waitcnt Time, Delay     '2 second settling time

        or outa, dPin           'PreSet DataPin HIGH
        or dira, dPin

        xor outa, dPin          'PreSet DataPin LOW [Tbe] - START

        mov Delay, mSec_Delay   'Set Delay to 1 mSec
        mov Time, cnt           'Get current system clock
        add Time, Delay         'Adjust by 1 mSec
        waitcnt Time, Delay     '1 mSec duration of START signal [Tbe]

        or outa, dPin           'PreSet DataPin HIGH [Tgo] - RELEASE
        xor dira, dPin          'Set DataPin to INPUT - RELEASE the bus

        waitpne dPin, dPin      'Catch the RESPONSE [Trel] LOW
        waitpeq dPin, dPin      'Catch the RESPONSE [Treh] HIGH
        waitpne dPin, dPin      'Catch [Tlow]

        mov data, #0
        mov counter, #32        'Set the loop counter for upper 32 data bits

dloop   waitpeq dPin, dPin      'Catch the data bit
        mov beginp, cnt         'Store the time of the leading edge
        waitpne dPin, dPin      'Catch [Tlow]
        mov endp, cnt           'Store the time of the trailing edge
        sub endp, beginp wc     'Calculate pulse width in tick counts
  if_nc cmp endp, uSec_Sample wc
  if_nc add data, #1            'if c = 0, data bit = 1
        cmp counter, #1 wz
  if_nz shl data, #1
        djnz counter, #dloop

        mov humid, data
        mov data, #0
        mov counter, #8         'Set the loop counter for the 8 check sum bits

csloop  waitpeq dPin, dPin      'Catch the data bit
        mov beginp, cnt         'Store the time of the leading edge
        waitpne dPin, dPin      'Catch [Tlow]
        mov endp, cnt           'Store the time of the trailing edge
        sub endp, beginp wc     'Calculate pulse width in tick counts
  if_nc cmp endp, uSec_Sample wc
  if_nc add data, #1            'if c = 0, data bit = 1
        cmp counter, #1 wz
  if_nz shl data, #1
        djnz counter, #csloop

        mov temp, humid         'Process the data
        shr humid, #16
        and temp, tmp_mask
        mov chk_sum, data
        and chk_sum, chk_mask

        mov th_data, temp
        mov th_data+1, humid
        mov addr, par
        wrlong th_data, addr
        add addr, #4
        wrlong th_data+1, addr

        waitpeq dPin, dPin      'Catch T'en going high

        noop
        jmp #read


dpin          long 0
'data_pin      long 5
data_pin      long 17
mSec_Delay    long 80_000
uSec_Sample   long 2_400
tmp_mask      long $FFFF
chk_mask      long $00FF
endp          long 0
beginp        long 0
sfreq         long 0
Time          long 0
Delay         long 0
counter       long 0
data          long 0
temp          long 0
humid         long 0
chk_sum       long 0
addr          long 0
th_data       long 0[2]
fit

{{
┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                   TERMS OF USE: MIT License                                                  │
├──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation    │
│files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,    │
│modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software│
│is furnished to do so, subject to the following conditions:                                                                   │
│                                                                                                                              │
│The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.│
│                                                                                                                              │
│THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE          │
│WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR         │
│COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,   │
│ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                         │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
}}
