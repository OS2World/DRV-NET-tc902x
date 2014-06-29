; *** Hardware dependent resident part definition

; --- Driver Version ---
extern	DrvMajVer : abs
extern	DrvMinVer : abs

; --- DMA Descriptor management ---
extern	TxHead : word
extern	TxFreeHead : word
extern	TxCount : word
extern	TxFreeCount : word
extern	TxIntReq : byte
extern	TxPendCount : byte

extern	RxHead : word
extern	RxTail : word
extern	RxBusyHead : word
extern	RxBusyTail : word

; --- System(PCI) Resource ---
extern	IOaddr : word
extern	MEMSel : word		; selector for MEMaddr
extern	MEMaddr : dword
extern	IRQlevel : byte
extern	stsMWI : byte

; --- Configuration Memory Image Parameters ---
extern	cfgSLOT : byte
extern	cfgTXQUEUE : byte
extern	cfgRXQUEUE : byte
extern	cfgMAXFRAMESIZE : word
extern	cfgTxStartThresh : word
extern	cfgRxEarlyThresh : word
extern	cfgTxIntDelay : word
extern	cfgRxIntDelay : word
extern	cfgRxIntCount : byte
extern	cfgFlowOffThresh : word
extern	cfgFlowOnThresh : word
extern	cfgTFCflags : byte
extern	cfgRxAcErr : word
extern	cfgRxChkSum : word

; --- Receive Buffer Address ---
extern	RxBufferLin : dword
extern	RxBufferPhys : dword
extern	RxBufferSize : dword
extern	RxBufferSelCnt : word
extern	RxBufferSel : word

; --- Vendor Adapter Decription ---
extern	AdapterDesc : byte


; --- Hardware Specific functions ---
extern	_hwTxChain : near16
extern	_hwRxRelease : near16
extern	_hwEnableRxInd : near16
extern	_hwDisableRxInd : near16
extern	_hwSetMACaddr : near16
extern	_hwOpen : near16
extern	_hwClose : near16
extern	_hwIntReq : near16
extern	_hwUpdatePktFlt : near16
extern	_hwUpdateMulticast : near16
extern	_hwUpdateStat : near16
extern	_hwClearStat : near16
extern	_hwReset : near16

extern	_hwCheckInt : near16
extern	_hwDisableInt : near16
extern	_hwEnableInt : near16
extern	_hwServiceInt : near16
extern	_hwPollLink : near16
