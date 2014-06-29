; === tamarack TBI TC9021 specific definition ===


; +++ I/O resisters +++

DMACtrl			equ	000h
RxDMAStatus		equ	008h
TFDListPtr		equ	010h
TFDListPtrHi		equ	014h
TxDMABurstThresh	equ	018h
TxDMAUrgentThresh	equ	019h
TxDMAPollPeriod		equ	01Ah
RFDListPtr		equ	01Ch
RFDListPtrHi		equ	020h
RxDMABurstThresh	equ	024h
RxDMAUrgentThresh	equ	025h
RxDMAPollPeriod		equ	026h
RxDMAIntCtrl		equ	028h
DebugCtrl		equ	02Ch
AsicCtrl		equ	030h
FIFOCtrl		equ	038h
RxEarlyThresh		equ	03Ah
FlowOffThresh		equ	03Ch
FlowOnThresh		equ	03Eh
TxStartThresh		equ	044h
EepromData		equ	048h
EepromCtrl		equ	04Ah
ExpRomAddr		equ	04Ch
ExpRomData		equ	050h
WakeEvent		equ	051h
Countdown		equ	054h
IntStatusAck		equ	05Ah
IntEnable		equ	05Ch
IntStatus		equ	05Eh
TxStatus		equ	060h
MACCtrl			equ	06Ch
VLANTag			equ	070h
PhyCtrl			equ	076h
StationAddress		equ	078h
VLANHashTable		equ	07Eh
VLANId			equ	080h
MaxFrameSize		equ	086h
ReceiveMode		equ	088h
HashTable		equ	08Ch
HashTableHi		equ	090h
RMONStatisticsMask	equ	098h
StatisticsMask		equ	09Ch


; *** AsicCtrl(30h 32bits) bits ***
ExpRomDisable		equ	     1	; (reserved)
ExpRomSize		equ	     2	; rw  0:32KB, 1:64KB
PhySpeed10		equ	    10h	; r
PhySpeed100		equ	    20h	; r
PhySpeed1000		equ	    40h	; r
PhyMedia		equ	    80h	; r  0:twisted-pair, 1:fiber
ForceConfig		equ	   700h	; rw
D3ResetDisable		equ	   800h	; rw
SpeedupMode		equ	  2000h	; rw
LEDMode			equ	  4000h	: rw
RstOutPolarity		equ	  8000h	; rw
GlobalReset		equ	 10000h	; w
RxReset			equ	 20000h	; w
TxReset			equ	 40000h	; w
DMA			equ	 80000h	; w
FIFO			equ	100000h	; w
Network			equ	200000h	; w
Host			equ	400000h	; w
AutoInit		equ	800000h	; w
RstOut			equ	1000000h	; w
InterruptRequest	equ	2000000h	; w
ResetBusy		equ	4000000h	; w

; *** Countdown (54h 32bits) bits ***
Count			equ	0ffffh	; rw  count mask
CountdownSpeed		equ	1000000h	; rw 0:3200ns, 1:320ns
CountdownMode		equ	2000000h	; rw 1:TxDMAComplete
CountdownIntEnabled	equ	4000000h	; r

; *** DebugCtrl (2Ch 16bits) bits ***
GPIO0Ctrl		equ	1
GPIO1Ctrl		equ	2
GPIO0			equ	4
GPIO1			equ	8
dbDisableDnHalt		equ	10h
dbDisableUpHalt		equ	20h
dbWrSameFSH		equ	40h
dbNearEmpty		equ	80h
dbSyncContrDone		equ	100h
dbFrCurDoneAck		equ	200h
dbFrcSpd1000		equ	400h

; *** DMACtrl (00h 32bit) bits ***
dcRxDMAComplete		equ	    8	; r
RxDMAPollNow		equ	   10h	; w
dcTxDMAComplete		equ	  800h	; r
TxDMAPollNow		equ	 1000h	; w
TxDMAInProg		equ	 8000h	; r
RxEarlyDisable		equ	10000h	; rw
MWIDisable		equ	40000h	; rw  Memory Write Invalidate
TxWriteBackDisable	equ	80000h	; rw  TFDDone bit
TxBurstLimit		equ	700000h	; rw  1-5 count of TFD FragInfos
TargetAbort		equ	40000000h	; r (PCI)
MasterAbort		equ	80000000h	; r (PCI)

; *** EepromCtrl (4Ah 16bit) bits ****
EepromAddress		equ	 0FFh	; mask  address and sub-command
EepromOpcode		equ	0300h	; mask  opecode
EepromBusy		equ	8000h	; busy bit

; *** FIFOCtrl (38h 16bit) bits ***
RAMTestMode		equ	1	; rw
Transmiting		equ	4000h	; r
Receiving		equ	8000h	; r

; *** FlowOffThresh (3Ch 16bit),
;     FlowOnThresh (3Eh 16bit)  ***
FlowThreshMask		equ	7FFh	; 16bytes * count

; *** IntEnable (5Ch 16bit), IntStatus (5Eh), IntStatusAck(5Ah) ***
InterruptStatus		equ	1	; rw
HostError		equ	2	; rw
iTxComplete		equ	4	; rw  (clear read TxStatus)
MACControlFrame		equ	8	; rsc  received MAC Control frame
RxComplete		equ	10h	; rw  received into FIFO
RxEarly			equ	20h	; rsc
IntRequested		equ	40h	; rsc  AsicCtrl or Countdown
UpdateStats		equ	80h	; rw
iLinkEvent		equ	100h	; rs
TxDMAComplete		equ	200h	; rsc
RxDMAComplete		equ	400h	; rsc
RFDListEND		equ	800h	; rsc
RxDMAPriority		equ	1000h	; rsc

; *** MACCtrl (6Ch 32bit) bits ***
IFSSelect		equ	3	; rw mask Inter-Frame Spacing
DuplexSelect		equ	20h	; rw  0:half 1:full
RcvLargeFrames		equ	40h	; rw (reserved)
TxFlowControlEnable	equ	80h	; rw
RxFlowControlEnable	equ	100h	; rw
RcvFCS			equ	200h	; rw  Receive Frame Check Sequence
FIFOLoopback		equ	400h	; rw
MACLoopback		equ	800h	; rw
AutoVLANtagging		equ	1000h	; rw
AutoVLANuntagging	equ	2000h	; rw
CollisionDetect		equ	10000h	; r
CarrierSense		equ	20000h	; r
StatisticsEnable	equ	200000h	; w
StatisticsDisable	equ	400000h	; w
StatisticsEnabled	equ	800000h	; r
TxEnable		equ	1000000h	; w
TxDisable		equ	2000000h	; w
TxEnabled		equ	4000000h	; r
RxEnable		equ	8000000h	; w
RxDisable		equ	10000000h	; w
RxEnabled		equ	20000000h	; r
Paused			equ	40000000h	; r

; *** PhyCtrl (76h 8bit) bits ***
MgmtClk			equ	1	; rw  clock
MgmtData		equ	2	; rw  data bit
MgmtDir			equ	4	; rw  direction
PhyDuplexPolarity	equ	8	; rw
PhyDuplexStatus		equ	10h	; r
PhyLnkPolarity		equ	20h	; rw
LinkSpeed		equ	0C0h	; r  mask

; *** ReceiveMode (88h 16bit) bits ***
ReceiveUnicast		equ	1	; rw
ReceiveMulticast	equ	2	; rw
ReceiveBroadcast	equ	4	; rw
ReceiveAllFrames	equ	8	; rw
ReceiveMulticastHash	equ	10h	; rw
ReceiveIPMulticast	equ	20h	; rw
ReceiveVLANMatch	equ	100h	; rw
ReceiveVLANHash		equ	200h	; rw

; *** RxDMAIntCtrl (28h 32bit) bits ***
RxFrameCount		equ	0ffh	; rw  mask
PriorityThresh		equ	0C00h	; rw  mask
RxDMAWaitTime		equ	0ffff0000h	; rw mask  64ns * count

; *** TxStatus (60h 32bit) bits ***
;   Cleared with read.
TxError			equ	1	; r
LateCollision		equ	4	; r
MaxCollision		equ	8	; r
TxUnderrun		equ	10h	; r
TxIndicateReqd		equ	40h	; r
TxComplete		equ	80h	; r
TxFrameId		equ	0ffff0000h	; r  mask

; *** WakeEvent (51h 8bit) bits ***
WakePktEnable		equ	1	; rw
MagicPktEnable		equ	2	; rw
LinkEventEnable		equ	4	; rw
WakePolarity		equ	8	; rw
WakePktEvent		equ	10h	; r
MagicPktEvent		equ	20h	; r
wLinkEvent		equ	40h	; r
WakeOnLanEnable		equ	80h	; rw


; *** RMONStatisticsMask (98h 32bit) bits ***
RStatAllMask		equ	7FFFFh	; rw  0:ON 1:OFF

; *** StatisticsMask (9Ch 32bit) bits ***
StatAllMask		equ	00FFFFFFh	; rw  0:ON 1:OFF
StatRxOctFrmOK		equ	1
StatRxMcOctFrmOK	equ	2
StatRxBcOctFrmOK	equ	4
StatTxOctFrmOK		equ	1000h
StatTxMcOctFrmOK	equ	2000h
StatTxBcOctFrmOK	equ	4000h

; +++ MIB Statistics register +++
OctetRcvOk		equ	0A8h	; 32bit
McstOctetRcvdOk		equ	0ACh	; 32bit
BcstOctetRcvOk		equ	0B0h	; 32bit
FramesRcvdOk		equ	0B4h	; 32bit
McstFramesRcvdOk	equ	0B8h	; 32bit
BcstFramesRcvdOk	equ	0BEh	; 16bit
MacControlFramesRcvd	equ	0C6h	; 16bit
FrameTooLongErrors	equ	0C8h	; 16bit
InRangeLengthErrors	equ	0CAh	; 16bit
FramesCheckSeqErrors	equ	0CCh	; 16bit
FramesLostRxErrors	equ	0CEh	; 16bit
OctetXmtOk		equ	0D0h	; 32bit
McstOctetXmtOk		equ	0D4h	; 32bit
BcastOctetXmtOk		equ	0D8h	; 32bit
FramesXmtdOk		equ	0DCh	; 32bit
McstFramesXmtdOk	equ	0E0h	; 32bit
FramesWDeferredXmt	equ	0E4h	; 32bit
LateCollisions		equ	0E8h	; 32bit
MultiColFrames		equ	0ECh	; 32bit
SingleColFrames		equ	0F0h	; 32bit
BcstFramesXmtdOk	equ	0F6h	; 16bit
CarrierSenseErrors	equ	0F8h	; 16bit
MacControlFramesXmtd	equ	0FAh	; 16bit
FramesAbortXSColls	equ	0FCh	; 16bit
FramesWEXDeferal	equ	0FEh	; 16bit

RxJumboFrames		equ	0BCh	; 16bit
TCPCheckSumErrors	equ	0C0h	; 16bit
IPCheckSumErrors	equ	0C2h	; 16bit
UDPCheckSumErrors	equ	0C4h	; 16bit
TxJumboFrames		equ	0F4h	; 16bit


; +++ eeprom field layout +++
eepConfigParam		equ	0
eepAsicCtrl		equ	1
eepSubVendorID		equ	2
eepSubSystemID		equ	3
eepStationAddress	equ	10h	; 3 word


; +++ Frame Descriptor +++
; *** Fragment Information ***
FragInfo	struc
FragAddr	dd	?	; fragment physical address
FragAddrHi	dw	0	; 40bit
FragLen		dw	?	; fragment length
FragInfo	ends

; *** Transmit Frame Control ***
_TFC		struc
FrameId		dw	?	; frame ID  (see TxStatus register)
TFCflags	dw	?	; lower flags
TFCVLANtags	dw	?	; related to VLAN
rsvd		dw	0	; reserved (NULL)
_TFC		ends

; *** Receive Frame Status ***
_RFS		struc
RxFrameLen	dw	?	; length of recieved frame
RFSflags	dw	?	; lower status
TCI		dw	?	; tag control information
rsvd		dw	0	; reserved (NULL)
_RFS		ends

; *** Transmit Frame Descriptor ***
TFD		struc
TFDNextPtr	dd	?	; Next TFD pointer (40bit)
TFDNextPtrHi	dd	0
TFC		_TFC	<>	; Transmit frame control
FragInfo0	FragInfo  9 dup (<>)	; fragments
; above for device, below for driver
PhysAddr	dd	?	; physical addr of this descriptor
ImmedPhysAddr	dd	?	; physical addr of immediate data
ImmedVAddr	dw	?	; virtual addr of immediate data
ProtID		dw	?	; requester protocol ID
ReqHandle	dw	?	; request handle
vlink		dw	?	; virtual link for driver access
TFD		ends

; *** Receive Frame Descriptor ***
RFD		struc
RFDNextPtr	dd	?	; next RFD pointer (40bit)
RFDNextPtrHi	dd	0
RFS		_RFS	<>
FragInfo0	FragInfo <>	; one fragment
; above for device, below for driver
PhysAddr	dd	?	; physical addr of this descriptor
FragVAddr	dd	?	; virtual addr of fragment buffer
DescID		dw	?	; descriptor id
LastDesc	dw	?	; last descriptor of the frame
vlink		dw	?	; virtual link for driver access
		dw	?	; reserve for 8byte alignment
RFD		ends

; *** Transmit Frame Control flags ***
TxWordAlign		equ	3	; alignment  (mask)
TCPChecksumEnable	equ	4	;
UDPChecksumEnable	equ	8	;
IPCheckEnable		equ	10h	;
FCSAppendDisable	equ	20h	;
TxIndicate		equ	40h	; request a TxComplete intr.
TxDMAIndicate		equ	80h	; req. a TxDMAComplete intr.
FragCount		equ	0F00h	; count of frag. 4bit (1-15)
VLANTagInsert		equ	1000h	;
TFDDone			equ	8000h	; 0:Device 1:Host own

; *** Recieve Frame Status flags ***
RxFIFOOverrun		equ	1	;
RxRuntFrame		equ	2	;
RxAlignmentError	equ	4	;
RxFCSError		equ	8	;
RxOversizedFrame	equ	10h	;
RxLengthError		equ	20h	;
VLANDetected		equ	40h	;
TCPDetected		equ	80h	;
TCPError		equ	100h	;
UDPDetected		equ	200h	;
UDPError		equ	400h	;
IPDetected		equ	800h	;
IPError			equ	1000h	;
FrameStart		equ	2000h	;
FrameEnd		equ	4000h	;
RFDDone			equ	8000h	; 0:Device 1:Host own
