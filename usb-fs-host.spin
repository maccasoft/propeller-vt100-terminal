{{

usb-fs-host
------------------------------------------------------------------

This is a software implementation of a simple full-speed
(12 Mb/s) USB 1.1 host controller for the Parallax Propeller.

This module is a self-contained USB stack, including host
controller driver, host controller, and a bit-banging PHY layer.

Software implementations of low-speed (1.5 Mb/s) USB have become
fairly common, but full-speed pushes the limits of even a fairly
powerful microcontroller like the Propeller. So naturally, we
had to cut some corners. See the sizable list of limitations and
caveats below.

The latest version of this file lives at
https://github.com/scanlime/propeller-usb-host

Copyright (c) 2010-2016 M. Elizabeth Scott <beth@scanlime.org>
See end of file for terms of use.


Hardware Requirements
---------------------

 - 80 MHz Propeller
 - USB D- attached to P0 with a 47 ohm series resistor
 - USB D+ attached to P1 with a 47 ohm series resistor
 - A spare IO pin to leave unconnected
 - Pull-down resistors (~47k ohm) from USB D- and D+ to ground

  +-------------------+  USB Host (Type A) Socket
  | ----------------- |
  |  [1] [2] [3] [4]  |  1: Vbus (+5v)  Red
  |-------------------|  2: D-          White
                         3: D+          Green
                         4: GND         Black

              +5v
                |   +-----+
      2x 47ohm  +---| [1] | Vbus
  P0 >---/\/--+-----| [2] | D-
  P1 >---/\/--|-+---| [3] | D+
              | | +-| [4] | GND
              | | | +-----+
      2x 47k  / / |
              | | |
              - - -

  P8 >---  no connection, or watch with oscilloscope :)

  Note: For maximum compatibility and at least some semblance of
        USB spec compliance, all four of these resistors are
        required. And the pull-down resistors are definitely
        necessary if you want to detect device connect/disconnect
        state. However, if you are permanently attaching a single
        device to your Propeller, depending on the device you
        may be able to omit the pull-down resistors and connect
        D-/D+ directly to P0/P1. I recommend you only try this if
        you know what you're doing and/or you're brave :)

  Note: You can modify DPLUS and DMINUS below, to change the pins we use
        for the USB port. This can only be done at compile-time so far,
        since a lot of compile-time literals rely on these values. Also,
        not all pins are supported. Both DPLUS and DMINUS must be between
        P0 and P7, inclusive.

Limitations and Caveats
-----------------------

 - Supports only a single device.
   (One host controller, one port, no hubs.)

 - Pin numbers are currently hardcoded as P0 and P1.
   Clock speed is hardcoded as 80 MHz

 - Requires 2 cogs.

   (We need a peak of 2 cogs during receive, but one
   of them is idle at other times.)

 - Maximum transmitted packet size is approx. 430 bytes (NEEDS UPDATE)
   Maximum received packet size is approx. 1024 bytes (NEEDS UPDATE)

 - Doesn't even pretend to adhere to the USB spec!
   May not work with all USB devices.

 - Full speed receiver is single-ended and uses a fixed clock rate.
   Does not tolerate line noise well, so use short USB
   cables if you must use a cable at all.

 - Maximum average speed is much less than line rate,
   due to time spent pre-encoding and post-decoding.

 - SOF packets do not have an incrementing frame number
   SOF packets may not be sent on-time due to other traffic

 - We don't detect TX buffer overruns. If it hurts,
   don't do it. The RX has some protections against overrun,
   mostly untested. (Also, do not use this HC with untrusted
   devices- a babble condition can overwrite cog memory.)

Theory of Operation
-------------------

With the Propeller overclocked to 96 MHz, we have 8 clock cycles
(2 instructions) for every bit. That isn't nearly enough! So, we
cheat, and we do as much work as possible either before sending
a packet, after receiving a packet, or concurrently on another cog.

One cog is responsible for the bulk of the host controller
implementation. This is the transmit/controller cog. It accepts
commands from Spin code, handles pre-processing transmitted
data and post-processing received data, and oversees the process
of sending and receiving packets.

The grunt work of actually transmitting and receiving data is
offloaded from this cog. Transmit is handled by the TX cog's video
generator hardware. It's programmed in "VGA" mode to send two-byte
"pixels" to the D+/D- pins every 8 clock cycles. We pre-calculate
a buffer of "video" data representing each transmitted packet.

The receiver gets some help from the counters. At 80MHz we have
20 clocks or 5 instructions for every 3 bits. The counter
can store incoming bits by adding them to the PHS register.
The cog must do the shifting. So, 3 of the 5 instructions
are committed to shifting the FRQ register. We can use the other
2 for things like reading and storing the incoming data.
This ratio between clocks and instructions makes it harder to
fill a 32 bit long. We store 30 bits per long to keep things
simple.

A slight complication of using the counter as an input shift
register is that we should add each bit exactly once. The
logic A&B mode works well. A counter in duty mode produces pulses
one clock wide at a configurable frequency and phase, exactly
what we need to sample the input once per bit.  We have to use a
pin to route the sampling clock from one counter to another.

We use this pin for some additional functions as well:
 *  Waking the RX cog with waitpxx to avoid polling hub ram.
 *  Signals the receiver to start so we don't need to calculate a wakeup time.
 *  Used as a watchdog timer for the LS receiver.
 *  Enables faster upload to hub by using timers to increment address.

USBNC pin in FULL speed mode

 ________----------______||||||||||||||_____|_|_|_|_|_|______
         + Rising edge from TX cog wakes the RX cog
            + RX cog checks hub ram for the current speed
                   + Falling edge from TX cog enables receiver code
                         + RX cog CTRA generates 12MHz sampling pulses
                                            + RX cog CTRA generates 5MHz
                                              pulses to advance hub address

USBNC pin in  LOW speed mode
________----------_____----------__________|_|_|_|_|_|______
         + Rising edge from TX cog wakes the RX cog
            + RX cog checks hub ram for the current speed
                   + Falling edge from TX cog enables receiver code
                        + RX cog CTRA is started as watchdog
                                  + CTRA switched off when EOP received
                                  + or, watchdog timer expires
                                            + RX cog CTRA generates 5MHz
                                              pulses to advance hub address

In USB FS receive:
   CTRA produces 12 MHz pulses in duty mode.

While receiving LS data:
    CTRA is used in NCO mode to act as a watchdog timer for the LS receiver.

While uploading data to hub:
   CTRA produces  5 MHz pulses in duty mode.
   CTRB adds 4 the hub address for each pulse received.



The low speed receiver was designed with the following goals:
 1. Small size
 2. Easy to write
 3. Wide bitrate tolerance
Low speed devices may use resonators, which are less accurate than crystals.
The USB spec allows 1.5 % tolerance for low speed devices.
Host controllers must be within 0.05 %.
Some code written for USB device receivers may assume this tight tolerence.
To be a reliable host controller, we need to accept the wider 1.5 % range.
This receiver can theoretically tolerate 5.0 % error.

It is possible to receive and un-stuff low speed USB in real time. The codes
that do this are longer and may not have the bitrate tolerance we want.
Also, longer code reduces the size of the full speed receive buffer.

Instead of trying to sample the bits, we measure the time between transitions.
Then we calculate how many bits fit between the transitions.
This post-processing time is roughly equal to the reception time.



The other demanding operation we need to perform is a data IN
transfer. We need to transmit a token, receive a data packet, then
transmit an ACK. All back-to-back, with just a handful of bit
periods between packets. This is handled by some dedicated code
on the TX cog that does nothing but send low-latency ACKs after
the EOP state.

Since it takes much longer to decode and validate a packet than
we have before we must send an ACK, we use an inefficient but
effective "deferred ACK" strategy for IN transfers.


Programming Model
-----------------

This should look a little familiar to anyone who's written USB
drivers for a PC operating system, or used a user-level USB library
like libusb.

Public functions are provided for each supported transfer type.
(BulkRead, BulkWrite, InterruptRead...) These functions take an
endpoint descriptor, hub memory buffer, and buffer size.

All transfers are synchronous. (So, during a transfer itself,
we're really tying up 3 cogs if you count the one you called from.)
All transfers and most other functions can 'abort' with an error code.
See the E_* constants below. You must use the '\' prefix on function
calls if you want to catch these errors.

Since the transfer functions need to know both an endpoint's address
and its maximum packet size, we refer to endpoints by passing around
pointers to the endpoint's descriptor. In fact, this is how we refer
to interfaces too. This object keeps an in-memory copy of the
configuration descriptor we're using, so this data is always handy.
There are high-level functions for iterating over a device's
descriptors.

When a device is attached, call Enumerate to reset and identify it.
After Enumerate, the device will be in the 'addressed' state. It
will not be configured yet, but we'll have a copy of the device
descriptor and the first configuration descriptor in memory. To use
that default configuration, you can immediately call Configure. Now
the device is ready to use.

This host controller is a singleton object which is intended to
be instantiated only once per Propeller. Multiple objects can declare
OBJs for the host controller, but they will all really be sharing the
same instance. This will prevent you from adding multiple USB
controllers to one system, but there are also other reasons that we
don't currently support that. It's convenient, though, because this
means multiple USB device drivers can use separate instances of the
host controller OBJ to speak to the same USB port. Each device driver
can be invoked conditionally based on the device's class(es).

}}

CON
  NUM_COGS = 2

  ' Transmit / Receive Size limits.
  '
  ' Transmit size limit is based on free Cog RAM. It can be increased if we save space
  ' in the cog by optimizing the code or removing other data. Receive size is limited only
  ' by available hub ram.
  '
  ' Note that if TX_BUFFER_WORDS is too large the error is detected at compile-time, but
  ' if RX_BUFFER_WORDS is too large we won't detect the error until Start is running!

  TX_BUFFER_WORDS = 185 ' FIXME is this right?
  RX_BUFFER_WORDS = 266

  ' Maximum stored configuration descriptor size, in bytes. If the configuration
  ' descriptor is longer than this, we'll truncate it. Must be a multiple of 4.

  CFGDESC_BUFFER_LEN = 256

  ' USB data pins.
  '
  ' Important: Both DMINUS and DPLUS must be <= 7, since we
  '            use pin masks in instruction literals, and we
  '            assume we're using the first video generator bank.

  DMINUS = 1
  DPLUS = 0

  ' This no-connect pin is used for cog to cog and counter to counter signalling.
  USBNC = 2

  ' This module can be very challenging to debug. To make things a little bit easier,
  ' there are several places where debug pin masks are OR'ed into our DIRA values
  ' at compile-time. This doesn't use any additional memory. With a logic analyzer,
  ' you can use this to see exactly when the bus is being driven, and by what code.
  '
  ' To use this, pick some pin(s) to use, put their bit masks here. Attach a pull-up
  ' resistor and logic analyzer probe to each pin. To disable, set all values to zero.
  '
  ' Since the masks must fit in an instruction's immediate data, you must use P0 through P8.

  DEBUG_ACK_MASK   = 0
  DEBUG_TX_MASK    = 0

  ' Low-level debug flags, settable at runtime

  DEBUGFLAG_NO_CRC = $01

  ' Output bus states
  BUS_MASK  = (|< DPLUS) | (|< DMINUS)
  STATE_J   = |< DPLUS
  STATE_K   = |< DMINUS
  STATE_SE0 = 0
  STATE_SE1 = BUS_MASK

  ' Retry options

  MAX_TOKEN_RETRIES    = 200
  MAX_CRC_RETRIES      = 200
  TIMEOUT_FRAME_DELAY  = 10

  ' Number of CRC error retry attempts

  ' Offsets in EndpointTable
  EPTABLE_SHIFT      = 2        ' log2 of entry size
  EPTABLE_TOKEN      = 0        ' word
  EPTABLE_TOGGLE_IN  = 2        ' byte
  EPTABLE_TOGGLE_OUT = 3        ' byte

  ' Port connection status codes
  PORTC_NO_DEVICE  = STATE_SE0     ' No device (pull-down resistors in host)
  PORTC_FULL_SPEED = STATE_J       ' Full speed: pull-up on D+
  PORTC_LOW_SPEED  = STATE_K       ' Low speed: pull-up on D-
  PORTC_INVALID    = STATE_SE1     ' Buggy device? Electrical transient?
  PORTC_NOT_READY  = $FF           ' Haven't checked port status yet

  ' Command opcodes for the controller cog.

  OP_NOP           = 0                 ' Do nothing
  OP_RESET         = 1                 ' Send a USB Reset signal   '
  OP_TX_BEGIN      = 2                 ' Start a TX packet. Includes 8-bit PID
  OP_TX_END        = 3                 ' End a TX packet, arg = # of extra idle bits after
  OP_TXRX          = 4                 ' Transmit and/or receive packets
  OP_TX_DATA_16    = 5                 ' Encode and store a 16-bit word
  OP_TX_DATA_PTR   = 6                 ' Encode data from hub memory.
                                       '   Command arg: pointer
                                       '   "result" IN: Number of bytes
  OP_TX_CRC16      = 7                 ' Encode  a 16-bit CRC of all data since the PID
  OP_RX_PID        = 8                 ' Decode and return a 16-bit PID word, reset CRC-16
  OP_RX_DATA_PTR   = 9                 ' Decode data to hub memory.
                                       '   Command arg: pointer
                                       '   "result" IN: Max number of bytes
                                       '   result OUT:  Actual number of bytes
  OP_RX_CRC16      = 10                ' Decode and check CRC. Returns (actual XOR expected)
  OP_SOF_WAIT      = 11                ' Wait for one SOF to be sent

  ' OP_TXRX parameters

  TXRX_TX_ONLY     = %00
  TXRX_TX_RX       = %01
  TXRX_TX_RX_ACK   = %11

  ' USB PID values / commands

  PID_OUT    = %1110_0001
  PID_IN     = %0110_1001
  PID_SOF    = %1010_0101
  PID_SETUP  = %0010_1101
  PID_DATA0  = %1100_0011
  PID_DATA1  = %0100_1011
  PID_ACK    = %1101_0010
  PID_NAK    = %0101_1010
  PID_STALL  = %0001_1110
  PID_PRE    = %0011_1100

  ' NRZI-decoded representation of a SYNC field, and PIDs which include the SYNC.
  ' These are the form of values returned by OP_RX_PID.

  SYNC_FIELD      = %10000000
  SYNC_PID_ACK    = SYNC_FIELD | (PID_ACK << 8)
  SYNC_PID_NAK    = SYNC_FIELD | (PID_NAK << 8)
  SYNC_PID_STALL  = SYNC_FIELD | (PID_STALL << 8)
  SYNC_PID_DATA0  = SYNC_FIELD | (PID_DATA0 << 8)
  SYNC_PID_DATA1  = SYNC_FIELD | (PID_DATA1 << 8)

  ' USB Tokens (Device ID + Endpoint) with pre-calculated CRC5 values.
  ' Since we only support a single USB device, we only need tokens for
  ' device 0 (the default address) and device 1 (our arbitrary device ID).
  ' For device 0, we only need endpoint zero. For device 1, we include
  ' tokens for every possible endpoint.
  '
  '                  CRC5  EP#  DEV#
  TOKEN_DEV0_EP0  = %00010_0000_0000000
  TOKEN_DEV1_EP0  = %11101_0000_0000001
  TOKEN_DEV1_EP1  = %01011_0001_0000001
  TOKEN_DEV1_EP2  = %11000_0010_0000001
  TOKEN_DEV1_EP3  = %01110_0011_0000001
  TOKEN_DEV1_EP4  = %10111_0100_0000001
  TOKEN_DEV1_EP5  = %00001_0101_0000001
  TOKEN_DEV1_EP6  = %10010_0110_0000001
  TOKEN_DEV1_EP7  = %00100_0111_0000001
  TOKEN_DEV1_EP8  = %01001_1000_0000001
  TOKEN_DEV1_EP9  = %11111_1001_0000001
  TOKEN_DEV1_EP10 = %01100_1010_0000001
  TOKEN_DEV1_EP11 = %11010_1011_0000001
  TOKEN_DEV1_EP12 = %00011_1100_0000001
  TOKEN_DEV1_EP13 = %10101_1101_0000001
  TOKEN_DEV1_EP14 = %00110_1110_0000001
  TOKEN_DEV1_EP15 = %10000_1111_0000001

  ' Standard device requests.
  '
  ' This encodes the first two bytes of the SETUP packet into
  ' one word-sized command. The low byte is bmRequestType,
  ' the high byte is bRequest.

  REQ_CLEAR_DEVICE_FEATURE     = $0100
  REQ_CLEAR_INTERFACE_FEATURE  = $0101
  REQ_CLEAR_ENDPOINT_FEATURE   = $0102
  REQ_GET_CONFIGURATION        = $0880
  REQ_GET_DESCRIPTOR           = $0680
  REQ_GET_INTERFACE            = $0a81
  REQ_GET_DEVICE_STATUS        = $0000
  REQ_GET_INTERFACE_STATUS     = $0001
  REQ_GET_ENDPOINT_STATUS      = $0002
  REQ_SET_ADDRESS              = $0500
  REQ_SET_CONFIGURATION        = $0900
  REQ_SET_DESCRIPTOR           = $0700
  REQ_SET_DEVICE_FEATURE       = $0300
  REQ_SET_INTERFACE_FEATURE    = $0301
  REQ_SET_ENDPOINT_FEATURE     = $0302
  REQ_SET_INTERFACE            = $0b01
  REQ_SYNCH_FRAME              = $0c82

  ' Standard descriptor types.
  '
  ' These identify a descriptor in REQ_GET_DESCRIPTOR,
  ' via the high byte of wValue. (wIndex is the language ID.)
  '
  ' The 'DESCHDR' variants are the full descriptor header,
  ' including type and length. This matches the first two bytes
  ' of any such static-length descriptor.

  DESC_DEVICE           = $0100
  DESC_CONFIGURATION    = $0200
  DESC_STRING           = $0300
  DESC_INTERFACE        = $0400
  DESC_ENDPOINT         = $0500

  DESCHDR_DEVICE        = $01_12
  DESCHDR_CONFIGURATION = $02_09
  DESCHDR_INTERFACE     = $04_09
  DESCHDR_ENDPOINT      = $05_07

  ' Descriptor Formats

  DEVDESC_bLength             = 0
  DEVDESC_bDescriptorType     = 1
  DEVDESC_bcdUSB              = 2
  DEVDESC_bDeviceClass        = 4
  DEVDESC_bDeviceSubClass     = 5
  DEVDESC_bDeviceProtocol     = 6
  DEVDESC_bMaxPacketSize0     = 7
  DEVDESC_idVendor            = 8
  DEVDESC_idProduct           = 10
  DEVDESC_bcdDevice           = 12
  DEVDESC_iManufacturer       = 14
  DEVDESC_iProduct            = 15
  DEVDESC_iSerialNumber       = 16
  DEVDESC_bNumConfigurations  = 17
  DEVDESC_LEN                 = 18

  CFGDESC_bLength             = 0
  CFGDESC_bDescriptorType     = 1
  CFGDESC_wTotalLength        = 2
  CFGDESC_bNumInterfaces      = 4
  CFGDESC_bConfigurationValue = 5
  CFGDESC_iConfiguration      = 6
  CFGDESC_bmAttributes        = 7
  CFGDESC_MaxPower            = 8

  IFDESC_bLength              = 0
  IFDESC_bDescriptorType      = 1
  IFDESC_bInterfaceNumber     = 2
  IFDESC_bAlternateSetting    = 3
  IFDESC_bNumEndpoints        = 4
  IFDESC_bInterfaceClass      = 5
  IFDESC_bInterfaceSubClass   = 6
  IFDESC_bInterfaceProtocol   = 7
  IFDESC_iInterface           = 8

  EPDESC_bLength              = 0
  EPDESC_bDescriptorType      = 1
  EPDESC_bEndpointAddress     = 2
  EPDESC_bmAttributes         = 3
  EPDESC_wMaxPacketSize       = 4
  EPDESC_bInterval            = 6

  ' SETUP packet format

  SETUP_bmRequestType         = 0
  SETUP_bRequest              = 1
  SETUP_wValue                = 2
  SETUP_wIndex                = 4
  SETUP_wLength               = 6
  SETUP_LEN                   = 8

  ' Endpoint constants

  DIR_IN       = $80
  DIR_OUT      = $00

  TT_CONTROL   = $00
  TT_ISOC      = $01
  TT_BULK      = $02
  TT_INTERRUPT = $03

  ' Negative error codes. Most functions in this library can call
  ' "abort" with one of these codes.
  '
  ' So that multiple levels of the software stack can share
  ' error codes, we define a few reserved ranges:
  '
  '   -1 to -99    : Application
  '   -100 to -150 : Device or device class driver
  '   -150 to -199 : USB host controller
  '
  ' Within the USB host controller range:
  '
  '   -150 to -159 : Device connectivity errors
  '   -160 to -179 : Low-level transfer errors
  '   -180 to -199 : High-level errors (parsing, resource exhaustion)
  '
  ' When adding new errors, please keep existing errors constant
  ' to avoid breaking other modules who may depend on these values.
  ' (But if you're writing another module that uses these values,
  ' please use the constants from this object rather than hardcoding
  ' them!)

  E_SUCCESS       = 0

  E_NO_DEVICE     = -150        ' No device is attached
  E_LOW_SPEED     = -151        ' Low-speed devices are not supported
  E_PORT_BOUNCE   = -152        ' Port connection state changing during Enumerate

  E_TIMEOUT       = -160        ' Timed out waiting for a response
  E_TRANSFER      = -161        ' Generic low-level transfer error
  E_CRC           = -162        ' CRC-16 mismatch and/or babble condition
  E_TOGGLE        = -163        ' DATA0/1 toggle error
  E_PID           = -164        ' Invalid or malformed PID and/or no response
  E_STALL         = -165        ' USB STALL response (pipe error)

  E_DEV_ADDRESS   = -170        ' Enumeration error: Device addressing
  E_READ_DD_1     = -171        ' Enumeration error: First device descriptor read
  E_READ_DD_2     = -172        ' Enumeration error: Second device descriptor read
  E_READ_CONFIG   = -173        ' Enumeration error: Config descriptor read

  E_OUT_OF_COGS   = -180        ' Not enough free cogs, can't initialize
  E_OUT_OF_MEM    = -181        ' Not enough space for the requested buffer sizes
  E_DESC_PARSE    = -182        ' Can't parse a USB descriptor


DAT
  ' This is a singleton object, so we use DAT for all variables.
  ' Note that, unlike VARs, these won't be sorted automatically.
  ' Keep variables of the same type together.

txc_command   long      -1                      ' Command buffer: [23:16]=arg, [15:0]=code ptr
rx1_time      long      -1                      ' Trigger time for RX1 cog
'rx2_time      long      -1                      ' Trigger time for RX2 cog
rx2_sop       long      -1                      ' Start of packet, calculated by RX2
txc_result    long      0

heap_top      word      0                       ' Top of recycled memory heap

buf_dd        word      0                       ' Device descriptor buffer pointer
buf_cfg       word      0                       ' Configuration descriptor buffer pointer
buf_setup     word      0                       ' SETUP packet buffer pointer
last_pid_err  word      0                       ' Details from the last E_PID error

isRunning     byte      0
portc         byte      PORTC_NOT_READY         ' Port connection status
rxdone        byte      $FF
debugFlags    byte      0

DAT
''
''
''==============================================================================
'' Host Controller Setup
''==============================================================================

PUB Start

  '' Starts the software USB host controller, if it isn't already running.
  '' Requires 2 free cogs. May abort if there aren't enough free cogs, or
  '' if we run out of recycled memory while allocating buffers.
  ''
  '' This function typically doesn't need to be invoked explicitly. It will
  '' be called automatically by GetPortConnection and Enumerate.

  if isRunning
    return

  heap_top := @heap_begin
  buf_dd := alloc(DEVDESC_LEN)
  buf_cfg := alloc(CFGDESC_BUFFER_LEN)
  buf_setup := alloc(SETUP_LEN)

  ' Set up pre-cognew parameters
  sof_deadline := cnt
  rx1p_portc := txp_portc    := @portc
  txp_result   := @txc_result
  txp_rx1_time := @rx1_time
'  txp_rx2_time := @rx2_time
'  rx2p_sop     := @rx2_sop
  rx1p_sop     := @rx2_sop

'  txp_rxdone   := rx1p_done   := rx2p_done   := @rxdone
'  txp_rxbuffer := rx1p_buffer := rx2p_buffer := alloc(constant(RX_BUFFER_WORDS * 4))
  txp_rxdone   := rx1p_done   := @rxdone
  txp_rxbuffer := rx1p_buffer := alloc(constant(RX_BUFFER_WORDS * 4))

'  if cognew(@controller_cog, @txc_command)<0 or cognew(@rx_cog_1, @rx1_time)<0 or cognew(@rx_cog_2, @rx2_time)<0
  if cognew(@controller_cog, @txc_command)<0 or cognew(@rx_cog_1, @rx1_time)<0
    abort E_OUT_OF_COGS

  ' Before we start scribbling over the memory we allocated above, wait for all cogs to start.
  repeat while txc_result or rx1_time

  isRunning~~

PRI alloc(bytes) : ptr
  ' Since this object can only be instantiated once, we have no need for the
  ' cog data in hub memory once we've started our cogs. Repurpose this as buffer
  ' space.

  ptr := heap_top := (heap_top + 3) & !3
  heap_top += bytes
  if heap_top > @heap_end
    abort E_OUT_OF_MEM

PUB FrameWait(count)
  '' Wait for the controller to send 'count' Start Of Frame tokens.
  '' If one SOF has been emitted since the last call to FrameWait, it may
  '' count as the first in 'count'.
  repeat count
    Command(OP_SOF_WAIT, 0)
  Sync

PUB SetDebugFlags(flags)
  '' Set low-level debug flags.
  '' 'flags' should be a combination of DEBUGFLAG_* constants.

  debugFlags := flags

DAT
''
''==============================================================================
'' High-level Device Framework
''==============================================================================

PUB GetPortConnection
  '' Is a device connected? If so, what speed? Returns a PORTC_* constant.
  '' Starts the host controller if it isn't already running.

  Start
  repeat while portc == PORTC_NOT_READY
  return portc

PUB Enumerate | pc
  '' Initialize the attached USB device, and get information about it.
  ''
  ''   1. Reset the device
  ''   2. Assign it an address
  ''   3. Read the device descriptor
  ''   4. Read the first configuration descriptor
  ''
  '' Starts the host controller if it isn't already running.

  ' Port debounce: Make sure the device is in the
  ' same connection state for a couple frames.

  pc := GetPortConnection
  FrameWait(3)
  if GetPortConnection <> pc
    abort E_PORT_BOUNCE

  case pc
    PORTC_NO_DEVICE, PORTC_INVALID:
      abort E_NO_DEVICE
    'PORTC_LOW_SPEED:
    '  abort E_LOW_SPEED

  ' Device reset, and give it some time to wake up
  DeviceReset
  FrameWait(10)
  DefaultMaxPacketSize0

  if 0 > \DeviceAddress
    abort E_DEV_ADDRESS

  ' Read the real max packet length (Must request exactly 8 bytes)
  if 0 > \ControlRead(REQ_GET_DESCRIPTOR, DESC_DEVICE, 0, buf_dd, 8)
    abort E_READ_DD_1

  ' Validate device descriptor header
  if WORD[buf_dd] <> DESCHDR_DEVICE
    abort E_DESC_PARSE

  ' Read the whole descriptor
  if 0 > \ControlRead(REQ_GET_DESCRIPTOR, DESC_DEVICE, 0, buf_dd, DEVDESC_LEN)
    abort E_READ_DD_2

  ReadConfiguration(0)


PUB DefaultMaxPacketSize0

  ' Before we can do any transfers longer than 8 bytes, we need to know the maximum
  ' packet size on EP0. Otherwise we won't be able to determine when a transfer has
  ' ended. So, we'll use a temporary maximum packet size of 8 in order to address the
  ' device and to receive the first 8 bytes of the device descriptor. This should
  ' always be possible using transfers of no more than one packet in length.

  BYTE[buf_dd + DEVDESC_bMaxPacketSize0] := 8


PUB Configure
  '' Switch device configurations. This (re)configures the device according to
  '' the currently loaded configuration descriptor. To use a non-default configuration,
  '' call ReadConfiguration() to load a different descriptor first.

  ResetEndpointToggle
  Control(REQ_SET_CONFIGURATION, BYTE[buf_cfg + CFGDESC_bConfigurationValue], 0)

PUB UnConfigure
  '' Place the device back in its un-configured state.
  '' In the unconfigured state, only the default control endpoint may be used.

  Control(REQ_SET_CONFIGURATION, 0, 0)

PUB ReadConfiguration(index)
  '' Read in a configuration descriptor from the device. Most devices have only one
  '' configuration, and we load it automatically in Enumerate. So you usually don't
  '' need to call this function. But if the device has multiple configurations, you
  '' can use this to get information about them all.
  ''
  '' This does not actually switch configurations. If this newly read configuration
  '' is indeed the one you want to use, call Configure.

  if 0 > \ControlRead(REQ_GET_DESCRIPTOR, DESC_CONFIGURATION | index, 0, buf_cfg, CFGDESC_BUFFER_LEN)
    abort E_READ_CONFIG

  if WORD[buf_cfg] <> DESCHDR_CONFIGURATION
    abort E_DESC_PARSE

PUB DeviceDescriptor : ptr
  '' Get a pointer to the enumerated device's Device Descriptor
  return buf_dd

PUB ConfigDescriptor : ptr
  '' Get a pointer to the last config descriptor read with ReadConfiguration().
  '' If the configuration was longer than CFGDESC_BUFFER_LEN, it will be truncated.
  return buf_cfg

PUB VendorID : devID
  '' Get the enumerated device's 16-bit Vendor ID
  return WORD[buf_dd + DEVDESC_idVendor]

PUB ProductID : devID
  '' Get the enumerated device's 16-bit Product ID
  return WORD[buf_dd + DEVDESC_idProduct]

PUB ClearHalt(epd)
  '' Clear a Halt condition on one endpoint, given a pointer to the endpoint descriptor

  Control(REQ_CLEAR_ENDPOINT_FEATURE, 0, BYTE[epd + EPDESC_bEndpointAddress])


DAT
''
''==============================================================================
'' Configuration Descriptor Parsing
''==============================================================================

PUB NextDescriptor(ptrIn) : ptrOut | endPtr
  '' Advance to the next descriptor within the configuration descriptor.
  '' If there is another descriptor, returns a pointer to it. If we're at
  '' the end of the descriptor or the buffer, returns 0.

  ptrOut := ptrIn + BYTE[ptrIn]
  endPtr := buf_cfg + (WORD[buf_cfg + CFGDESC_wTotalLength] <# CFGDESC_BUFFER_LEN)

  if ptrOut => endPtr
    ptrOut~

PUB NextHeaderMatch(ptrIn, header) : ptrOut
  '' Advance to the next descriptor which matches the specified header.

  repeat while ptrIn := NextDescriptor(ptrIn)
    if UWORD(ptrIn) == header
      return ptrIn
  return 0

PUB FirstInterface : firstIf
  '' Return a pointer to the first interface in the current config
  '' descriptor. If there were no valid interfaces, returns 0.

  return NextInterface(buf_cfg)

PUB NextInterface(curIf) : nextIf
  '' Advance to the next interface after 'curIf' in the current
  '' configuration descriptor. If there are no more interfaces, returns 0.

  return NextHeaderMatch(curIf, DESCHDR_INTERFACE)

PUB NextEndpoint(curIf) : nextIf
  '' Advance to the next endpoint after 'curIf' in the current
  '' configuration descriptor. To get the first endpoint in an interface,
  '' pass in a pointer to the interface descriptor.
  ''
  '' If there are no more endpoints in this interface, returns 0.

  repeat while curIf := NextDescriptor(curIf)
    case UWORD(curIf)
      DESCHDR_ENDPOINT:
        return curIf
      DESCHDR_INTERFACE:
        return 0

  return 0

PUB FindInterface(class) : foundIf
  '' Look for the first interface which has the specified class.
  '' If no such interface exists on the current configuration, returns 0.

  foundIf := FirstInterface
  repeat while foundIf
    if BYTE[foundIf + IFDESC_bInterfaceClass] == class
      return foundIf
    foundIf := NextInterface(foundIf)

PUB EndpointDirection(epd)
  '' Given an endpoint descriptor pointer, test the endpoint direction.
  '' (DIR_IN or DIR_OUT)

  return BYTE[epd + EPDESC_bEndpointAddress] & $80

PUB EndpointType(epd)
  '' Return an endpoint's transfer type (TT_BULK, TT_ISOC, TT_INTERRUPT)

  return BYTE[epd + EPDESC_bmAttributes] & $03


PUB UWORD(addr) : value
  '' Like WORD[addr], but works on unaligned addresses too.
  '' You must use this rather than WORD[] when reading 16-bit values
  '' from descriptors, since descriptors have no alignment guarantees.

  return BYTE[addr] | (BYTE[addr + 1] << 8)


DAT
''
''==============================================================================
'' Device Setup
''==============================================================================

PUB DeviceReset
  '' Asynchronously send a USB bus reset signal.

  Command(OP_RESET, 0)
  ResetEndpointToggle

PUB DeviceAddress | buf

  '' Send a SET_ADDRESS(1) to device 0.
  ''
  '' This should be sent after DeviceReset to transition the
  '' device from the Default state to the Addressed state. All
  '' other transfers here assume the device address is 1.

  WORD[buf_setup] := REQ_SET_ADDRESS
  WORD[buf_setup + SETUP_wValue] := 1
  LONG[buf_setup + SETUP_wIndex]~

  ControlRaw(TOKEN_DEV0_EP0, @buf, 4)

DAT
''
''==============================================================================
'' Control Transfers
''==============================================================================

PUB Control(req, value, index) | buf

  '' Issue a no-data control transfer to an addressed device.

  WORD[buf_setup] := req
  WORD[buf_setup + SETUP_wValue] := value
  WORD[buf_setup + SETUP_wIndex] := index
  WORD[buf_setup + SETUP_wLength]~

  return ControlRaw(TOKEN_DEV1_EP0, @buf, 4)

PUB ControlRead(req, value, index, bufferPtr, length) | toggle

  '' Issue a control IN transfer to an addressed device.
  ''
  '' Returns the number of bytes read.
  '' Aborts on error.

  WORD[buf_setup] := req
  WORD[buf_setup + SETUP_wValue] := value
  WORD[buf_setup + SETUP_wIndex] := index
  WORD[buf_setup + SETUP_wLength] := length

  ' Issues SETUP and IN transactions
  result := ControlRaw(TOKEN_DEV1_EP0, bufferPtr, length)

  ' Status phase (OUT + DATA1)
  toggle := PID_DATA1
  WriteData(PID_OUT, TOKEN_DEV1_EP0, 0, 0, @toggle, MAX_TOKEN_RETRIES)

PUB ControlWrite(req, value, index, bufferPtr, length) | toggle, pktSize0, packetSize

  '' Issue a control OUT transfer to an addressed device.

  WORD[buf_setup] := req
  WORD[buf_setup + SETUP_wValue] := value
  WORD[buf_setup + SETUP_wIndex] := index
  WORD[buf_setup + SETUP_wLength] := length

  toggle := PID_DATA0
  WriteData(PID_SETUP, TOKEN_DEV1_EP0, buf_setup, 8, @toggle, MAX_TOKEN_RETRIES)

  ' Break OUT data into multiple packets if necessary
  pktSize0 := BYTE[buf_dd + DEVDESC_bMaxPacketSize0]
  repeat
    packetSize := length <# pktSize0
    WriteData(PID_OUT, TOKEN_DEV1_EP0, bufferPtr, packetSize, @toggle, MAX_TOKEN_RETRIES)
    bufferPtr += packetSize
    if (length -= packetSize) =< 0

      ' Status stage (always DATA1)
      toggle := PID_DATA1
      return DataIN(TOKEN_DEV1_EP0, @packetSize, 4, pktSize0, @toggle, TXRX_TX_RX_ACK, MAX_TOKEN_RETRIES, 1)

PUB ControlRaw(token, buffer, length) | toggle

  ' Common low-level implementation of no-data and read control transfers.

  toggle := PID_DATA0
  WriteData(PID_SETUP, token, buf_setup, 8, @toggle, MAX_TOKEN_RETRIES)
  return DataIN(token, buffer, length, BYTE[buf_dd + DEVDESC_bMaxPacketSize0], @toggle, TXRX_TX_RX_ACK, MAX_TOKEN_RETRIES, 1)

PUB SetupBuffer
  return buf_setup


DAT
''
''==============================================================================
'' Interrupt Transfers
''==============================================================================

PUB InterruptRead(epd, buffer, length) : actual | epTable

  '' Try to read one packet, up to 'length' bytes, from an Interrupt IN endpoint.
  '' Returns the actual amount of data read.
  '' If no data is available, raises E_TIMEOUT without waiting.
  ''
  '' 'epd' is a pointer to this endpoint's Endpoint Descriptor.

  ' This is different from Bulk in two main ways:
  '
  '   - We give DataIN an artificially large maxPacketSize, since we
  '     never want it to receive more than one packet at a time here.
  '   - We give it a retry of 0, since we don't want to retry on NAK.

  epTable := EndpointTableAddr(epd)
  return DataIN(WORD[epTable], buffer, length, $1000, epTable + EPTABLE_TOGGLE_IN, TXRX_TX_RX, 0, MAX_CRC_RETRIES)


DAT
''
''==============================================================================
'' Bulk Transfers
''==============================================================================

PUB BulkWrite(epd, buffer, length) | packetSize, epTable, maxPacketSize

  '' Write 'length' bytes of data to a Bulk OUT endpoint.
  ''
  '' Always writes at least one packet. If 'length' is zero,
  '' we send a zero-length packet. If 'length' is any other
  '' even multiple of maxPacketLen, we send only maximally-long
  '' packets and no zero-length packet.
  ''
  '' 'epd' is a pointer to this endpoint's Endpoint Descriptor.

  epTable := EndpointTableAddr(epd)
  maxPacketSize := EndpointMaxPacketSize(epd)

  repeat
    packetSize := length <# maxPacketSize

    WriteData(PID_OUT, WORD[epTable], buffer, packetSize, epTable + EPTABLE_TOGGLE_OUT, MAX_TOKEN_RETRIES)

    buffer += packetSize
    if (length -= packetSize) =< 0
      return

PUB BulkRead(epd, buffer, length) : actual | epTable

  '' Read up to 'length' bytes from a Bulk IN endpoint.
  '' Returns the actual amount of data read.
  ''
  '' 'epd' is a pointer to this endpoint's Endpoint Descriptor.

  epTable := EndpointTableAddr(epd)
  return DataIN(WORD[epTable], buffer, length, EndpointMaxPacketSize(epd), epTable + EPTABLE_TOGGLE_IN, TXRX_TX_RX, MAX_TOKEN_RETRIES, MAX_CRC_RETRIES)

DAT

'==============================================================================
' Low-level Transfer Utilities
'==============================================================================

PUB EndpointTableAddr(epd) : addr
  ' Given an endpoint descriptor, return the address of our EndpointTable entry.

  return @EndpointTable + ((BYTE[epd + EPDESC_bEndpointAddress] & $F) << EPTABLE_SHIFT)

PUB EndpointMaxPacketSize(epd) : maxPacketSize
  ' Parse the max packet size out of an endpoint descriptor

  return UWORD(epd + EPDESC_wMaxPacketSize)

PUB ResetEndpointToggle | ep
  ' Reset all endpoints to the default DATA0 toggle

  ep := @EndpointTable
  repeat 16
    BYTE[ep + EPTABLE_TOGGLE_IN] := BYTE[ep + EPTABLE_TOGGLE_OUT] := PID_DATA0
    ep += constant(|< EPTABLE_SHIFT)

PUB DataIN(token, buffer, length, maxPacketLen, togglePtr, txrxFlag, tokenRetries, crcRetries) : actual | packetLen

  ' Issue IN tokens and read the resulting data packets until
  ' a packet smaller than maxPacketLen arrives. On success,
  ' returns the actual number of bytes read. On failure, returns
  ' a negative error code.
  '
  ' 'togglePtr' is a pointer to a byte with either PID_DATA0 or
  ' PID_DATA1, depending on which DATA PID we expect next. Every
  ' time we receive a packet, we toggle this byte from DATA0 to
  ' DATA1 or vice versa.
  '
  ' Each packet will have up to 'retries' additional attempts
  ' if the device responds with a NAK.

  actual~

  ' As long as there's buffer space, send IN tokens. Each IN token
  ' allows the device to send us back up to maxPacketLen bytes of data.
  ' If the device sends a short packet (including zero-byte packets)
  ' it terminates the transfer.

  repeat
    packetLen := ReadDataIN(token, buffer, length, togglePtr, txrxFlag, tokenRetries, crcRetries)
    actual += packetLen
    buffer += packetLen
    length -= packetLen

    if packetLen < maxPacketLen
      return  ' Short packet. Device ended the transfer early.
    if length =< 0
      return  ' Transfer fully completed

PUB WriteData(pid, token, buffer, length, togglePtr, retries)

  ' Transmit a single data packet to an endpoint, as a token followed by DATA.
  '
  ' 'togglePtr' is a pointer to a byte with either PID_DATA0 or
  ' PID_DATA1, depending on which DATA PID we expect next. Every
  ' time we receive a packet, we toggle this byte from DATA0 to
  ' DATA1 or vice versa.
  '
  ' Each packet will have up to 'retries' additional attempts
  ' if the device responds with a NAK.

  repeat
    SendToken(pid, token, 10)
    Command(OP_TX_BEGIN, BYTE[togglePtr])      ' DATA0/1

    if length
      Sync
      txc_result := length
      Command(OP_TX_DATA_PTR, buffer)

    Command(OP_TX_CRC16, 0)
    Command(OP_TX_END, 1)
    Command(OP_TXRX, TXRX_TX_RX)

    Command(OP_RX_PID, 0)
    Sync
    case txc_result

      SYNC_PID_NAK:
        ' Busy. Wait a frame and try again.
        if --retries =< 0
          abort E_TIMEOUT
        FrameWait(TIMEOUT_FRAME_DELAY)

      SYNC_PID_STALL:
        abort E_STALL

      SYNC_PID_ACK:
        BYTE[togglePtr] ^= constant(PID_DATA0 ^ PID_DATA1)
        return E_SUCCESS

      other:
        last_pid_err := txc_result
        abort E_PID

PUB RequestDataIN(token, txrxFlag, togglePtr, retries)

  ' Low-level data IN request. Handles data toggle and retry.
  ' This is part of the implementation of DataIN().
  ' Aborts on error, otherwise returns the EOP timestamp.

  repeat
    SendToken(PID_IN, token, 0)

    Command(OP_TXRX, txrxFlag)
    Sync
    result := txc_result

    Command(OP_RX_PID, 0)
    Sync
    case txc_result

      SYNC_PID_NAK:
        ' Busy. Wait a frame and try again.
        if --retries =< 0
          abort E_TIMEOUT
        FrameWait(TIMEOUT_FRAME_DELAY)

      SYNC_PID_STALL:
        abort E_STALL

      SYNC_PID_DATA0, SYNC_PID_DATA1:
        if (txc_result >> 8) <> BYTE[togglePtr]
          abort E_TOGGLE
        if txrxFlag == TXRX_TX_RX_ACK
          ' Only toggle if we're ACK'ing this packet
          BYTE[togglePtr] ^= constant(PID_DATA0 ^ PID_DATA1)
        return

      other:
        last_pid_err := txc_result
        abort E_PID

PRI ReadDataIN(token, buffer, length, togglePtr, txrxFlag, tokenRetries, crcRetries) | pc

  ' Low-level data IN request + read to buffer.
  ' This is part of the implementation of DataIN().
  ' Aborts on error, otherwise returns the actual number of bytes read.

  ' This implements our crazy "deferred ACK" scheme, to work around
  ' the fact that we can't decode a packet fast enough to check it prior
  ' to sending the ACK when we're supposed to. In this strategy, we send
  ' multiple IN tokens for each actual packet we intend to read, and postpone
  ' the ACK by one packet. The first packet is never acknowledged. The second
  ' will be ACK'ed only if the first was checked successfully. And so on.
  ' Normally this means that there are two packets: The first one is decoded
  ' but not ACKed, and the second one is ACKed but the contents are ignored.
  ' (We assume it's identical to the first.)
  '
  ' To use deferred ACKs, set txrxFlag to TXRX_TX_RX. To ACK the first
  ' response (before the CRC check) set txrxFlag to TXRX_TX_RX_ACK.
  ' If deferred ACKs are NOT in use, crcRetries must be 1.
  '
  ' We're currently using deferred ACKs only for Bulk and Interrupt INs.
  ' Some devices don't handle non-acknowledged IN packets during control
  ' transfers, so we still have the possibility of CRC errors during control
  ' reads. Luckily, most such transfers can be retried at a higher
  ' protocol level.

  repeat crcRetries

    ' The process of actually decoding the received packet is a bit convoluted,
    ' due to the split of responsibilities between the RX cogs, TX cog, and
    ' Spin code:
    '
    '   - The RX cogs don't really detect the EOP condition, they just stop when
    '     the D- line has been zero for a while. But they do record an accurate
    '     SOP timestamp.
    '
    '   - The TX cog records a fairly accurate EOP timestamp
    '
    '   - Spin code uses these timestamps to figure out the maximum number of
    '     bits that reside in a packet, minus the CRC and header.
    '
    '   - The decoder is given both a bit and byte limit, so it stops writing
    '     when either the buffer fills up or we reach the calculated EOP minus
    '     CRC position.

    ' Calculate the actual packet length.
    '
    ' RequestDataIN returns an EOP timestamp. The TX cog knew when the EOP
    ' was, and the RX2 cog knew when SOP was. We're running at 8 clocks
    ' per bit, or 64 clocks per byte. Convert clocks to bits.
    '
    ' We subtract enough bits to cover the CRC-16 and PID. The decoder needs us
    ' to account for slightly less bits than we're actually receiving, since it
    ' stops after the bit count underflows. To round evenly we could subtract half
    ' a byte, but we only subtract a couple due to the additional CRC-16 bit stuffing
    ' bits we haven't accounted for. (These are guaranteed to cause less than one
    ' byte's worth of difference in the calculation if we do this right.)
    '
    ' The full offset calculation is:
    '
    '    headerBits   = 16
    '    crcBits      = 16
    '    roundingBits = 4
    '
    '    offset = (headerBits + crcBits + roundingBits) * 8 - 4 = 284

    ' new offset for 80MHz clock   6 2/3 clocks per bit
    '    offset = (headerBits + crcBits + roundingBits) * (20/3) - 4 = 236

    pc := GetPortConnection
    if pc == PORTC_LOW_SPEED
        result := ((RequestDataIN(token, txrxFlag, togglePtr, tokenRetries) - rx2_sop - 1916)*3)/20/8
    else
        result := ((RequestDataIN(token, txrxFlag, togglePtr, tokenRetries) - rx2_sop - 236)*3)/20

    if result =< 0
      result~ ' Zero-length packet. Device ended the transfer early
    elseif length =< 0
      result~ ' We don't want the data, the caller is just checking for a good PID. We're done.
    else
      ' The packet wasn't zero-length. Figure out how many bytes it was while
      ' we were decoding. The parameters for OP_RX_DATA_PTR are very counterintuitive,
      ' see the assembly code for a complete description. After the call, packetLen
      ' contains the number of actual bytes stored.
      Sync
      txc_result := ((length - 1) << 16) | result
      Command(OP_RX_DATA_PTR, buffer)
      Sync
      result := WORD[@txc_result] - buffer

      ' We currently can't tell whether RX_DATA_PTR ended because it hit the
      ' bit limit or because it hit the byte limit. If it hit the bit limit, all
      ' is well and we should be receiving the whole packet. But if it hit the byte
      ' limit, this is actually a babble condition. We stopped short, and the receive
      ' buffer isn't pointing at the actual CRC.
      '
      ' This is why E_CRC can mean either a CRC error or a babble error.

      Command(OP_RX_CRC16, 0)
      Sync
      if txc_result and not (debugFlags & DEBUGFLAG_NO_CRC)
        result := E_CRC

    if result => 0
      ' Success. ACK (if we haven't already) and get out.
      if txrxFlag <> TXRX_TX_RX_ACK
        RequestDataIN(token, TXRX_TX_RX_ACK, togglePtr, tokenRetries)
      return

  ' Out of CRC retries
  abort

PUB SendToken(pid, token, delayAfter)
  '' Enqueue a token in the TX buffer

  Command(OP_TX_BEGIN, pid)
  Command(OP_TX_DATA_16, token)
  Command(OP_TX_END, delayAfter)

PUB LastPIDError
  '' Return the raw 16-bit frame from the last E_PID error

  return last_pid_err


DAT

'==============================================================================
' Low-level Command Interface
'==============================================================================

PUB Sync
  ' Wait for the driver cog to finish what it was doing.
  repeat while txc_command

PUB Command(cmd, arg) | packed
  ' Asynchronously execute a low-level driver cog command.
  ' To save space in the driver cog, the conversion from
  ' command ID to address happens here, and we pack the
  ' address and 16-bit argument into the command word.

  packed := lookup(cmd: @cmd_reset, @cmd_tx_begin, @cmd_tx_end, @cmd_txrx, @cmd_tx_data_16, @cmd_tx_data_ptr, @cmd_tx_crc16, @cmd_rx_pid, @cmd_rx_data_ptr, @cmd_rx_crc16, @cmd_sof_wait)
  packed := ((packed - @controller_cog) >> 2) | (arg << 16)
  Sync
  txc_command := packed

PUB CommandResult
  Sync
  return txc_result

PUB CommandExtra(arg)
  Sync
  txc_result := arg


DAT

'==============================================================================
' Endpoint State Table
'==============================================================================

' For each endpoint number, we have:
'
' Offset    Size    Description
' ----------------------------------------------------
'  0        Word    Token (device, endpoint, crc5)
'  2        Byte    Toggle for IN endpoint (PID_DATA0 / PID_DATA1)
'  3        Byte    Toggle for OUT endpoint

EndpointTable           word    TOKEN_DEV1_EP0, 0
                        word    TOKEN_DEV1_EP1, 0
                        word    TOKEN_DEV1_EP2, 0
                        word    TOKEN_DEV1_EP3, 0
                        word    TOKEN_DEV1_EP4, 0
                        word    TOKEN_DEV1_EP5, 0
                        word    TOKEN_DEV1_EP6, 0
                        word    TOKEN_DEV1_EP7, 0
                        word    TOKEN_DEV1_EP8, 0
                        word    TOKEN_DEV1_EP9, 0
                        word    TOKEN_DEV1_EP10, 0
                        word    TOKEN_DEV1_EP11, 0
                        word    TOKEN_DEV1_EP12, 0
                        word    TOKEN_DEV1_EP13, 0
                        word    TOKEN_DEV1_EP14, 0
                        word    TOKEN_DEV1_EP15, 0

DAT

heap_begin    ' Begin recyclable memory heap

'==============================================================================
' Controller / Transmitter Cog
'==============================================================================

' This is the "main" cog in the host controller. It processes commands that arrive
' from Spin code. These commands can build encoded USB packets in a local buffer,
' and transmit them. Multiple packets can be buffered back-to-back, to reduce the
' gap between packets to an acceptable level.
'
' This cog also handles triggering our two receiver cogs. Two receiver cogs are
' interleaved, so we can receive packets larger than what will fit in a single
' cog's unrolled loop.
'
' The receiver cogs are also responsible for managing the bus ownership, and the
' handoff between a driven idle state and an undriven idle. We calculate timestamps
' at which the receiver cogs will perform this handoff.

              org
controller_cog

              '======================================================
              ' Cog Initialization
              '======================================================

              ' Initialize the PLL and video generator for 12 MB/s output.
              ' This sets up CTRA as a divide-by-8, with no PLL multiplication.
              ' Use 2bpp "VGA" mode, so we can insert SE0 states easily. Every
              ' two bits we send to waitvid will be two literal bits on D- and D+.

              ' To start with, we leave the pin mask in vcfg set to all zeroes.
              ' At the moment we're actually ready to transmit, we set the mask.
              '
              ' We also re-use this initialization code space for temporary variables.

tx_count      mov       ctra, ctra_value
t1            mov       frqa, frqa_value
l_cmd         mov       vcfg, vcfg_value
codec_buf     mov       vscl, vscl_value

codec_cnt     call      #enc_reset

              '======================================================
              ' Command Processing
              '======================================================

              ' Wait until there's a command available or it's time to send a SOF.
              ' SOF is more important than a command, but we have no way of ensuring
              ' that a SOF won't need to occur during a command- so the SOF might be
              ' late.

cmdret
              ' Reduce jitter between spin code and the USB packets, for experiments where that matters
              waitvid   v_palette, v_idle
              waitvid   v_palette, v_idle

              wrlong    c_zero, par
              andn      outa, c_00010000

command_loop
              mov       t1, cnt                 ' cnt - sof_deadline, store sign bit
              sub       t1, sof_deadline
              rcl       t1, #1 wc               ' C = deadline is in the future
        if_nc tjz       tx_count, #tx_sof       ' Send the SOF if the buffer is not in use

              rdlong    l_cmd, par wz           ' Look for an incoming command
        if_z  jmp       #command_loop

              movs      :cmdjmp, l_cmd          ' Handler address in low 16 bits
              rol       l_cmd, #16              ' Now parameter is in low 16 bits
:cmdjmp       jmp       #0

              '======================================================
              ' SOF Packets / PORTC Sampling
              '======================================================

              ' If we're due for a SOF and we're between packets,
              ' this routine is called to transmit the SOF packet.
              '
              ' We're allowed to use the transmit buffer, but we must
              ' not return via 'cmdret', since we don't want to clear
              ' our command buffer- if another cog wrote a command
              ' while we're processing the SOF, we would miss it.
              ' So we need to use the lower-level encoder routines
              ' instead of calling other command implementations.
              '
              ' This happens to also be a good time to sample the port
              ' connection status. When the bus is idle, its state tells
              ' us whether a device is connected, and what speed it is.
              ' We need to sample this when the bus is idle, and this
              ' is a convenient time to do so. We can also skip sending
              ' the SOF if the bus isn't in a supported state.

tx_sof
              xor       cmd_sof_wait, c_condition     ' Let an SOF wait through.
                                                      ' (Swap from if_always to if_never)

              mov       t1, ina
              and       t1, #BUS_MASK
              wrbyte    t1, txp_portc                 ' Save idle bus state as PORTC
              cmp       t1, #PORTC_FULL_SPEED wz      ' Z if full speed
        if_z  jmp       #:sof_full

              mov       v_palette,v_palette_low       ' switch the tx speed while time is not critical
              mov       vscl_value,vscl_low           '
              cmp       t1, #PORTC_LOW_SPEED wz       ' Z if low speed
       if_nz  jmp       #:skip                        ' skip if not low speed
              jmp       #:sof_low

:sof_full
              mov       v_palette,v_palette_full      ' switch the tx speed while time is not critical
              mov       vscl_value,vscl_full          '

              call      #encode_sync                  ' SYNC field

              mov       codec_buf, sof_frame          ' PID and Token
              mov       codec_cnt, #24
              call      #encode
:sof_low

              call      #encode_eop                   ' End of packet and inter-packet delay
              call      #encode_idle ' this added to FS too!

              mov       l_cmd, #0                     ' TX only, no receive
              call      #txrx
              jmp       #:skip

              ' LOW speed uses keep-alive pulses instead of SOF
':keepalive
'              cmp       t1, #PORTC_LOW_SPEED wz
'        if_nz jmp       #:skip                        ' Only send keepalive to low-speed devices

'              mov       t1,#100     ' delay
'              djnz      t1,#$                         '

'              mov       t1,#25     ' 4*N + 8 clocks = 2 bit times (N=25)
'              andn      outa, #BUS_MASK
'              or        dira, #BUS_MASK               ' Send keep-alive
'              djnz      t1,#$                         '
'              or        outa, #PORTC_LOW_SPEED        ' Drive idle
'              mov       t1,#25     ' 4*N + 8 clocks = 2 bit times (N=25)
'              djnz      t1,#$                         '
'              andn      dira, #BUS_MASK               ' release bus
'              andn      outa, #BUS_MASK
'              call      #enc_reset                    ' May not be needed, but txrx does it

:skip
              add       sof_deadline, sof_period

              jmp       #command_loop

              '======================================================
              ' OP_TX_BEGIN
              '======================================================

              ' When we begin a packet, we'll always end up generating
              ' 16 bits (8 sync, 8 pid) which will fill up the first long
              ' of the transmit buffer. So it's legal to use tx_count!=0
              ' to detect whether we're using the transmit buffer.

cmd_tx_begin
              call      #encode_sync

              ' Now NRZI-encode the PID field

              mov       codec_buf, l_cmd
              mov       codec_cnt, #8
              call      #encode

              ' Reset the CRC-16, it should cover only data from after the PID.

              mov       enc_crc16, crc16_mask

              jmp       #cmdret

              '======================================================
              ' OP_TX_END
              '======================================================

cmd_tx_end
              call      #encode_eop
:idle_loop
              test      l_cmd, #$1FF wz
        if_z  jmp       #cmdret
              call      #encode_idle
              sub       l_cmd, #1
              jmp       #:idle_loop

              '======================================================
              ' OP_TX_DATA_16
              '======================================================

cmd_tx_data_16
              mov       codec_buf, l_cmd
              mov       codec_cnt, #16
              call      #encode

              jmp       #cmdret

              '======================================================
              ' OP_TX_DATA_PTR
              '======================================================

              ' Byte count in "result", hub pointer in l_cmd[15:0].
              '
              ' This would be faster if we processed in 32-bit
              ' chunks when possible (at least 4 bytes left, pointer is
              ' long-aligned) but right now we're optimizing for simplicity
              ' and small code size.

cmd_tx_data_ptr
              rdlong    t1, txp_result

:loop         rdbyte    codec_buf, l_cmd
              mov       codec_cnt, #8
              add       l_cmd, #1
              call      #encode
              djnz      t1, #:loop

              jmp       #cmdret

              '======================================================
              ' OP_TX_CRC16
              '======================================================

cmd_tx_crc16
              mov       codec_buf, enc_crc16
              xor       codec_buf, crc16_mask
              mov       codec_cnt, #16
              call      #encode

              jmp       #cmdret

              '======================================================
              ' OP_TXRX
              '======================================================

cmd_txrx
              call      #txrx
              jmp       #cmdret

              '======================================================
              ' OP_RESET
              '======================================================

cmd_reset

              andn      outa, #BUS_MASK         ' Start driving SE0
              or        dira, #BUS_MASK

              mov       t1, cnt
              add       t1, reset_period
              waitcnt   t1, #0

              andn      dira, #BUS_MASK         ' Stop driving
              mov       sof_deadline, cnt       ' Ignore SOFs that should have occurred

              jmp       #cmdret

              '======================================================
              ' OP_RX_PID
              '======================================================

              ' Receive a 16-bit word, and reset the CRC-16.
              ' For use in receiving and validating a packet's SYNC/PID header.

cmd_rx_pid
              mov       codec_cnt, #16
              call      #decode
              shr       codec_buf, #16
              wrlong    codec_buf, txp_result

              mov       dec_crc16, crc16_mask   ' Reset the CRC-16

              jmp       #cmdret

              '======================================================
              ' OP_RX_DATA_PTR
              '======================================================

              ' Parameters:
              '   - Hub pointer in the command word
              '   - Maximum raw bit count in result[15:0]
              '   - Maximum byte count in result[31:16]
              '
              ' Returns:
              '   - Final write pointer (actual byte count + original pointer)
              '
              ' Always decodes at least one byte.
              '
              ' This would be faster if we processed in 32-bit
              ' chunks when possible (at least 4 bytes left, pointer is
              ' long-aligned) but right now we're optimizing for simplicity.
              '
              ' If this is modified to operate on 32-bit words in the future,
              ' this optimization must only take effect when the remaining bit
              ' count is high enough that we're guaranteed not to hit the bit
              ' limit during the 32-bit word. The returned actual byte count
              ' MUST have one-byte granularity.
              '
              ' We stop receiving when the byte or bit counts underflow. So both
              ' counts should be one byte under the actual values.

cmd_rx_data_ptr
              rdlong    t1, txp_result          ' Byte/bit count

:loop         mov       codec_cnt, #8           ' One byte at a time
              sub       t1, c_00010000          ' Decrements byte count
              call      #decode                 ' Decrements bit count
              shr       codec_buf, #24          ' Right-justify result
              wrbyte    codec_buf, l_cmd        ' Store result
              add       l_cmd, #1               ' Pointer + 1
              test      t1, c_80008000 wz       ' Detect bit or byte underflow
        if_z  jmp       #:loop

              wrword    l_cmd, txp_result
              jmp       #cmdret

              '======================================================
              ' OP_RX_CRC16
              '======================================================

cmd_rx_crc16
              xor       dec_crc16, crc16_mask   ' Save CRC of payload
              mov       t3, dec_crc16

              mov       codec_cnt, #16
              call      #decode

              shr       codec_buf, #16          ' Justify received CRC
              xor       t3, codec_buf           ' Compare
              wrlong    t3, txp_result          ' and return
              jmp       #cmdret

              '======================================================
              ' OP_SOF_WAIT
              '======================================================

              ' Normally this jumps back to the command loop without
              ' completing the command. In tx_sof, this code is modified
              ' to return exactly once.
              '
              ' (The modification works by patching the condition code on the
              ' first instruction in this routine.)

cmd_sof_wait  jmp       #command_loop
              xor       cmd_sof_wait, c_condition       ' Swap from if_never to if_always
              jmp       #cmdret


              '======================================================
              ' Transmit / Receive Front-end
              '======================================================

txrx
              ' Save the raw transmit length, not including padding,
              ' then pad our buffer to a multiple of 16 (one video word).

              mov       tx_count_raw, tx_count
:pad          test      tx_count, #%1111 wz
        if_z  jmp       #:pad_done
              call      #encode_idle
              jmp       #:pad
:pad_done

              ' Reset the receiver state (regardless of whether we're using it)

              wrbyte    v_idle, txp_rxdone      ' Arbitrary nonzero byte

              rcr       l_cmd, #1 wc            ' C = bit0 = RX Enable

              ' The RX cog clock pin can be reused as a wakeup pin.
              ' This is great because we don't have to calculate the wakup time
              ' and we save power by using waitpeq instead of looping.
              or        dira, tx_ncmask        ' Maybe put this somewhere else
       if_c   or        outa, tx_ncmask        ' Get ready for falling edge later

              ' Right now tx_count_raw is the number of bits
              ' in the packet. Convert it to a loop count we can
              ' use to line up our EOP with the video generator phase.
              ' We must multiply by 1 2/3 for 80MHz
              ' instead of 2 for 96MHz.
              ' approximated by 1 3/4
              ' peak error +1 or -1 instruction

              add       tx_count_raw, #15       ' 0 -> 16
              and       tx_count_raw, #%1111    ' Period is 16 bits
              mov       t1,tx_count_raw
              shr       t1, #1                  '
              add       tx_count_raw,t1         ' 1/2
              shr       t1, #1                  '
              add       tx_count_raw,t1         ' 1/4
              cmp       vscl_value,vscl_low wz
        if_z  shl       tx_count_raw,#3         ' low speed 8 times slower
        if_z  add       tx_count_raw,#20
              ' Transmitter startup: We need to synchronize with the video PLL,
              ' and transition from an undriven idle state to a driven idle state.
              ' To do this, we need to fill up the video generator register with
              ' idle states before setting DIRA and VCFG.
              '
              ' Since we own the bus at this point, we don't have to hurry.

              ' This section was relocated because the extra math involved
              ' for 80MHz operation was running causing the video generator
              ' to run out of data and transmit garbage on the bus.
              ' May not apply with pin wakeup
              ' Make sure there are no more than XX instructions between waitvids.

              mov       vscl, vscl_value                ' Back to normal video speed
              waitvid   v_palette, v_idle
              waitvid   v_palette, v_idle
              movs      vcfg, #BUS_MASK
              or        dira, #DEBUG_TX_MASK | BUS_MASK

              ' Transmit our NRZI-encoded packet.
              '
              ' This loop is optimized to do the last waitvid separately, so
              ' that we don't add any extra instructions between it and the
              ' bus release code below.

              movs      :tx_inst1, #tx_buffer
              shr       tx_count, #4            ' Bits -> words

:tx_loop      sub       tx_count, #1 wz
        if_z  jmp       #:tx_loop_last          ' Stop looping before the last word

:tx_inst1     waitvid   v_palette, 0            ' Output all words except the last one
              add       :tx_inst1, #1
              jmp       #:tx_loop

:tx_loop_last mov       :tx_inst2, :tx_inst1    ' Copy last address
              mov       :tx_inst3, :tx_inst1
    if_c      andn      outa, tx_ncmask         ' Falling edge enables RX cog

              ' The last word is special, since we need to stop driving the bus
              ' immediately after the video generator clocks out our EOP bits.
              ' We've already calculated a loop count for how long to delay
              ' between the waitvid and the end of our EOP- but we need to
              ' special-case 0 so we can stop driving immediately after waitvid.

              tjz       tx_count_raw, #:tx_inst3

:tx_inst2     waitvid   v_palette, 0            ' Output last word
              djnz      tx_count_raw, #$        ' Any tx_count_raw >= 1
              andn      dira, #DEBUG_TX_MASK | BUS_MASK
              jmp       #:tx_release_done

:tx_inst3     waitvid   v_palette, 0            ' tx_count_raw == 0
              andn      dira, #DEBUG_TX_MASK | BUS_MASK


:tx_release_done

              ' As soon as we're done transmitting, switch to a 'turbo' vscl value,
              ' so that after the current video word expires we switch to a faster
              ' clock. This will help us synchronize to the video generator faster
              ' when sending ACKs, decreasing the maximum ACK latency.

              mov       vscl, vscl_turbo

              '======================================
              ' Receiver Controller
              '======================================

        if_nc jmp       #:rx_done                       ' Receiver disabled
              rcr       l_cmd, #1 wc                    ' C = bit1 = ACK Enable

              ' First, wait for an EOP signal. This wait needs to have a timeout,
              ' in case we never receive a packet. It also needs to have low latency,
              ' since we use this timing both to send ACK packets and to calculate
              ' the length of the received packet.

              mov       t1, eopwait_iters
:wait_eop     test      c_bus_mask, ina wz
        if_nz djnz      t1, #:wait_eop
              mov       t3, cnt                         ' EOP timestamp

              mov       t1,#20
              cmp       vscl_value,vscl_low wz
        if_z  djnz      t1,#$         ' low speed delay

              ' The USB spec gives us a fairly narrow window in which to transmit the ACK.
              ' So, to get predictable latency while also keeping code size down, we
              ' use the video generator in a somewhat odd way. Prior to this code,
              ' we set the video generator to run very quickly, so the variation in
              ' waitvid duration is fairly small. After re-synchronizing to the video
              ' generator, we slow it back down and emit a pre-constructed ACK packet.

        if_c  waitvid   v_palette, v_idle                ' Sync to vid gen. at turbo speed
        if_c  mov       vscl, vscl_value                 ' Back to normal speed at the next waitvid
        if_c  waitvid   v_palette, v_ack1                ' Start ACK after a couple idle cycles
        if_c  or        dira, #DEBUG_ACK_MASK | BUS_MASK ' Take bus ownership during the idle
        if_c  waitvid   v_palette, v_ack2                ' Second half of the ACK + EOP
        if_c  waitvid   v_palette, v_idle                ' Wait for the ack to completely finish
        if_c  andn      dira, #DEBUG_ACK_MASK | BUS_MASK ' Release bus

              ' Time-critical work is over. Save the EOP timestamp. The Spin code
              ' will use this value to calculate actual packet length.

              wrlong    t3, txp_result

              ' Now we're just waiting for the RX cog to finish. Poll RX_DONE.
              ' This shouldn't take long, since we already waited for the EOP.
              ' The RX cogs just need to detect the EOP and finish the word
              ' they're on. We'll be conservative and say they need 64 bit
              ' periods (2 full iterations) to do this job. That's 512
              ' clock cycles, or 32 hub windows.

              mov       t1, #1
              shl       t1,#12
              'mov       t1,#32
:rx_wait      rdbyte    t3, txp_rxdone wz
        if_nz djnz      t1, #:rx_wait

              ' If the timeout expired and our RX cogs still aren't done,
              ' we'll manually wake them up by driving a SE1 onto the bus
              ' for a few cycles.

        if_nz or        outa, #BUS_MASK
        if_nz or        dira, #BUS_MASK
              nop
              nop
        if_nz andn      dira, #BUS_MASK
        if_nz andn      outa, #BUS_MASK

              ' Initialize the decoder, load the first long into the shift register.
              ' Add the first zero to the sync byte since the receiver misses it.

              mov       dec_rxbuffer, txp_rxbuffer
              mov       dec_nrzi_cnt, #31        ' 31 bits for first long
              mov       dec_1cnt, #0
              rdlong    dec_nrzi, dec_rxbuffer
              shl       dec_nrzi,#1              ' add the implied zero
              add       dec_rxbuffer, #4

:rx_done
              '======================================
              ' End of Receiver Controller
              '======================================

              call      #enc_reset              ' Reset the encoder too
              movs      vcfg, #0                ' Disconnect vid gen. from outputs

txrx_ret      ret


              '======================================================
              ' NRZI Encoding and Bit Stuffing
              '======================================================

              ' Encode (NRZI, bit stuffing, and store) up to 32 bits.
              '
              ' The data to be encoded comes from codec_buf, and codec_cnt
              ' specifies how many bits we shift out from the LSB side.
              '
              ' For both space and time efficiency, this routine is also
              ' responsible for updating a running CRC-16. This is only
              ' used for data packets- at all other times it's quietly
              ' ignored.
encode
              rcr       codec_buf, #1 wc

              ' Update the CRC16.
              '
              ' This is equivalent to:
              '
              '   condition = (input_bit ^ (enc_crc16 & 1))
              '   enc_crc16 >>= 1
              '   if condition:
              '     enc_crc16 ^= crc16_poly

              test      enc_crc16, #1 wz
              shr       enc_crc16, #1
    if_z_eq_c xor       enc_crc16, crc16_poly

              ' NRZI-encode one bit.
              '
              ' For every incoming bit, we generate two outgoing bits;
              ' one for D- and one for D+. We can do all of this in three
              ' instructions with SAR and XOR. For example:
              '
              '   Original value of tx_reg:        10 10 10 10
              '   After SAR by 2 bits:          11 10 10 10 10
              '     To invert D-/D+, flip MSB:  01 10 10 10 10
              '    (or)
              '     Avoid inverting by flipping
              '     the next highest bit:       10 10 10 10 10
              '
              ' These two operations correspond
              ' to NRZI encoding 0 and 1, respectively.

              sar       enc_nrzi, #2
        if_nc xor       enc_nrzi, c_80000000     ' NRZI 0
        if_c  xor       enc_nrzi, c_40000000     ' NRZI 1


              ' Bit stuffing: After every six consecutive 1 bits, insert a 0.
              ' If we detect that bit stuffing is necessary, we do the branch
              ' after storing the original bit below, then we come back here to
              ' store the stuffed bit.

        if_nc mov       enc_1cnt, #6 wz
        if_c  sub       enc_1cnt, #1 wz
enc_bitstuff_ret

              ' Every time we fill up enc_nrzi, append it to tx_buffer.
              ' We use another shift register as a modulo-32 counter.

              ror       enc_nrzi_cnt, #1 wc
              add       tx_count, #1
encode_ptr
        if_c  mov       0, enc_nrzi
        if_c  add       encode_ptr, c_dest_1

              ' Insert the stuffed bit if necessary

        if_z  jmp       #enc_bitstuff

              djnz      codec_cnt, #encode
encode_ret    ret

              ' Handle the relatively uncommon case of inserting a zero bit,
              ' for bit stuffing. This duplicates some of the code from above
              ' for NRZI-encoding the extra bit. This bit is *not* included
              ' in the CRC16.

enc_bitstuff  sar       enc_nrzi, #2
              xor       enc_nrzi, c_80000000
              mov       enc_1cnt, #6 wz
              jmp       #enc_bitstuff_ret       ' Count and store this bit


              '======================================================
              ' Encoder / Transmitter Reset
              '======================================================

              ' (Re)initialize the encoder and transmitter registers.
              ' The transmit buffer will now be empty.

enc_reset     mov       enc_nrzi, v_idle
              mov       enc_nrzi_cnt, enc_ncnt_init
              mov       enc_1cnt, #0
              mov       tx_count, #0
              movd      encode_ptr, #tx_buffer
enc_reset_ret ret


              '======================================================
              ' Low-level Encoder
              '======================================================

              ' The main 'encode' function above is the normal case.
              ' But we need to be able to encode special bus states too,
              ' so these functions are slower but more flexible encoding
              ' entry points.
              '

              ' Check whether we need to store the contents of enc_nrzi
              ' after encoding another bit-period worth of data from it.
              ' This is a modified version of the tail end of 'encode' above.

encode_store
              mov       :ptr, encode_ptr
              ror       enc_nrzi_cnt, #1 wc
              add       tx_count, #1
:ptr    if_c  mov       0, enc_nrzi
        if_c  add       encode_ptr, c_dest_1
encode_store_ret ret

              ' Raw NRZI zeroes and ones, with no bit stuffing

encode_raw0
              sar       enc_nrzi, #2
              xor       enc_nrzi, c_80000000
              mov       enc_1cnt, #0
              call      #encode_store
encode_raw0_ret ret

encode_raw1
              sar       enc_nrzi, #2
              xor       enc_nrzi, c_40000000
              call      #encode_store
encode_raw1_ret ret

              ' One cycle of single-ended zero.

encode_se0
              shr       enc_nrzi, #2
              call      #encode_store
encode_se0_ret ret

              ' One cycle of idle bus (J state).

encode_idle
              shr       enc_nrzi, #2
              xor       enc_nrzi, c_80000000
              call      #encode_store
encode_idle_ret ret

              ' Append a raw SYNC field
encode_sync
              mov       t1, #7
:loop         call      #encode_raw0
              djnz      t1, #:loop
              call      #encode_raw1
encode_sync_ret ret

              ' Append a raw EOP.
              '
              ' Note that this makes sure we have at least one idle
              ' bit after the SE0s, but we'll probably have more due
              ' to the padding and bus-release latency in the transmitter.
encode_eop
              call      #encode_se0
              call      #encode_se0
              call      #encode_idle
encode_eop_ret ret


              '======================================================
              ' NRZI Decoder / Bit un-stuffer
              '======================================================

              ' Decode (retrieve, NRZI, bit un-stuff) up to 32 bits.
              '
              ' The NRZI decoding is now done in the rx cog.
              ' We still need to remove stuffed bits and calculate CRC-16.
              '
              ' As with encoding, we also run a CRC-16 here, since it's
              ' a convenient place to do so.
              '
              ' For every raw bit we consume, subtract 1 from t1.
              ' This is used as part of the byte/bit limiting for rx_data_ptr.

decode
              sub       t1, #1

              ' Variables redefined since previous versions:
              ' dec_nrzi_cnt   = number of bits remaining in dec_nrzi
              ' dec_nrzi       = shift register

              rcr       dec_nrzi, #1 wc        ' shift new bit to c
              sub       dec_nrzi_cnt, #1 wz    ' count bits remaining
        if_z  rdlong    dec_nrzi, dec_rxbuffer ' reload if necessary
        if_z  add       dec_rxbuffer, #4
        if_z  mov       dec_nrzi_cnt, #30

              cmp       dec_1cnt, #6 wz         ' Skip stuffed bits
        if_z  mov       dec_1cnt, #0
        if_z  jmp       #decode

              rcr       codec_buf, #1            ' add new data at bit 31
              test      codec_buf, c_80000000 wz ' Move decoded bit to Z


    if_nz     add       dec_1cnt, #1            ' Count consecutive '1' bits
    if_z      mov       dec_1cnt, #0

              ' Update our CRC-16. This performs the same function as the logic
              ' in the encoder above, but it's optimized for our flag usage.

              shr       dec_crc16, #1 wc          ' Shift out CRC LSB into C
    if_z_eq_c xor       dec_crc16, crc16_poly

              djnz      codec_cnt, #decode
decode_ret    ret


              '======================================================
              ' Data
              '======================================================

' Parameters that are set up by Spin code prior to cognew()

sof_deadline  long      0
txp_portc     long      0
txp_result    long      0
txp_rxdone    long      0
txp_rx1_time  long      0
'txp_rx2_time  long      0
txp_rxbuffer  long      0

' Constants

c_zero        long      0
c_40000000    long      $40000000
c_80000000    long      $80000000
c_00010000    long      $00010000
c_80008000    long      $80008000
c_dest_1      long      1 << 9
c_condition   long      %000000_0000_1111_000000000_000000000
c_bus_mask    long      BUS_MASK

reset_period  long      80_000 * 10

frqa_value    long      $13333333                       ' 6MHz
ctra_value    long      (%00001 << 26) | (%111 << 23)   ' PLL x16  96MHz
vcfg_value    long      (%011 << 28)                    ' Unpack 2-bit -> 8-bit
vscl_value    long      (8 << 12) | (8 * 16)            ' Normal 8 clocks per pixel, 16 bits/frame
vscl_turbo    long      (1 << 12) | (1 * 16)            ' 1 clock per pixel, 2 bit times/frame
v_palette     long      (BUS_MASK << 24) | (STATE_J << 16) | (STATE_K) << 8

vscl_low      long      ((8*8) << 12) | ((8*8) * 16)
vscl_full     long      (8 << 12) | (8 * 16)
v_palette_low  long      (BUS_MASK << 24) | (STATE_J << 8) | (STATE_K) << 16 ' Swap D+, D-
v_palette_full long      (BUS_MASK << 24) | (STATE_J << 16) | (STATE_K) << 8

v_idle        long      %%2222_2222_2222_2222
tx_ncmask     long      |<USBNC
' Pre-encoded ACK sequence:
'
'    SYNC     ACK      EOP
'    00000001 01001011
'    KJKJKJKK JJKJJKKK 00JJ
'
'    waitvid: %%2200_1112_2122_1121_2121
'
' This encoded sequence requires 40 bits.
' We encode this in two logs, but we don't start
' it immediately. Two reasons:
'
'   - We enable the output drivers immediately
'     after sync'ing to the video generator, So
'     there is about a 1/2 bit delay between
'     starting to send this buffer and when we
'     actually take control over the bus.
'
'   - We need to ensure a minimum inter-packet
'     delay between EOP and ACK.
'
'
'     (Currently we wait 4 bit periods.
'      This may need to be tweaked)

v_ack1        long      %%2122112121212222
v_ack2        long      %%2222222222001112

enc_ncnt_init long      $8000_8000                      ' Shift reg as mod-16 counter

crc16_poly    long      $a001                           ' USB CRC-16 polynomial
crc16_mask    long      $ffff                           ' Init/final mask

' How long will we wait for an EOP, during receive?
'
' This is a two-instruction (test / djnz) loop which takes 8 cycles. So each
' iteration is one bit period, and this is really a count of the maximum number
' of bit periods that could exist between the end of the transmitted packet
' and the EOP on the received packet. So it must account for the max size of the
' receive buffer, plus an estimate of the max inter-packet delay.

eopwait_iters long      ((RX_BUFFER_WORDS * 32) + 128 + 2000)

' We try to send SOFs every millisecond, but other traffic can preempt them.
' Since we're not even trying to support very timing-sensitive devices, we
' also send a fake (non-incrementing) frame number.

sof_frame     long      %00010_00000000000_1010_0101    ' SOF PID, Frame 0, valid CRC5
sof_period    long      80_000                          ' 80 MHz, 1ms

' Encoder only
enc_nrzi      res       1                               ' Encoded NRZI shift register
enc_1cnt      res       1
enc_nrzi_cnt  res       1                               ' Cyclic bit counter
enc_crc16     res       1

' Decoder only
dec_nrzi      res       1                               ' Encoded NRZI shift register
dec_nrzi_cnt  res       1                               ' Bit counter
dec_1cnt      res       1
dec_rxbuffer  res       1
dec_crc16     res       1

tx_count_raw  res       1
t3            res       1

led_tmp       res 1 ' FIXME
tx_buffer     res       TX_BUFFER_WORDS

              fit


'==============================================================================
' Receiver Cog 1
'==============================================================================

' This receiver cog stores 30 bits of data in each long.
' Also performs NRZI decoding.
'
' The first bit is missed compared to previous receiver code.
' Sync shows as 0x40, we compensate for this in the decoder.
'
' Parameters:
'      par (rx1_time)  set to zero by this cog on startup
'                      set nonzero by controller cog with trigger time
'                      immediately reset to zero for one-shot action

'      rx1p_done   =   set nonzero by controller cog when before activating receivers
'                      set to zero when pseudo-eop is detected

'      rx1p_buffer = hub address for receive buffer, same to rx1 and rx2

'      rx1p_sop    = timestamp measured for SOP (Start of Packet)

'      rx1_zero    = literal zero for use from D operand


' We store the entire packet in cog ram since there is no time
' for hub access while receiving.
' This shouldn't be a problem since USB 1.1 specifies a maximum
' payload size of 1023 bytes.

' We have only one RX cog right now, but the RX1/RX2 notation remains in
' case we want to return to interleaved receivers. This could allow
' un-stuffing and CRC-16 to run on another cog while reception is
' in progress.

              org
rx_cog_1
              wrlong    rx1_zero, par           ' Notify Start() that we're running.

:restart
              ' Initial conditions for counters
              mov frqb , #0            ' PHSB is set later
              mov ctrb, ctr_data_fs    ' accumulate when sampling pulse and data

              ' Initialize CTRA. We must keep the USBNC pin low now,
              ' or we will miss our wakeup signal from the TX cog.
              mov frqa , #0
              mov phsa, phs_usb
              mov ctra, ctr_usb        ' duty output on USBNC pin
              mov dira, rx1_dira


              ' FIXME We count by longs, not bytes.
              ' The math works out anyway.
              mov       rx1_iters, #RX_BUFFER_WORDS

              ' The sampling loop is pipelined so the
              ' first "received raw data" is actually the
              ' initial conditions set here. We define this
              ' to be (1<<29) to feed the NRZI decoder the
              ' initial one that our sampling loop missed.

              ' The NRZI decoder outputs undefined data for
              ' the first long because oldraw is not initialized.
              ' That's ok, we don't even copy it to hub ram.

              ' The first raw data is (newphs-oldphs).
              ' We set oldphs to zero because it's convenient.

              mov newphs,d_first
              mov phsb,newphs      ' load the counter with our known value
              mov oldphs,#0
              mov dptr, #databuf

              ' A rising edge from the TX cog is our wakeup signal.
              waitpeq rx1_nc,rx1_nc

              ' Check what speed we need to receive.
              rdbyte  t2,rx1p_portc
              test    t2,rx1_dplus wz
      if_z    jmp     #:start_ls


:rx1_start_fs
              waitpne rx1_nc,rx1_nc ' trigger on falling edge

              ' Now synchronize to the beginning of the next packet.
              ' We sample only D- in the receiver. If we time out,
              ' the controller cog will artificially send a SE1
              ' to bring us out of sleep. (We'd rather not send a SE0,
              ' since we may inadvertently reset the device.)

              ' The receiver must start in the narrow window
              ' between the SE0 sent at end of packet and sync byte
              ' at the beginning of the received packet.

              ' The TX cog triggers us a little early
              ' so we wait for SE0 before activating the receiver.
              waitpeq   rx1_zero, rx1_dmask   ' wait for EOP

              ' We should have time to do this here since USB spec
              ' require minimum of 2 bit times before next packet.
              mov frqb , #1 '0    ' get timer ready to receive data

              waitpne   rx1_zero, rx1_dminus    ' sync to rising edge (K)
        mov frqa, frq_usb                       ' turn on sampling clock
                        mov rx1_cnt, cnt        ' save SOP time
        shl frqb,#1 '1
                        sub rx1_cnt, #4         ' adjust SOP timestamp
:sample_loop
        shl frqb,#1 '2
' quantum break
        shl frqb,#1 '3
                        mov newraw, newphs      ' set up to subtract
        shl frqb,#1 '4
                        sub newraw, oldphs wz   ' extract new data, detect pEOP
        shl frqb,#1 '5
' quantum break
        shl frqb,#1 '6
                        if_z jmp #:rx_done      ' exit quickly on pEOP
        shl frqb,#1 '7
                        movd :wr, dptr
        shl frqb,#1 '8
' quantum break
        shl frqb,#1 '9
                        add dptr, #1
        shl frqb,#1 '10
                        mov datalong, newraw    ' start of nrzi decoder
        shl frqb,#1 '11
' quantum break
        shl frqb,#1 '12
                        shr oldraw, #29         ' get last bit of old data
        shl frqb,#1 '13
                        and oldraw, #1          ' destructively
        shl frqb,#1 '14
' quantum break
        shl frqb,#1 '15
                        shl datalong, #1        ' make room for last bit
        shl frqb,#1 '16
                        add datalong, oldraw    ' add the last bit on
        shl frqb,#1 '17
' quantum break
        shl frqb,#1 '18
                        xor datalong, newraw    ' find transitions
        shl frqb,#1 '19
                        xor datalong,data_mask  ' invert
        shl frqb,#1 '20
' quantum break
        shl frqb,#1 '21
                        nop
        shl frqb,#1 '22
                        nop
        shl frqb,#1 '23
' quantum break
        shl frqb,#1 '24
                        nop
        shl frqb,#1 '25
:wr                     mov 0, datalong         ' store data
        shl frqb,#1 '26
' quantum break
        shl frqb,#1 '27
                        mov oldraw,newraw
        shl frqb,#1 '28
                        mov oldphs,newphs    '
        shl frqb,#1 '29
' quantum break
        mov frqb,#1 '0
                        mov newphs,phsb ' read data, bit 0 not yet included
        shl frqb,#1 '1
                        djnz rx1_iters,#:sample_loop '
      ' shl frqb,#1 '2  after jump

              ' We don't have time to read and clear phsb without
              ' loosing a bit. Thankfully, addition is reversible
              ' so all we need to do is read.

:rx_done
              mov frqa, #0      ' stop sample clock

              movd :zwr, dptr   ' set D to add terminating zero to buffer
              mov frqb, #0      ' stop accum, also a delay between movd and mov
:zwr          mov 0,#0          ' write zero at end
' databuf[0] is written with dummy data
' databuf[1] contains first real data, [31:30] undefined, [29:0] NRZI decoded
' databuf[n] is written with 0 on pEOP

              jmp #:upload

:start_ls

                 movd      :lswr, #databuf      ' reset data pointer
                 mov  bitpos,rx1_dplus          ' initial state for waitpxx
                 or   bitpos,rx1_nc


                 waitpne rx1_nc,rx1_nc ' trigger on falling edge`



                 waitpeq   rx1_zero, rx1_dmask  ' wait for EOP

                 mov frqa , #1       ' watchdog timer on
                 mov phsa, phs_wdt
                 mov ctra, ctr_wdt   ' NCO output on NC pin

                 waitpne  rx1_zero,rx1_dplus    ' wait for SOP (K)

                 ' alternate SOP detector with timeout
                 ' mov       loopcnt,#1 ' eopwait_iters
                 ' shl       loopcnt,#20
' :wait_sop        test      mask, ina wz         ' Wait for a one on
'        if_z     djnz      loopcnt, #:wait_sop  ' D+

                 mov       rx1_cnt, cnt         ' save SOP
                 mov       oldphs,rx1_cnt       ' also use it as first edge

                 ' We use the Z flag and C flag parity calculation to
                 ' detect EOP and timeout in the same test.
                 '
                 ' If we receive a SE1 at the exact same time
                 ' as the timer runs out, we will miss it. (Unlikely)
                 '
                 '  NC       USB      Z      C
                 ' ---------------------------------
                 '   1       SE0      0      1    Exit due to SE0
                 '   1        D+      0      0    Normal receving case
                 '   1        D-      0      0    Normal receving case
                 '   1       SE1      0      1    Exit due to SE1
                 '   0       SE0      1      0    Exit due to timeout and SE0
                 '   0        D+      0      1    Exit due to timeout
                 '   0        D-      0      1    Exit due to timeout
                 '   0       SE1      0      0    Fail to exit !!!

                 ' We need waitpxx to continue on SE0
                 ' in order to detect SE0 after J.
:ls_loop
                 waitpne   bitpos,rx1_wmask     ' 1
                 mov       newphs,cnt           ' 2
                 xor       bitpos,rx1_dmask     ' 3 swap polarity for next edge
                 mov       newraw,newphs        ' 4
                 test      rx1_wmask,ina  wc,wz ' 5
                 sub       newraw,oldphs        ' 6
:lswr            mov       0, newraw            ' 7 store data
  if_c_or_z      jmp       #:ls_eop             ' 8
                 add       :lswr,d_by_one       ' 9
                 mov       oldphs,newphs        '10
                 djnz      rx1_iters,#:ls_loop  '11

:ls_eop
                 ' If we needed the EOP timestamp we could get it from newphs.

                 ' Retrieve the current dptr from our write instruction
                 mov     dptr,:lswr             '
                 shr     dptr,#9                '
                 and     dptr,#$1FF             '

                 mov frqa, #0                   ' Stop counter
                 mov phsa, #0                   ' Set the counter output pin to low
                 mov ctra, ctr_usb              ' ctr_hub, for upload (same as ctr_usb)


                 ' The output of the low speed receiver needs some post-processing.
                 ' In the future we could do unstuffing here.

                 ' oldphs = input  clocks between edges
                 ' newphs = used to count how many bits to output for each edge
                 ' newraw = output data buffer
                 ' ocnt   = output bits remaining in long

                 mov loopcnt,dptr                 ' calculate how many
                 sub loopcnt,#databuf             ' longs we received
                 add loopcnt,#2                   ' index adjustment   Don't fully understand yet

                 movs      :lsread,#(databuf+0)   ' reset read address
                 mov       dptr,#(databuf+1)      ' reset write address
                 cmp       rx1_zero,#$1FF   wc    ' set carry
                 jmp       #:lsinit               ' rest of init in loop


:lsread          mov       newphs, databuf+1      ' read new data
                 add       :lsread, #1            ' S++
                 sub       loopcnt,#1   wz        ' limit input length
           if_z  jmp       #:lsrx_done


              ' 53 1/3 clocks per bit nominal at 80 MHz
              ' Using 53 shifts the thresholds a little
              ' off center, but we should still be able
              ' to tolerate 5% clock error with 7 consecutive ones.
              ' USB spec is 1.5% for low speed devices.

              sub       newphs,#26   wc
     '   if_c  jmp       #:lsread             ' optional noise/error catch

              cmp       newphs,#450  wc       ' Limit the number of bits in each run
        if_nc jmp       #:lsrx_done           ' to avoid overflow. This would be a
                                              ' bit stuffing error or other fault.

:lswloop      sub       newphs,#53   wc        ' C=1 for last bit of the loop.
        if_nc or        newraw, bitpos         ' That means write a zero.
              ' Future: skip the next 2 lines for stuffed bits
              shl       bitpos,#1
              sub       lsrx_ocnt, #1 wz       ' count bits remaining
        if_nz jmp       #:samelong
:lswrite      mov       0, newraw
              add       dptr, #1               ' increment address
:lsinit       movd      :lswrite, dptr         '
              mov       lsrx_ocnt, #30         '
              mov       bitpos, #1             ' reset output shift reg
              mov       newraw,#0              '
:samelong
        if_nc jmp       #:lswloop
              jmp       #:lsread

:lsrx_done    movd      :lswrite2, dptr        '
              nop
:lswrite2     mov       0, newraw



:upload       ' Data received, now copy the data to hub ram.
              '
              mov loopcnt,dptr          ' calculate how many
              sub loopcnt,#databuf      ' longs we received
              ' loopcnt is number of longs including terminating 0

              movd :hublp,#databuf      ' set cog start address
              add :hublp, d_by_one      ' skip dummy long at start
              mov ctrb, ctr_clock       ' accumulate with sampling pulse only

              ' save the SOP timestamp  and synchronize with hub
              wrlong    rx1_cnt, rx1p_sop
              mov phsa, phs_hub         ' initial offset for
              mov phsb, rx1p_buffer     ' set hub start address

              ' Signal that we are done even though
              ' we have yet to copy the data.
              ' The decode cog won't catch us.
              wrbyte    rx1_zero, rx1p_done
              mov frqb, #4              ' increment by longs
              mov frqa, frq_hub         ' enable clock to ctrb
              ' Copy the data longs.
:hublp        wrlong 0, phsb            ' counter increments hub address
              add :hublp, d_by_one      ' increment cog mem address
              djnz loopcnt,#:hublp

              mov frqa, #0 ' stop sample clock
              mov frqb, #0 ' stop accumulator

        ' Debug code for quickstart LEDs
'       mov cnttmp,databuf+1
   '    mov cnttmp,t2
'      mov t2, rx1p_buffer
'      add t2,#4
'      rdlong cnttmp,t2
   '   mov cnttmp,phsb
'      shr cnttmp,#7
'       and cnttmp,#$ff
'       shl cnttmp,#16
'       mov outa,cnttmp


              jmp       #:restart
rx1_wmask     long      (1<<DPLUS) + (1<<DMINUS) + (1<<USBNC)
rx1_dmask     long      (1<<DPLUS) + (1<<DMINUS)
rx1_dplus     long      |< DPLUS
rx1_dminus    long      |< DMINUS
rx1_zero      long      0
rx1_nc        long      |< USBNC
rx1_dira      long      (1<<USBNC) + ($ff<<16) '+ (1<<7)

ctr_wdt       long      (%00100_000 << 23) + (USBNC) 'nco out
phs_wdt       long      -(53*130)    ' 130 bits is max LS packet + gap

ctr_usb       long      (%00110_000 << 23) + (USBNC) 'duty out
' Adjusting the starting phase may require the
' sampling loop to be modified.
' USB start phase was adjusted using scope to place
' the sampling pulses in the center of the USB bits.
phs_usb       long      $2666_6666*5  ' starting phase
frq_usb       long      $2666_6666    ' 12 MHz pulses for USB


phs_hub       long      $8000_0000    ' Not sure if this is critical
frq_hub       long      $1000_0000    ' 1/16 clock rate
' ctr_data  is used to sample USB data
' ctr_clock is used to increment hub address
ctr_data_fs   long      (%11000_000 << 23) + (USBNC) + (DMINUS<<9)
ctr_clock     long      (%11010_000 << 23) + (USBNC)

d_by_one      long      (1<<9)
data_mask     long      $3FFF_FFFF  ' bits 29-0
d_first       long      (1<<29)     ' initial condition for NRZI decoder
' Parameters that are set up by Spin code prior to cognew()
rx1p_done     long      0
rx1p_buffer   long      0
rx1p_sop      long      0
rx1p_portc    long      0            ' we check this for speed data

'rx1_buffer    res       1           ' we store this in phsb now
rx1_cnt       res       1            ' stores SOP timestamp
rx1_iters     res       1
t2            res       1
loopcnt       res       1
newphs        res       1
oldphs        res       1
'lsrx_icnt     res       1
lsrx_ocnt     res       1
dptr          res       1
newraw        res       1
oldraw        res       1
datalong      res       1
cnttmp        res       1
'lsrx_cnt      res       1
'iloop         res       1
'oloop         res       1
'sample0       res       1
'sample1       res       1
'sample2       res       1
bitpos        res       1
'lrx_shift     res       1
databuf       res     240

              fit


{{  ' RX2 not used
'==============================================================================
' Receiver Cog 2
'==============================================================================
' This receiver cog is not used right now.

' This receiver cog stores the second 16-bit half of every 32-bit word.
'
' Since this is the last receiver cog to run, we update the RX_LONGS counter
' and detect when we're "done". We don't actually detect EOP conditions (since
' we are only sampling D-) but we decide to finish receiving when an entire word
' (16 bit perods) of the bus looks idle. Due to bit stuffing, this condition never
' occurs while a packet is in progress.
'
' When we detect this pseudo-EOP condition, we'll set the "done" bit (bit 31) in
' RX_LONGS. This tells both the RX1 cog and the controller that we're finished.

              org
rx_cog_2
              wrlong    rx2_zero, par           ' Notify Start() that we're running.
:restart
              mov       rx2_buffer, rx2p_buffer
              mov       rx2_iters, #RX_BUFFER_WORDS

:wait         rdlong    t4, par wz              ' Read trigger timestamp
        if_z  jmp       #:wait
              wrlong    rx2_zero, par           ' One-shot, zero it.

              waitcnt   t4, #0                  ' Wait for trigger time
              waitpne   rx2_zero, rx2_pin       ' Sync to SOP

              ' Save the SOP timestamp. We need this for our own calculations,
              ' plus our Spin code will use this to calculate received packet length.

              mov       rx2_cnt, cnt
              wrlong    rx2_cnt, rx2p_sop

              ' Calculate a sample time that's 180 degrees out of phase
              ' from the RX1 cog's sampling burst. We want to sample every
              ' 8 clock cycles with no gaps.

              add       rx2_cnt, #(16*8 - 5)
              jmp       #:first_sample

:sample_loop

              ' Justify the received word. Also detect our pseudo-EOP condition,
              ' when we've been idle (0) for 16 bits.
              shr       t4, #16 wz

              add       rx2_buffer, #2
              wrword    t4, rx2_buffer
              add       rx2_buffer, #2

              ' Update RX_DONE only after writing to the buffer.
              ' We're done if rx2_iters runs out, or if we're idle.

        if_nz sub       rx2_iters, #1 wz
        if_z  wrbyte    rx2_zero, rx2p_done
        if_z  jmp       #:restart

:first_sample waitcnt   rx2_cnt, #(32*8)

              test      rx2_pin, ina wc         '  0
              rcr       t4, #1
              test      rx2_pin, ina wc         '  1
              rcr       t4, #1
              test      rx2_pin, ina wc         '  2
              rcr       t4, #1
              test      rx2_pin, ina wc         '  3
              rcr       t4, #1
              test      rx2_pin, ina wc         '  4
              rcr       t4, #1
              test      rx2_pin, ina wc         '  5
              rcr       t4, #1
              test      rx2_pin, ina wc         '  6
              rcr       t4, #1
              test      rx2_pin, ina wc         '  7
              rcr       t4, #1
              test      rx2_pin, ina wc         '  8
              rcr       t4, #1
              test      rx2_pin, ina wc         '  9
              rcr       t4, #1
              test      rx2_pin, ina wc         ' 10
              rcr       t4, #1
              test      rx2_pin, ina wc         ' 11
              rcr       t4, #1
              test      rx2_pin, ina wc         ' 12
              rcr       t4, #1
              test      rx2_pin, ina wc         ' 13
              rcr       t4, #1
              test      rx2_pin, ina wc         ' 14
              rcr       t4, #1
              test      rx2_pin, ina wc         ' 15
              rcr       t4, #1

              jmp       #:sample_loop

rx2_pin       long      |< DMINUS
rx2_zero      long      0

' Parameters that are set up by Spin code prior to cognew()
rx2p_done     long      0
rx2p_buffer   long      0
rx2p_sop      long      0

rx2_done_p    res       1
rx2_time_p    res       1
rx2_buffer    res       1
rx2_iters     res       1
rx2_cnt       res       1
t4            res       1

              fit
}}          ' RX2 not used

heap_end    ' Begin recyclable memory heap

DAT
{{

TERMS OF USE: MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,
modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software
is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

}}
