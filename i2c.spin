'' ******************************************************************************
'' * I2C SPIN Object                                                            *
'' * James Burrows May 2006                                                     *
'' * Version 1.3                                                                *
'' ******************************************************************************
''
'' Synchronous Serial adapted from the ShiftIO object by Jon Williams @ Parallax
''
'' for reference look at: www.semiconductors.philips.com/ acrobat/literature/9398/39340011.pdf
''
'' this is adapted from the Parallax Javalin i2c library, and the Jon's BS2 bit bang routine.
''
'' this object provides the PUBLIC functions:
''  -> Init  - sets up the address and inits sub-objects such
''  -> Stop - stop the object
''  -> Start - start the object
''  -> getError - gets the error flag
''  -> clearError - clear the error
''  -> isStarted - returns true/false for the object started state
''  -> testBus - allows the pullups to raise the bus to pinHIGH's.  Sets errorlevel
''  -> devicePresent - sents and address byte and looks for the device to ACK
''  -> readLocation - high level READ functions using the four low level functions
''  -> writeLocation - high level WRITE functions using the four low level functions
''  -> i2cStart - performs a bus start
''  -> i2cStop - performs a bus stop
''  -> i2cRead - performs a read
''  -> i2cWrite - performs a write
''
'' this object provides the PRIVATE functions:
''  -> None
''
'' this object uses the following sub OBJECTS:
''  -> None
''
'' Revision History:
''  -> V1 - Release
''      -> V1.1 - Documentation update, slight code tidy-up
''      -> V1.2 - More Documentation update, slight code tidy-up
''                i2cWrite changes - see below.
''      -> V1.3 - additional parameter added to the init to allow for SCL lines that
''                don't have resistor pull-ups. This allows for the Propeller Dev board SCL and SDA pins
''                28/29 if you use them.  Note that if the i2cObject code is set to drive the
''                i2c SCL line - this will not work if more than one cog attempts to run it (obviously)
''                not at the same time!!)  (thanks to Michael Green on the forums)
''                Normally set to FALSE if you have pull-ups, and TRUE if you dont.
''
''                ++ i2cBits parameter removed from the i2cRead function as it was not used!!
''
''
'' i2c Address's:
''  -> Specify the full 8 bit address when using the high level object, they will add the R/W 1/0 bit in the LSB
''  -> Low level objects - specify it as you want to come out!
''
'' ACK/NAK bit return:
''  -> Implemented to allow the calling application to see the last 32 ack/naks returned in a multi-write operation.
''     For example, if a call makes three (3) writes and produces no errors (acks) you will get a 0 returned.
''     If the middle write is NAK'd by the device, you'll get (in binary) %010 back.  So if you get a >0 back
''     as a return a NAK as occurred somewhere.  Look at it in binary to see which!
''
'' Bus Error handing:
''  -> Partially implemented.  When its completed each method can set error flags appropriate to the condition
''  -> External routines can use getError and clear error to access the error states.  Could be expanded to include
''  -> bus arbiration errors in the future.
''
'' i2cWrite - changed (v1.2)  :  i2cwrite now always outputs the top 8 bits of a the LONG data, i.e.
''      %xxxxxxxx_00000000_00000000_00000000
''     The i2cbits parameter controlls an shift, so if you pass i2cWrite (10, 8) it will shift the low byte left 24 bits
''      %00000000_00000000_00000000_00001010  is shifted to become...
''      %00001010_00000000_00000000_00000000  then the top 8 bits are output!
''

CON
  ' i2c bus contants
  _i2cNAK         = 1
  _i2cACK         = 0
  _pinHigh        = 1
  _pinLow         = 0
  _i2cByteAddress = 8
  _i2cWordAddress = 16

  ' arbitory error constants
  _None           = 1000
  _ObjNotInit     = 1001
  _SCLHold        = 1002
  _i2cSDAFault    = 1003
  _i2cSCLFault    = 1004
  _i2cStopFault   = 1005

  ' device constants
  EEPROM          = $A0

VAR
  word  i2cSDA, i2cSCL
  long  ErrorState
  long  i2cStarted
  long  lastAckBit
  byte  driveLines

'' ******************************************************************************
'' *  These are the high level routines                                         *
'' ******************************************************************************

PUB Start : okay
  ' start the object
  if i2cStarted == false
    i2cStarted := true
    ' init both i2c lines as inputs.
    dira[i2cSDA] ~
    dira[i2cSCL] ~
    ' init the last ack bit
    lastAckBit := 1 ' default to NAK
    ' init no error state
    ErrorState := _None


PUB Stop : okay
  ' stop the object and release the pins
  if i2cStarted == true
    i2cStarted := false
    ' release both i2c lines as inputs.
    dira[i2cSDA] ~
    dira[i2cSCL] ~
    ' init no error state
    ErrorState := _None


PUB getLastAckBit : ackbit
  ' return the last ack bit
  return lastAckBit


PUB init(_i2cSDA, _i2cSCL, _driveSCLLine): okay
  if lookdown(_i2cSDA : 0..31) > 0 and lookdown(_i2cSCL : 0..31) > 0
     ' init the I2C Object
     i2cSDA := _i2cSDA
     i2cSCL := _i2cSCL
     ' init the drive'n parameter for SCL lines
     driveLines := _driveSCLLine
     ' init both i2c lines as inputs.
     if driveLines == false
       dira[i2cSDA] ~
       dira[i2cSCL] ~
     else
       dira[i2cSDA] ~~
       dira[i2cSCL] ~~

     ' init no error state
     ErrorState := _None
     i2cStarted := true
  else
     ErrorState := _ObjNotInit
     i2cStarted := false

  ' return true if init was OK
  return i2cStarted


PUB getError : errorCode
  ' return the error state variable
  return(ErrorState)


PUB clearError
  ' clear the error state variable
  ErrorState := _None


PUB isStarted : i2cState
  ' return the i2cStarted flag (true/false)
  return i2cStarted


PUB testBus : errorCode
  ' put both lines to input
  ' they should both go high from the resistor pullup's
  ErrorState := _None
  dira[i2cSDA] ~
  dira[i2cSCL] ~
  if ina[i2cSDA] <> _pinHigh
    ErrorState := _i2cSDAFault
  if ina[i2cSCL] <> _pinHigh
    ErrorState := _i2cSCLFault
  return ErrorState


PUB devicePresent(deviceAddress) : ackbit
  ' send the deviceAddress and listen for the ACK
  ackbit := _i2cNAK
  if i2cStarted == true
    i2cStart
    ackbit := i2cWrite(deviceAddress | 0,8)
    i2cStop
    if ackbit == _i2cACK
      ackbit := true
    else
      ackbit := false
    return ackbit


PUB eeprom_read(deviceRegister, dataBuffer, dataSize) : ackbit
  ' do a standard i2c address, then read
  ' read a device's register
  ackbit := _i2cACK

  if i2cStarted == true
    i2cStart
    ackbit := (ackbit << 1) | i2cWrite(EEPROM | 0, 8)

    ' send a 16 bit deviceRegister
    ackbit := (ackbit << 1) | i2cWrite(deviceRegister << 16, 0)
    ackbit := (ackbit << 1) | i2cWrite(deviceRegister << 24, 0)

    i2cStart
    ackbit := (ackbit << 1) | i2cWrite(EEPROM | 1, 8)

    repeat dataSize - 1
      BYTE[dataBuffer] := i2cRead(_i2cACK)
      dataBuffer := dataBuffer + 1

    BYTE[dataBuffer] := i2cRead(_i2cNAK)

    i2cStop
  else
    ackbit := _i2cNAK
  ' set the last i2cACK bit
  lastAckBit := ackbit
  return ackbit


PUB eeprom_write(deviceRegister, dataBuffer, dataSize) : ackbit
  ' do a standard i2c address, then write
  ' return the ACK/NAK bit from the device address
  ackbit := _i2cACK

  if i2cStarted == true
    i2cStart
    ackbit := (ackbit << 1) | i2cWrite(EEPROM | 0, 8)

    ' send a 16 bit deviceRegister
    ackbit := (ackbit << 1) | i2cWrite(deviceRegister << 16, 0)
    ackbit := (ackbit << 1) | i2cWrite(deviceRegister << 24, 0)

    repeat dataSize
      ackbit := (ackbit << 1) | i2cWrite(BYTE[dataBuffer], 8)
      dataBuffer := dataBuffer + 1

    i2cStop
  else
    ackbit := _i2cNAK
  return ackbit


PUB readLocation(deviceAddress, deviceRegister, addressbits, databits) : i2cData | ackbit
  ' do a standard i2c address, then read
  ' read a device's register
  ackbit := _i2cACK

  if i2cStarted == true
    i2cStart
    ackbit := (ackbit << 1) | i2cWrite(deviceAddress | 0,8)

    ' cope with bigger than 8 bit deviceRegisters, i.e. EEPROM's use 16 bit or more
    case addressbits
      8:  ' send a 8 bit deviceRegister. (i2cWrite will shift left 24 bits)
          ackbit := (ackbit << 1) | i2cWrite(deviceRegister << 24, 0)
      16: ' send a 16 bit deviceRegister
          ackbit := (ackbit << 1) | i2cWrite(deviceRegister << 16, 0)
          ackbit := (ackbit << 1) | i2cWrite(deviceRegister << 24, 0)
      24:  ' send a 24 bit deviceRegister
          ackbit := (ackbit << 1) | i2cWrite(deviceRegister << 8,  0)
          ackbit := (ackbit << 1) | i2cWrite(deviceRegister << 16, 0)
          ackbit := (ackbit << 1) | i2cWrite(deviceRegister << 24, 0)
      32:  ' send a 32 bit deviceRegister
          ackbit := (ackbit << 1) | i2cWrite(deviceRegister << 0,  0)
          ackbit := (ackbit << 1) | i2cWrite(deviceRegister << 8,  0)
          ackbit := (ackbit << 1) | i2cWrite(deviceRegister << 16, 0)
          ackbit := (ackbit << 1) | i2cWrite(deviceRegister << 24, 0)
      other: ' any other value passed!
          ackbit := (ackbit << 1) | i2cWrite(deviceRegister << 24, 0)

    i2cStart
    ackbit := (ackbit << 1) | i2cWrite(deviceAddress | 1, 8)
    i2cData := i2cRead(_i2cNAK)
    i2cStop
  else
    ackbit := _i2cNAK
  ' set the last i2cACK bit
  lastAckBit := ackbit
  ' return the data
  return i2cData


PUB writeLocation(deviceAddress, deviceRegister, i2cDataValue, addressbits,databits) : ackbit
  ' do a standard i2c address, then write
  ' return the ACK/NAK bit from the device address
  ackbit := _i2cACK

  if i2cStarted == true
    i2cStart
    ackbit := (ackbit << 1) | i2cWrite(deviceAddress | 0,8)

    ' cope with bigger than 8 bit deviceRegisters, i.e. EEPROM's use 16 bit or more
    case addressbits
      8:  ' send a 8 bit deviceRegister
          ackbit := (ackbit << 1) | i2cWrite(deviceRegister << 24, 0)
      16: ' send a 16 bit deviceRegister
          ackbit := (ackbit << 1) | i2cWrite(deviceRegister << 16, 0)
          ackbit := (ackbit << 1) | i2cWrite(deviceRegister << 24, 0)
      24: ' send a 24 bit deviceRegister
          ackbit := (ackbit << 1) | i2cWrite(deviceRegister << 8,  0)
          ackbit := (ackbit << 1) | i2cWrite(deviceRegister << 16, 0)
          ackbit := (ackbit << 1) | i2cWrite(deviceRegister << 24, 0)
      32: ' send a 32 bit deviceRegister
          ackbit := (ackbit << 1) | i2cWrite(deviceRegister << 0,  0)
          ackbit := (ackbit << 1) | i2cWrite(deviceRegister << 8,  0)
          ackbit := (ackbit << 1) | i2cWrite(deviceRegister << 16, 0)
          ackbit := (ackbit << 1) | i2cWrite(deviceRegister << 24, 0)
      other: ' any other value passed!
          ackbit := (ackbit << 1) | i2cWrite(deviceRegister << 24, 0)

    ackbit := (ackbit << 1) | i2cWrite(i2cDataValue,8)
    i2cStop
  else
    ackbit := _i2cNAK
  return ackbit


' ******************************************************************************
' *   These are the low level routines                                         *
' ******************************************************************************

PUB i2cStop
  ' i2c stop sequence - the SDA goes LOW to HIGH while SCL is HIGH
  dira[i2cSCL] ~
  dira[i2cSDA] ~


PUB i2cStart
  ' i2c Start sequence - the SDA goes HIGH to LOW while SCL is HIGH
  if i2cStarted == true
    if driveLines == false
       ' if the SDA and SCL lines are correctly pulled up to VDD
       dira[i2cSDA] ~
       dira[i2cSCL] ~
       dira[i2cSDA] ~~
       outa[i2cSDA] := _pinLow
       repeat until ina[i2cSCL] == _pinHigh
    else
       ' if the SDA and SCL lines are left floating
       dira[i2cSDA] ~
       dira[i2cSCL] ~~
       outa[i2cSCL] := _pinHigh
       outa[i2cSDA] := _pinHigh
       outa[i2cSDA] := _pinLow


PUB i2cWrite(i2cData, i2cBits) : ackbit
  ' Write i2c data.  Data byte is output MSB first, SDA data line is valid
  ' only while the SCL line is HIGH
  ackbit := _i2cNAK

  if i2cStarted == true
    ' set the i2c lines as outputs
    dira[i2cSDA] ~~
    dira[i2cSCL] ~~

     ' init the clock line
    outa[i2cSCL] := _pinLow

    ' send the data
    i2cData <<= (32 - i2cBits)
    repeat 8
      ' set the SDA while the SCL is LOW
      outa[i2cSDA] := (i2cData <-= 1) & 1
      ' toggle SCL HIGH
      outa[i2cSCL] := _pinHigh
      ' toogle SCL LOW
      outa[i2cSCL] := _pinLow

    ' setup for ACK - pin to input
    dira[i2cSDA] ~

    ' read in the ACK
    outa[i2cSCL] := _pinHigh
    ackbit := ina[i2cSDA]
    outa[i2cSCL] := _pinLow

    ' leave the SDA pin LOW
    dira[i2cSDA] ~~
    outa[i2cSDA] := _pinLow

  ' return the ackbit
  return ackbit


PUB i2cRead(ackbit): i2cData
  ' Read in i2c data, Data byte is output MSB first, SDA data line is valid
  ' only while the SCL line is HIGH
  if i2cStarted == true
    ' set the SCL to output and the SDA to input
    dira[i2cSCL] ~~
    dira[i2cSDA] ~
    outa[i2cSCL] := _pinLow

    ' clock in the byte
    i2cData := 0
    repeat 8
      outa[i2cSCL] := _pinHigh
      i2cData := (i2cData << 1) | ina[i2cSDA]
      outa[i2cSCL] := _pinLow

    ' send the ACK or NAK
    dira[i2cSDA] ~~
    outa[i2cSCL] := _pinHigh
    outa[i2cSDA] := ackbit
    outa[i2cSCL] := _pinLow

    ' return the data
    return i2cData
