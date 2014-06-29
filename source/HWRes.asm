; *** Resident part: Hardware dependent ***

include	NDISdef.inc
include	tc9021.inc
include	MIIdef.inc
include	misc.inc
include	DrvRes.inc

extern	DosIODelayCnt : far16

public	DrvMajVer, DrvMinVer
DrvMajVer	equ	1
DrvMinVer	equ	1*16+0		; 10

.386

_DATA	segment	public word use16 'DATA'

; --- DMA Descriptor management ---
public	TxHead, TxFreeHead, TxCount, TxFreeCount, TxIntReq, TxPendCount
TxHead		dw	0
TxFreeHead	dw	0
TxCount		dw	0
TxFreeCount	dw	0
TxIntReq	db	0
TxPendCount	db	8

public	RxHead, RxTail, RxBusyHead, RxBusyTail, RxInProg
RxHead		dw	0
RxTail		dw	0
RxBusyHead	dw	0
RxBusyTail	dw	0
RxInProg	dw	0

; --- System(PCI) Resource ---
public	IOaddr, MEMSel, MEMaddr, IRQlevel, stsMWI
IOaddr		dw	?
MEMSel		dw	?
MEMaddr		dd	?
IRQlevel	db	?
stsMWI		db	0	; cache line size

; --- Physical information ---
PhyInfo		_PhyInfo <>

MediaSpeed	db	0
MediaDuplex	db	0
MediaPause	db	0
MediaLink	db	0
;MediaType	db	0

; --- Register Contents ---
regIntMask	dw	0
regReceiveMode	dw	0
regHashTable	dq	0

; --- ReceiveChain Frame Descriptor ---
RxFrameLen	dw	0
RxDesc		RxFrameDesc	<>


; --- Configuration Memory Image Parameters ---
public	cfgSLOT, cfgTXQUEUE, cfgRXQUEUE, cfgMAXFRAMESIZE
public	cfgTxStartThresh, cfgRxEarlyThresh
public	cfgTxIntDelay, cfgRxIntDelay, cfgRxIntCount
public	cfgFlowOffThresh, cfgFlowOnThresh
cfgSLOT		db	0
cfgTXQUEUE	db	8
cfgRXQUEUE	db	16

cfgTxStartThresh	dw	1536/4	; n*4byte  1..fff
cfgRxEarlyThresh	dw	256/8	; n*8byte  1..7ff

cfgTxBurstThresh	db	3072/32	; n*32byte  8..ff
cfgTxUrgentThresh	db	768/32	; n*32byte  4..ff
cfgTxPollPeriod		db	255	; n*320ns  1..ff
cfgTxIntDelay		dw	128	; n*320ns 1..ffff Countdown

cfgRxBurstThresh	db	1280/32	; n*32byte  8..ff
cfgRxUrgentThresh	db	4608/32	; n*32byte  4..ff
cfgRxPollPeriod		db	255	; n*320ns  1..ff
cfgRxIntDelay		dw	576	; n*64ns  0..ffff
cfgRxIntCount		db	4	; 1..ff
cfgMAXFRAMESIZE		dw	1514

cfgFlowOffThresh	dw	8192/16	; n*16byte 0..7ff
cfgFlowOnThresh		dw	24576/16 ; n*16byte 0..7ff

public	cfgRxAcErr, cfgRxChkSum
cfgRxAcErr	dw	RxFIFOOverrun or RxRuntFrame or \
		  RxFCSError or RxLengthError
cfgRxChkSum	dw	UDPError or IPError	; remove TCPError

public	cfgTFCflags
cfgTFCflags	db	1	; alignment disable

; --- Receive Buffer address ---
public	RxBufferLin, RxBufferPhys, RxBufferSize, RxBufferSelCnt, RxBufferSel
RxBufferLin	dd	?
RxBufferPhys	dd	?
RxBufferSize	dd	?
RxBufferSelCnt	dw	?
RxBufferSel	dw	6 dup (?)	; max is 6.

; --- Vendor Adapter Decription ---
public	AdapterDesc
AdapterDesc	db	'TAMARACK tmi TC902x GbE Adapter',0


_DATA	ends

_TEXT	segment	public word use16 'CODE'
	assume	ds:_DATA
	
_hwTxChain	proc	near
	push	bp
	mov	bp,sp
	push	offset semTx
	call	_EnterCrit
	mov	ax,[TxFreeCount]
	xor	bx,bx
	dec	ax
	jl	short loc_1	; No Free Tx Descriptor
	mov	[TxFreeCount],ax
	mov	bx,[TxFreeHead]
	mov	ax,[bx].TFD.vlink
	mov	[TxFreeHead],ax
loc_1:
	call	_LeaveCrit
	or	bx,bx
	jnz	short loc_2
	mov	ax,OUT_OF_RESOURCE
	pop	bx	; stack adjust
	pop	bp
	retn

loc_2:
	push	gs
	mov	ax,[bp+8]
	mov	dx,[bp+10]
	mov	[bx].TFD.ProtID,dx
	mov	[bx].TFD.ReqHandle,ax
	lgs	bp,[bp+4]
	mov	cx,gs:[bp]
	mov	si,10h
	or	cx,cx
	jz	short loc_3	; No Immediate Data

	push	si
	push	fs
	push	ds
	pop	es
	lfs	si,gs:[bp].TxFrameDesc.TxImmedPtr
	mov	di,[bx].TFD.ImmedVAddr
	mov	dx,cx
	rep	movsb	es:[di],fs:[si]
	pop	fs
	pop	si
	mov	eax,[bx].TFD.ImmedPhysAddr
	mov	[bx+si].FragInfo.FragAddr,eax
	mov	[bx+si].FragInfo.FragLen,dx
	add	si,sizeof(FragInfo)
	inc	cx		; inc FragCount 
loc_3:
	mov	di,gs:[bp].TxFrameDesc.TxDataCount
	or	di,di
	jz	short loc_6
	add	cx,di		; total FragCount
	lea	bp,[bp].TxFrameDesc.TxBufDesc1
loc_4:
	cmp	gs:[bp].TxBufDesc.TxPtrType,0
	mov	eax,gs:[bp].TxBufDesc.TxDataPtr
	jz	short loc_5
	push	eax
	call	_VirtToPhys
	add	sp,4
loc_5:
	mov	dx,gs:[bp].TxBufDesc.TxDataLen
	mov	[bx+si].FragInfo.FragAddr,eax
	mov	[bx+si].FragInfo.FragLen,dx
	add	bp,sizeof(TxBufDesc)
	add	si,sizeof(FragInfo)
	dec	di
	jnz	short loc_4

loc_6:
	pop	gs
	call	_EnterCrit
	mov	al,[cfgTFCflags]
	mov	ah,cl
	mov	word ptr [bx].TFD.TFC.TFCflags,ax
;	mov	byte ptr [bx].TFD.TFC.TFCflags,1 ; alignment disable
;	mov	byte ptr [bx].TFD.TFC.TFCflags[1],cl ; FragCount
	inc	[TxCount]
	mov	dx,[IOaddr]
	mov	ax,TxDMAPollNow
	add	dx,DMACtrl
	out	dx,ax

	mov	al,1
	xchg	al,[TxIntReq]
	or	al,al
	jnz	short loc_7
	mov	dx,[IOaddr]
	mov	eax,CountdownSpeed
	add	dx,Countdown
	mov	ax,[cfgTxIntDelay]
	out	dx,eax		; Countdown start
loc_7:
	call	_LeaveCrit
	pop	cx	; stack adjust
	mov	ax,REQUEST_QUEUED
	pop	bp
	retn
_hwTxChain	endp


_hwRxRelease	proc	near
	push	bp
	mov	bp,sp
	push	si
	push	di
	push	offset semRx
	call	_EnterCrit
	mov	ax,[bp+4]		; ReqHandle
	mov	bx,[RxInProg]
	xor	di,di
	or	bx,bx			; no frame in progress
	jz	short loc_0
	cmp	ax,[bx].RFD.DescID	; match with progress frame
	jnz	short loc_0
	mov	si,[bx].RFD.LastDesc
	mov	[RxInProg],di
	jmp	short loc_5

loc_0:
	mov	bx,[RxBusyHead]
loc_1:
	or	bx,bx			; queue empty
	jz	short loc_ex
	cmp	ax,[bx].RFD.DescID
	mov	si,[bx].RFD.LastDesc
	jz	short loc_2		; handle match frame found
	mov	di,si
	mov	bx,[si].RFD.vlink
	jmp	short loc_1
loc_2:
				; bx:head, si:tail, di:prev
	or	di,di
	mov	ax,[si].RFD.vlink
	jz	short loc_4		; list top
	cmp	si,[RxBusyTail]
	mov	[di].RFD.vlink,ax	; next or 0
	jnz	short loc_5		; middle
loc_3:
	mov	[RxBusyTail],di
	jmp	short loc_5
loc_4:
	mov	[RxBusyHead],ax

loc_5:
	xor	eax,eax
	mov	di,bx
loc_6:
	cmp	di,si
	mov	[di].RFD.RFS.RxFrameLen,ax
	jz	short loc_7
	mov	[di].RFD.RFS.RFSflags,ax
	mov	di,[di].RFD.vlink
	jmp	short loc_6
loc_7:
	mov	[di].RFD.RFS.RFSflags,RFDDone
	mov	[di].RFD.vlink,ax
	mov	si,[RxTail]
	mov	[RxTail],di
	mov	[si].RFD.vlink,bx
	mov	[di].RFD.RFDNextPtr,eax
	mov	ecx,[bx].RFD.PhysAddr
	mov	[si].RFD.RFDNextPtr,ecx
	mov	[si].RFD.RFS.RFSflags,ax

	mov	dx,[IOaddr]
;	add	dx,DMACtrl
	mov	ax,RxDMAPollNow
	out	dx,ax

loc_ex:
	call	_LeaveCrit
	mov	ax,SUCCESS
	pop	bp	; stack adjust
	pop	di
	pop	si
	pop	bp
	retn
_hwRxRelease	endp



_ServiceIntTx	proc	near
	enter	4,0
it_sc	equ	bp-2
it_fc	equ	bp-4

	xor	ax,ax
	mov	[it_fc],ax
	mov	[it_sc],ax

	push	offset semTx
	call	_EnterCrit
	mov	dx,[IOaddr]
	mov	bx,[TxHead]
	mov	cx,[TxCount]
	add	dx,TxStatus
	mov	si,bx
	mov	di,cx
	in	eax,dx
IF 0
	test	al,TxComplete
ELSE
	test	eax,eax			; asus nx1101 custumize
ENDIF

	jz	short loc_cp		; invalid status
	mov	[TxPendCount],8
	test	al,TxError
	jnz	short loc_e		; error

	shr	eax,16
	or	cx,cx
	jz	short loc_s2		; no descriptor
loc_s1:
	test	byte ptr [bx].TFD.TFC.TFCflags[1],high(TFDDone)
	jz	short loc_s2		; incomplete?
	cmp	ax,[bx].TFD.TFC.FrameId
	mov	bx,[bx].TFD.vlink
	jz	short loc_s3
	dec	cx
	jnz	short loc_s1
loc_s2:
	jmp	near ptr loc_cr1
loc_s3:
	dec	cx
	mov	[TxHead],bx
	mov	[TxCount],cx
	sub	di,cx
	mov	[it_sc],di
	jmp	near ptr loc_cr1


loc_cp:
	add	dx,(MACCtrl +2 - TxStatus)
	in	ax,dx
	test	ax,highword(Paused)
	jnz	short loc_cr1	; Stop Tx with Rx pause.
	dec	[TxPendCount]
	jnz	short loc_cr1
		; excess invalid TxStatus loop. Tx logic hang?
		; remove all descriptor and TxReset.
	or	eax,-1		; set invalid FrameId


loc_e:
		; TxError - Remove done frame and TxReset
	shr	eax,16
	or	cx,cx
	jz	short loc_e6
loc_e1:
	test	byte ptr [bx].TFD.TFC.TFCflags[1],high(TFDDone)
	jz	short loc_e2
	cmp	ax,[bx].TFD.TFC.FrameId
	mov	bx,[bx].TFD.vlink
	jz	short loc_e3
	dec	cx
	jnz	short loc_e1
	sub	di,cx
loc_e2:
	mov	[TxHead],bx
	mov	[TxCount],cx
	mov	[it_fc],di
	jmp	short loc_e6
loc_e3:
	mov	dx,cx
loc_e4:
	dec	cx
	jz	short loc_e5
	test	byte ptr [bx].TFD.TFC.TFCflags[1],high(TFDDone)
	jz	short loc_e5
	mov	bx,[bx].TFD.vlink
	jmp	short loc_e4
loc_e5:
	mov	[TxCount],cx
	mov	[TxHead],bx
	sub	di,dx
	sub	dx,cx
	mov	[it_sc],di
	mov	[it_fc],dx
loc_e6:
	mov	dx,[IOaddr]
	add	dx,AsicCtrl
	in	eax,dx
	or	eax,TxReset or FIFO or DMA
	out	dx,eax
loc_e7:
	in	eax,dx
	test	eax,ResetBusy
	jnz	short loc_e7
	call	_InitTx
	mov	dx,IOaddr
	add	dx,MACCtrl+2
	mov	ax,highword(TxEnable)
	out	dx,ax

loc_cr1:
	mov	dx,IOaddr
	cmp	[TxCount],0
	jnz	short loc_cr3
	xor	eax,eax
	mov	[TxIntReq],al
	jmp	short loc_cr4
loc_cr3:
	mov	eax,CountdownSpeed
	mov	ax,cfgTxIntDelay
loc_cr4:
	add	dx,Countdown
	out	dx,eax
	call	_LeaveCrit

	mov	di,[it_sc]
	or	di,di
	jz	short loc_cf2
loc_cf1:
	mov	bx,SUCCESS
	call	_TxConfirm
	mov	si,[si].TFD.vlink
	dec	di
	jnz	short loc_cf1
loc_cf2:
	mov	di,[it_fc]
	or	di,di
	jz	short loc_cf4
loc_cf3:
	mov	bx,GENERAL_FAILURE
	call	_TxConfirm
	mov	si,[si].TFD.vlink
	dec	di
	jnz	short loc_cf3
loc_cf4:
	mov	ax,[it_sc]
	add	ax,[it_fc]
	jz	short loc_ex

	call	_EnterCrit
	add	[TxFreeCount],ax
	call	_LeaveCrit
loc_ex:
	pop	ax	; stack adjust
	leave
	retn
_ServiceIntTx	endp

_TxConfirm	proc	near
	push	si
	push	di
	mov	cx,[si].TFD.ProtID
	mov	ax,[si].TFD.ReqHandle
	or	ax,ax
	jz	short loc_1
	mov	dx,[CommonChar.moduleID]
	mov	di,[ProtDS]

	push	cx	; ProtID
	push	dx	; MACID
	push	ax	; ReqHandle
	push	bx	; Status
	push	di	; ProtDS
	call	dword ptr [LowDisp.txconfirm]
loc_1:
	pop	di
	pop	si
	retn
_TxConfirm	endp


_ServiceIntRx	proc	near
	push	bp
	push	offset semRx
loc_0:
	call	_EnterCrit

	mov	di,[RxInProg]
	mov	bx,[RxHead]
	or	di,di
;	jnz	short loc_3		; frame in progress exist
	jnz	near ptr loc_3
	cmp	bx,[RxTail]
	jz	short loc_ex		; queue tail
	mov	ax,[bx].RFD.RFS.RFSflags
	test	ah,high(RFDDone)
	jz	short loc_ex		; no received
	test	ah,high(FrameStart)
	jz	short loc_ns		; no start mark

	xor	cx,cx
	mov	si,offset RxDesc.RxBufDesc1
	xor	bp,bp
loc_1:
	mov	edx,[bx].RFD.FragVAddr	; data pointer
	mov	[si].RxBufDesc.RxDataPtr,edx
	inc	cx			; fragment count
	test	ah,high(FrameEnd)
;	jnz	short loc_2		; end mark found
	jnz	near ptr loc_2
	cmp	cl,8
	jnc	short loc_rmc		; too long frame
	mov	ax,[bx].RFD.FragInfo0.FragLen	; fragment length
	mov	dx,bx
	add	bp,ax			; frame length
	mov	[si].RxBufDesc.RxDataLen,ax
	cmp	bp,[cfgMAXFRAMESIZE]
	ja	short loc_rmc
	mov	bx,[bx].RFD.vlink
	add	si,sizeof(RxBufDesc)
	cmp	bx,[RxTail]
	jz	short loc_ex		; queue tail
	mov	ax,[bx].RFD.RFS.RFSflags
	test	ah,high(RFDDone)
	jz	short loc_ex
	test	ah,high(FrameStart)	; second start mark
	jz	short loc_1
	jmp	short loc_rmp

loc_ex:
	call	_LeaveCrit
	pop	ax
	pop	bp
	retn

loc_ns:
	mov	dx,bx
	mov	bx,[bx].RFD.vlink
	mov	ax,[bx].RFD.RFS.RFSflags
	test	ah,high(RFDDone)
	jz	short loc_rmp
	test	ah,high(FrameStart)
	jz	short loc_ns
loc_rmp:
	mov	bx,dx			; previous pointer
loc_rmc:
	mov	si,[RxHead]
	xor	ax,ax
loc_rm2:
	cmp	si,bx
	mov	[si].RFD.RFS.RxFrameLen,ax
	jz	short loc_rm3		; tail
	mov	[si].RFD.RFS.RFSflags,ax
	mov	si,[si].RFD.vlink
	jmp	short loc_rm2
loc_rm3:
	mov	[si].RFD.RFS.RFSflags,RFDDone ; terminate
	mov	dx,[si].RFD.vlink
	mov	[si].RFD.vlink,ax
	mov	bx,[RxHead]
	mov	di,[RxTail]
	mov	[RxHead],dx
	mov	[RxTail],si
	mov	[di].RFD.vlink,bx
	mov	ecx,[bx].RFD.PhysAddr
	mov	[di].RFD.RFDNextPtr,ecx
	mov	[di].RFD.RFS.RFSflags,ax

	mov	dx,[IOaddr]
;	add	dx,DMACtrl
	mov	ax,RxDMAPollNow
	out	dx,ax

	call	_LeaveCrit
;	jmp	short loc_0
	jmp	near ptr loc_0


loc_2:
;	test	ax,RxFIFOOverrun or RxRuntFrame or \
;		  RxFCSError or RxLengthError
	test	ax,[cfgRxAcErr]
	mov	dx,ax
	jnz	short loc_rmc		; errored frame
	shl	dx,1
	and	ax,dx
;	test	ax,TCPError or UDPError or IPError
;	test	ax,UDPError or IPError
	test	ax,[cfgRxChkSum]
	jnz	short loc_rmc		; checksum errored frame
	mov	ax,[bx].RFD.RFS.RxFrameLen
	cmp	ax,[cfgMAXFRAMESIZE]	; too long frame
	ja	short loc_rmc
	mov	[RxFrameLen],ax
	sub	ax,bp			; last fragment length
	jbe	short loc_rmc
	mov	[si].RxBufDesc.RxDataLen,ax
	mov	bp,[bx].RFD.vlink
	mov	di,[RxHead]
	mov	[RxHead],bp
	mov	[di].RFD.LastDesc,bx
	mov	[RxInProg],di
	mov	[RxDesc.RxDataCount],cx
loc_3:
	call	_LeaveCrit

	call	_IndicationChkOFF
	or	ax,ax
	jz	short loc_sp

	push	-1		; indicate
	mov	dx,[di].RFD.DescID	; request handle
	mov	cx,[RxFrameLen]
	mov	ax,[CommonChar.moduleID]
	mov	bx,[ProtDS]
	mov	si,sp
	push	dx		; handle

	push	ax		; MACID
	push	cx		; FrameSize
	push	dx		; ReqHandle
	push	ds
	push	offset RxDesc	; RxBufDesc
	push	ss
	push	si		; Indicate
	push	bx		; ProtDS
	call	dword ptr [LowDisp.rxchain]
lock	or	[drvflags],mask df_idcp
	cmp	ax,WAIT_FOR_RELEASE
	jz	short loc_bq	; wait RxRelease from protocol
	call	_hwRxRelease
	jmp	short loc_4

loc_bq:
	push	offset semRx
	call	_EnterCrit
	xor	ax,ax
	mov	bx,[RxInProg]
	mov	[RxInProg],ax
	or	bx,bx
	jz	short loc_bq3		; no frame

	mov	si,[bx].RFD.LastDesc
	cmp	ax,[RxBusyHead]
	jz	short loc_bq1		; queue empty
	mov	di,[RxBusyTail]
	mov	[di].RFD.vlink,bx
	jmp	short loc_bq2
loc_bq1:
	mov	[RxBusyHead],bx
loc_bq2:
	mov	[RxBusyTail],si
	mov	[si].RFD.vlink,ax
loc_bq3:
	call	_LeaveCrit
	pop	dx	; semRx
loc_4:
	pop	cx	; handle

	pop	ax
	cmp	al,-1
	jnz	short loc_5
	call	_IndicationON
	jmp	near ptr loc_0
loc_sp:
lock	or	[drvflags],mask df_rxsp
loc_5:
	pop	ax	; stack adjust - semRx
	pop	bp
	retn
_ServiceIntRx	endp


_hwServiceInt	proc	near
	enter	2,0
loc_0:
	mov	dx,IOaddr
	add	dx,IntStatus
	in	ax,dx
	and	ax,regIntMask
	jnz	short loc_1
	leave
	retn

loc_1:
	mov	[bp-2],ax

	test	word ptr [bp-2],IntRequested or iTxComplete
	jz	short loc_n1
	mov	ax,IntRequested
	test	word ptr [bp-2],IntRequested
	jz	short loc_tx
	mov	dx,IOaddr
	add	dx,IntStatus
	out	dx,ax		; clear
loc_tx:
	call	_ServiceIntTx

loc_n1:
	test	word ptr [bp-2],RxDMAComplete or RFDListEND or \
		  IntRequested
	jz	short loc_n2
	mov	ax,RxDMAComplete or RFDListEND
	mov	dx,IOaddr
	test	word ptr [bp-2],ax
	jnz	short loc_rx1

	test	drvflags,mask df_rxsp
	jnz	short loc_rx2
	jmp	short loc_n2
loc_rx1:
	add	dx,IntStatus
	out	dx,ax		; clear 
loc_rx2:
	call	_ServiceIntRx
IF 0
	test	word ptr [bp-2],RFDListEND
	jz	short loc_n2
	call	_ResetRxDMA
ENDIF

loc_n2:
	test	word ptr [bp-2],UpdateStats
	jz	short loc_n3
	call	_hwUpdateStat
loc_n3:
	jmp	short loc_0
_hwServiceInt	endp

_hwCheckInt	proc	near
	mov	dx,IOaddr
	add	dx,IntStatus
	in	ax,dx
	and	ax,InterruptStatus
	retn
_hwCheckInt	endp

_hwEnableInt	proc	near
	mov	dx,IOaddr
	mov	ax,regIntMask
	add	dx,IntEnable
	out	dx,ax
	retn
_hwEnableInt	endp

_hwDisableInt	proc	near
	mov	dx,IOaddr
	xor	ax,ax
	add	dx,IntEnable
	out	dx,ax
	retn
_hwDisableInt	endp

_hwIntReq	proc	near
	mov	dx,IOaddr
	mov	eax,InterruptRequest
	add	dx,AsicCtrl
	out	dx,eax
	retn
_hwIntReq	endp

_hwEnableRxInd	proc	near
	push	ax
	push	dx
lock	or	regIntMask,RxDMAComplete or RFDListEND
	cmp	semInt,0
	jnz	short loc_1
	mov	dx,IOaddr
	mov	ax,regIntMask
	add	dx,IntEnable
	out	dx,ax
loc_1:
	pop	dx
	pop	ax
	retn
_hwEnableRxInd	endp

_hwDisableRxInd	proc	near
	push	ax
	push	dx
lock	or	regIntMask,RxDMAComplete or RFDListEND
	cmp	semInt,0
	jnz	short loc_1
	mov	dx,IOaddr
	mov	ax,regIntMask
	add	dx,IntEnable
	out	dx,ax
loc_1:
	pop	dx
	pop	ax
	retn
_hwDisableRxInd	endp

_hwPollLink	proc	near
	call	_ChkLink
	test	al,MediaLink
	jz	short loc_0	; Link status change/down
	retn
loc_0:
	or	al,al
	mov	MediaLink,al
	jnz	short loc_1	; Link Active
	call	_ChkLink
	or	al,al
	jnz	short loc_1
	retn
loc_1:
	cli
	mov	al,1
	xchg	al,[semInt]	; get interrupt semaphore
	or	al,al
	jz	short loc_2
	call	_Delay1ms
	jmp	short loc_1
loc_2:
	call	_hwDisableInt
	sti
	call	_GetPhyMode

	cmp	al,MediaSpeed
	jnz	short loc_3
	cmp	ah,MediaDuplex
	jnz	short loc_3
	cmp	dl,MediaPause
	jz	short loc_4
loc_3:
	mov	MediaSpeed,al
	mov	MediaDuplex,ah
	mov	MediaPause,dl

	call	_StopTxDMA
	call	_StopRxDMA

	push	offset semTx
	call	_EnterCrit
	push	offset semRx
	call	_EnterCrit
	call	_SetMacEnv
	call	_LeaveCrit
	pop	ax
	call	_LeaveCrit
	pop	ax
loc_4:
	cli
	call	_hwIntReq	; interrupt for Tx Cleanup.(maybe loop 8 times:-))
	call	_hwEnableInt
	mov	al,0
	xchg	al,[semInt]	; release interrupt semaphore
	sti
	retn
_hwPollLink	endp

_hwOpen		proc	near	; call in protocol bind process?
	call	_ResetPhy
	cmp	ax,SUCCESS
	jnz	short loc_e
	call	_AutoNegotiate
	mov	MediaSpeed,al
	mov	MediaDuplex,ah
	mov	MediaPause,dl

	call	_ChkLink
	mov	MediaLink,al
	call	_SetMacEnv
	mov	dx,IOaddr
	or	ax,-1
	add	dx,IntStatus
	out	dx,ax		; clear interrupt status.
	mov	ax,iTxComplete or IntRequested or UpdateStats or \
	  RxDMAComplete or RFDListEND
	add	dx,(IntEnable - IntStatus)
	mov	regIntMask,ax
	out	dx,ax		; enable interrupt.
	mov	ax,SUCCESS
loc_e:
	retn
_hwOpen		endp

_SetMacEnv	proc	near
	mov	dx,IOaddr
	xor	eax,eax
	add	dx,MACCtrl
	out	dx,eax			; IFSSelect?

	mov	eax,StatisticsDisable or RxDisable or TxDisable
	mov	cl,MediaDuplex
	mov	al,MediaPause
	shl	cl,5
	shl	ax,7
	or	al,cl
	out	dx,eax			; media mode set.

	mov	dx,IOaddr
	add	dx,AsicCtrl
	in	eax,dx
	or	eax,RxReset or TxReset or DMA or FIFO or Network
	out	dx,eax		; MAC function reset
	in	eax,dx
loc_2:
	in	eax,dx
	test	eax,ResetBusy
	jnz	short loc_2

	add	dx,(DebugCtrl - AsicCtrl)
	mov	ax,230h
	out	dx,ax		; bug work-around??

	call	_SetPauseEnv
	call	_SetStatMask
	call	_SetTxEnv
	call	_SetRxEnv
	call	_InitTx
	call	_InitRx

	mov	dx,IOaddr
	add	dx,MACCtrl
	in	eax,dx
	or	eax,StatisticsEnable or RxEnable or TxEnable
	out	dx,eax			; enable function
	call	_SetSpeedStat
	retn
_SetMacEnv	endp

_InitTx		proc	near
	mov	dx,IOaddr
	mov	ax,cfgTxStartThresh	; n*4byte FIFO occupied
	add	dx,TxStartThresh
	out	dx,ax

	add	dx,(DMACtrl - TxStartThresh)
	in	eax,dx
	and	eax,not TxBurstLimit	; clear (use default)
	or	eax,(5 shl 20)		; TxBurstLimit 5
	out	dx,eax

	add	dx,(TFDListPtrHi - DMACtrl)
	xor	eax,eax
	out	dx,eax
	mov	bx,[TxHead]
	add	dx,(TFDListPtr - TFDListPtrHi)
	or	bx,bx
	jz	short loc_1
	mov	eax,[bx].TFD.PhysAddr
loc_1:
	out	dx,eax
	mov	[TxPendCount],8		; reset loop count
	retn
_InitTx		endp

_InitRx		proc	near
	mov	dx,IOaddr
	mov	ax,cfgRxEarlyThresh	; n*8byte rx frame
	add	dx,RxEarlyThresh
	out	dx,ax

	add	dx,(DMACtrl - RxEarlyThresh)
	in	eax,dx
	or	eax,RxEarlyDisable
	out	dx,eax

	add	dx,(RFDListPtrHi - DMACtrl)
	xor	eax,eax
	out	dx,eax
	mov	bx,[RxHead]
	add	dx,(RFDListPtr - RFDListPtrHi)
	or	bx,bx
	jz	short loc_1
	mov	eax,[bx].RFD.PhysAddr
loc_1:
	out	dx,eax
	retn
_InitRx		endp

_SetTxEnv	proc	near
	mov	dx,IOaddr
	mov	al,cfgTxBurstThresh	; n*32bytes FIFO free
	add	dx,TxDMABurstThresh
	out	dx,al
	mov	al,cfgTxUrgentThresh	; n*32byte FIFO occupied
	add	dx,(TxDMAUrgentThresh - TxDMABurstThresh)
	out	dx,al
	mov	al,cfgTxPollPeriod	; n*320ns interval
	add	dx,(TxDMAPollPeriod - TxDMAUrgentThresh)
	out	dx,al
	mov	eax,CountdownSpeed or CountdownMode
	add	dx,(Countdown - TxDMAPollPeriod)
	mov	ax,cfgTxIntDelay	; n*320ns delay
	out	dx,eax
	retn
_SetTxEnv	endp

_SetRxEnv	proc	near
	mov	dx,IOaddr
	mov	al,cfgRxBurstThresh	; n*32byte FIFO occupied
	add	dx,RxDMABurstThresh
	out	dx,al
	mov	al,cfgRxUrgentThresh	; n*32byte FIFO free
	add	dx,(RxDMAUrgentThresh - RxDMABurstThresh)
	out	dx,al
	mov	al,cfgRxPollPeriod	; n*320ns interval
	add	dx,(RxDMAPollPeriod - RxDMAUrgentThresh)
	out	dx,al
	mov	ax,cfgRxIntDelay	; n*64ns delay
	add	dx,(RxDMAIntCtrl - RxDMAPollPeriod)
	shl	eax,16
;	mov	ax,1			; frame count
	mov	al,cfgRxIntCount
	out	dx,eax
	mov	ax,cfgMAXFRAMESIZE	; 14bit
	add	dx,(MaxFrameSize - RxDMAIntCtrl)
	out	dx,ax

	push	offset semFlt
	call	_EnterCrit
	mov	dx,IOaddr
	mov	eax,dword ptr regHashTable
	add	dx,HashTable
	out	dx,eax
	mov	eax,dword ptr regHashTable[4]
	add	dx,(HashTableHi - HashTable)
	out	dx,eax
	mov	ax,regReceiveMode
	add	dx,(ReceiveMode - HashTableHi)
	out	dx,ax
	call	_LeaveCrit
	pop	ax
	retn
_SetRxEnv	endp

_SetPauseEnv	proc	near
	mov	dx,IOaddr
	mov	ax,cfgFlowOffThresh	; n*16byte occupied (len 0)
	add	dx,FlowOffThresh
	out	dx,ax
	mov	ax,cfgFlowOnThresh	; n*16byte occupied (len ffff)
	add	dx,(FlowOnThresh - FlowOffThresh)
	out	dx,ax
	retn
_SetPauseEnv	endp

_ResetRxDMA	proc	near
	call	_StopRxDMA
	mov	dx,IOaddr
	add	dx,AsicCtrl
	in	eax,dx
	or	eax,RxReset or DMA
	out	dx,eax

	push	dx
	push	offset semRx
	call	_EnterCrit
	mov	bx,[RxHead]
	mov	ax,[RxTail]
	xor	cx,cx
;	or	bx,bx
	cmp	bx,ax
	jz	short loc_2
loc_1:
	mov	[bx].RFD.RFS.RxFrameLen,cx
	mov	[bx].RFD.RFS.RFSflags,cx
	mov	bx,[bx].RFD.vlink
;	or	bx,bx
	cmp	bx,ax
	jnz	short loc_1
loc_2:
	call	_LeaveCrit
	pop	bx
	pop	dx
loc_3:
	in	eax,dx
	test	eax,ResetBusy
	jnz	short loc_3

	call	_InitRx
	mov	dx,IOaddr
	mov	ax,RxEnable
	add	dx,MACCtrl +2
	out	dx,ax
	retn
_ResetRxDMA	endp

_StopRxDMA	proc	near
	mov	dx,IOaddr
	mov	ax,highword(RxDisable)
	add	dx,MACCtrl +2
	out	dx,ax
	add	dx,(FIFOCtrl - MACCtrl -2)
	mov	cx,128
loc_1:
	in	ax,dx
	and	ax,Receiving
	jz	short loc_2
	dec	cx
	jnz	short loc_1
loc_2:
	shr	ax,15
	xor	al,1
	retn
_StopRxDMA	endp

_StopTxDMA	proc	near
	mov	dx,IOaddr
	mov	ax,highword(TxDisable)
	add	dx,MACCtrl +2
	out	dx,ax
	add	dx,(FIFOCtrl - MACCtrl -2)
	mov	cx,128
loc_1:
	in	ax,dx
	test	ax,Transmiting
	jz	short loc_2
	dec	cx
	jnz	short loc_1
loc_2:
	shr	ax,14
	xor	al,1
	retn
_StopTxDMA	endp


_SetStatMask	proc	near
	mov	dx,IOaddr
	mov	eax,RStatAllMask
	add	dx,RMONStatisticsMask
	out	dx,eax
	mov	eax,StatAllMask and not ( StatRxOctFrmOK or \
	  StatRxMcOctFrmOK or StatRxBcOctFrmOK or \
	  StatTxOctFrmOK or StatTxMcOctFrmOK or StatTxBcOctFrmOK )
	add	dx,(StatisticsMask - RMONStatisticsMask)
	out	dx,eax
	retn
_SetStatMask	endp


_ChkLink	proc	near
	push	miiBMSR
	push	[PhyInfo.Phyaddr]
	call	_miiRead
	and	ax,miiBMSR_LinkStat
	add	sp,2*2
	shr	ax,2
	retn
_ChkLink	endp


_AutoNegotiate	proc	near
	enter	2,0
	push	0
	push	miiBMCR
	push	[PhyInfo.Phyaddr]
	call	_miiWrite		; clear ANEnable bit
	add	sp,3*2

	call	_Delay1ms
	push	miiBMCR_ANEnable or miiBMCR_RestartAN
	push	miiBMCR
	push	[PhyInfo.Phyaddr]
	call	_miiWrite		; restart Auto-Negotiation
	add	sp,3*2

	mov	word ptr [bp-2],12*30	; about 12sec.
loc_1:
	call	_Delay1ms
	push	miiBMCR
	push	[PhyInfo.Phyaddr]
	call	_miiRead
	add	sp,2*2
	test	ax,miiBMCR_RestartAN	; AN in progress?
	jz	short loc_2
	dec	word ptr [bp-2]
	jnz	short loc_1
	jmp	short loc_f
loc_2:
	call	_Delay1ms
	push	miiBMSR
	push	[PhyInfo.Phyaddr]
	call	_miiRead
	add	sp,2*2
	test	ax,miiBMSR_ANComp	; AN Base Page exchange complete?
	jnz	short loc_3
	dec	word ptr [bp-2]
	jnz	short loc_2
	jmp	short loc_f
loc_3:
	call	_Delay1ms
	push	miiBMSR
	push	[PhyInfo.Phyaddr]
	call	_miiRead
	add	sp,2*2
	test	ax,miiBMSR_LinkStat	; link establish?
	jnz	short loc_4
	dec	word ptr [bp-2]
	jnz	short loc_3
loc_f:
	xor	ax,ax			; AN failure.
	xor	dx,dx
	leave
	retn
loc_4:
	call	_GetPhyMode
	leave
	retn
_AutoNegotiate	endp

_GetPhyMode	proc	near
	push	miiANLPAR
	push	[PhyInfo.Phyaddr]
	call	_miiRead		; read base page
	add	sp,2*2
	mov	[PhyInfo.ANLPAR],ax

	test	[PhyInfo.BMSR],miiBMSR_ExtStat
	jz	short loc_2

	push	mii1KSTSR
	push	[PhyInfo.Phyaddr]
	call	_miiRead
	add	sp,2*2
	mov	[PhyInfo.GSTSR],ax
	shr	ax,2
	and	ax,[PhyInfo.GTCR]
	test	ax,mii1KTCR_1KTFD
	jz	short loc_1
	mov	al,3			; media speed - 1000Mb
	mov	ah,1			; media duplex - full
	jmp	short loc_p
loc_1:
	test	ax,mii1KTCR_1KTHD
	jz	short loc_2
	mov	al,3			; 1000Mb
	mov	ah,0			; half duplex
	jmp	short loc_p
loc_2:
	mov	ax,[PhyInfo.ANAR]
	and	ax,[PhyInfo.ANLPAR]
	test	ax,miiAN_100FD
	jz	short loc_3
	mov	al,2			; 100Mb
	mov	ah,1			; full duplex
	jmp	short loc_p
loc_3:
	test	ax,miiAN_100HD
	jz	short loc_4
	mov	al,2			; 100Mb
	mov	ah,0			; half duplex
	jmp	short loc_p
loc_4:
	test	ax,miiAN_10FD
	jz	short loc_5
	mov	al,1			; 10Mb
	mov	ah,1			; full duplex
	jmp	short loc_p
loc_5:
	test	ax,miiAN_10HD
	jz	short loc_e
	mov	al,1			; 10Mb
	mov	ah,0			; half duplex
	jmp	short loc_p
loc_e:
	xor	ax,ax
	sub	dx,dx
	retn
loc_p:
	cmp	ah,1			; full duplex?
	mov	dh,0
	jnz	short loc_np
	mov	cx,[PhyInfo.ANLPAR]
	test	cx,miiAN_PAUSE		; symmetry
	mov	dl,3			; tx/rx pause
	jnz	short loc_ex
	test	cx,miiAN_ASYPAUSE	; asymmetry
	mov	dl,2			; rx pause
	jnz	short loc_ex
loc_np:
	mov	dl,0			; no pause
loc_ex:
	retn
_GetPhyMode	endp


_ResetPhy	proc	near
	enter	2,0
	call	_miiReset	; Reset Interface

	call	_SearchMedium
	cmp	ax,20h
	jc	short loc_2
loc_1:
	mov	ax,HARDWARE_FAILURE
	leave
	retn

loc_2:
	mov	[PhyInfo.Phyaddr],ax
	push	miiBMCR_Reset
	push	miiBMCR
	push	[PhyInfo.Phyaddr]
	call	_miiWrite	; Reset PHY
	add	sp,3*2
	mov	word ptr [bp-2],64
loc_3:
	push	miiBMCR
	push	[PhyInfo.Phyaddr]
	call	_miiRead
	add	sp,2*2
	test	ax,miiBMCR_Reset
	jz	short loc_4
	mov	cx,offset DosIODelayCnt
	loop	short $
	dec	word ptr [bp-2]
	jnz	short loc_3
	jmp	short loc_1	; PHY Reset Failure
loc_4:
	push	miiBMSR
	push	[PhyInfo.Phyaddr]
	call	_miiRead
	add	sp,2*2
	mov	[PhyInfo.BMSR],ax
	push	miiANAR
	push	[PhyInfo.Phyaddr]
	call	_miiRead
	add	sp,2*2
	mov	[PhyInfo.ANAR],ax
	test	[PhyInfo.BMSR],miiBMSR_ExtStat
	jz	short loc_5	; extended status exist?
	push	mii1KTCR
	push	[PhyInfo.Phyaddr]
	call	_miiRead
	add	sp,2*2
	mov	[PhyInfo.GTCR],ax
	push	mii1KSCR
	push	[PhyInfo.Phyaddr]
	call	_miiRead
	add	sp,2*2
	mov	[PhyInfo.GSCR],ax
	xor	cx,cx
;	test	ax,mii1KSCR_1KXFD or mii1KSCR_1KXHD
;	setnz	[MediaType]		; GMII/MII or TBI
	test	ax,mii1KSCR_1KTFD or mii1KSCR_1KXFD
	jz	short loc_41
	or	cx,mii1KTCR_1KTFD
loc_41:
	test	ax,mii1KSCR_1KTHD or mii1KSCR_1KXHD
	jz	short loc_42
	or	cx,mii1KTCR_1KTHD
loc_42:
	mov	ax,[PhyInfo.GTCR]
	and	ax,not (mii1KTCR_MSE or mii1KTCR_Port or \
		  mii1KTCR_1KTFD or mii1KTCR_1KTHD)
	or	ax,cx
	mov	[PhyInfo.GTCR],ax
	push	ax
	push	mii1KTCR
	push	[PhyInfo.Phyaddr]
	call	_miiWrite
	add	sp,2*2
loc_5:
	mov	ax,[PhyInfo.BMSR]
	mov	cx,miiAN_PAUSE
	test	ax,miiBMSR_100FD
	jz	short loc_61
	or	cx,miiAN_100FD
loc_61:
	test	ax,miiBMSR_100HD
	jz	short loc_62
	or	cx,miiAN_100HD
loc_62:
	test	ax,miiBMSR_10FD
	jz	short loc_63
	or	cx,miiAN_10FD
loc_63:
	test	ax,miiBMSR_10HD
	jz	short loc_64
	or	cx,miiAN_10HD
loc_64:
	mov	ax,[PhyInfo.ANAR]
	and	ax,not (miiAN_ASYPAUSE + miiAN_T4 + \
	  miiAN_100FD + miiAN_100HD + miiAN_10FD + miiAN_10HD)
	or	ax,cx
	mov	[PhyInfo.ANAR],ax
	push	ax
	push	miiANAR
	push	[PhyInfo.Phyaddr]
	call	_miiWrite
	add	sp,3*2
	mov	ax,SUCCESS
	leave
	retn

_SearchMedium	proc	near
	push	miiPHYID2
	push	0		; phyaddr [0..1f]
loc_1:
	call	_miiRead
	or	ax,ax		; ID2 = 0
	jz	short loc_next
	inc	ax		; ID2 = -1
	jnz	short loc_found
loc_next:
	pop	ax
	inc	ax		; next phyaddr
	cmp	al,20h
	push	ax
	jc	short loc_1
loc_found:
	pop	ax		; phyaddr checked
	pop	cx	; stack adjust
	retn
_SearchMedium	endp

_ResetPhy	endp


_hwUpdateMulticast	proc	near
	enter	2,0
	push	offset semFlt
	call	_EnterCrit
	mov	cx,MCSTList.curnum
	xor	eax,eax
	mov	dword ptr [regHashTable],eax
	mov	dword ptr [regHashTable][4],eax
	dec	cx
	jl	short loc_2
	mov	[bp-2],cx
loc_1:
	mov	ax,[bp-2]
	shl	ax,4		; 16bytes
	add	ax,offset MCSTList.multicastaddr1
	push	ax
	call	_CRC32
	pop	dx
	and	ax,3fh		; least 6bits
	mov	bx,ax
	and	ax,0fh
	shr	bx,4
	add	bx,bx
	bts	word ptr regHashTable[bx],ax
	dec	word ptr [bp-2]
	jge	short loc_1
loc_2:
	mov	dx,IOaddr
	add	dx,HashTable
	mov	eax,dword ptr regHashTable
	out	dx,eax
	add	dx,4
	mov	eax,dword ptr regHashTable[4]
	out	dx,eax
	call	_LeaveCrit
	pop	dx
	mov	ax,SUCCESS
	leave
	retn
_hwUpdateMulticast	endp

_CRC32		proc	near
POLYNOMIAL_be   equ  04C11DB7h
POLYNOMIAL_le   equ 0EDB88320h

	push	bp
	mov	bp,sp

	push	si
	push	di
	or	ax,-1
	mov	bx,[bp+4]
	mov	ch,3
	cwd

loc_1:
	mov	bp,[bx]
	mov	cl,10h
	inc	bx
loc_2:
IF 1
		; big endian

	ror	bp,1
	mov	si,dx
	xor	si,bp
	shl	ax,1
	rcl	dx,1
	sar	si,15
	mov	di,si
	and	si,highword POLYNOMIAL_be
	and	di,lowword POLYNOMIAL_be
ELSE
		; litte endian
	mov	si,ax
	ror	bp,1
	ror	si,1
	shr	dx,1
	rcr	ax,1
	xor	si,bp
	sar	si,15
	mov	di,si
	and	si,highword POLYNOMIAL_le
	and	di,lowword POLYNOMIAL_le
ENDIF
	xor	dx,si
	xor	ax,di
	dec	cl
	jnz	short loc_2
	inc	bx
	dec	ch
	jnz	short loc_1
	push	dx
	push	ax
	pop	eax
	pop	di
	pop	si
	pop	bp
	retn
_CRC32		endp


_hwUpdatePktFlt	proc	near
	push	offset semFlt
	call	_EnterCrit
	mov	cx,MacStatus.sstRxFilter
	xor	ax,ax
	mov	dx,IOaddr
	test	cl,mask fltdirect
	jz	short loc_1
	or	ax,ReceiveUnicast or ReceiveMulticastHash
loc_1:
	test	cl,mask fltbroad
	jz	short loc_2
	or	ax,ReceiveBroadcast
loc_2:
	test	cl,mask fltprms
	jz	short loc_3
	or	ax,ReceiveAllFrames
loc_3:
	add	dx,ReceiveMode
	mov	regReceiveMode,ax
	out	dx,ax
	call	_LeaveCrit
	pop	dx
	mov	ax,SUCCESS
	retn
_hwUpdatePktFlt	endp

_hwSetMACaddr	proc	near
	push	offset semFlt
	call	_EnterCrit
	mov	dx,IOaddr
	mov	eax,dword ptr MacChar.mctcsa
	mov	cx,word ptr MacChar.mctcsa[4]
	or	eax,eax
	jnz	short loc_1
	or	cx,cx
	jnz	short loc_1
	mov	eax,dword ptr MacChar.mctpsa
	mov	cx,word ptr MacChar.mctpsa[4]
	mov	dword ptr MacChar.mctcsa,eax
	mov	word ptr MacChar.mctcsa[4],cx
loc_1:
	add	dx,StationAddress
	out	dx,eax
	mov	ax,cx
	add	dx,4
	out	dx,ax
	call	_LeaveCrit
	pop	dx
	mov	ax,SUCCESS
	retn
_hwSetMACaddr	endp

_hwUpdateStat	proc	near
	push	bp
	push	si
	push	di
	push	offset semStat
	call	_EnterCrit

	mov	es,[MEMSel]
	mov	di,OctetRcvOk
	mov	si,offset MacStatus
	xor	ebx,ebx
	mov	eax,es:[di]
	mov	ecx,es:[di][FramesRcvdOk - OctetRcvOk]
	mov	edx,es:[di][McstFramesRcvdOk - OctetRcvOk]
	mov	bx, es:[di][BcstFramesRcvdOk - OctetRcvOk]
	add	[si].mst.rxframe,ecx
	add	[si].mst.rxbyte,eax
	add	[si].mst.rxframemulti,edx
	add	[si].mst.rxframebroad,ebx
	mov	di,FrameTooLongErrors
	xor	bp,bp
	mov	ax,es:[di]
	mov	cx,es:[di][InRangeLengthErrors - FrameTooLongErrors]
	mov	dx,es:[di][FramesCheckSeqErrors - FrameTooLongErrors]
	mov	bx,es:[di][FramesLostRxErrors - FrameTooLongErrors]
	add	word ptr [si].mst.rxframecrc,dx
	adc	word ptr [si].mst.rxframecrc[2],bp
	add	word ptr [si].mst.rxframebuf,ax
	adc	word ptr [si].mst.rxframebuf[2],bp
	add	word ptr [si].mst.rxframebuf,cx
	adc	word ptr [si].mst.rxframebuf[2],bp
	add	dword ptr [si].mst.rxframehw,ebx
	mov	di,OctetXmtOk
	mov	eax,es:[di]
	mov	ecx,es:[di][FramesXmtdOk - OctetXmtOk]
	mov	edx,es:[di][McstFramesXmtdOk - OctetXmtOk]
	mov	bx ,es:[di][BcstFramesXmtdOk - OctetXmtOk]
	add	[si].mst.txframe,ecx
	add	[si].mst.txbyte,eax
	add	[si].mst.txframemulti,edx
	add	[si].mst.txframebroad,ebx
	mov	di,FramesAbortXSColls
	mov	ax,es:[si]
	mov	bx,es:[si][FramesWEXDeferal - FramesAbortXSColls]
	add	word ptr [si].mst.txframehw,ax
	adc	word ptr [si].mst.txframehw[2],bp
	add	[si].mst.txframeto,ebx
	call	_hwClearStat
	call	_LeaveCrit
	pop	bp	; stack adjust
	pop	di
	pop	si
	pop	bp
	retn
_hwUpdateStat	endp

_hwClearStat	proc	near
	push	di
	mov	es,MEMSel
	xor	eax,eax
	mov	di,OctetRcvOk
	mov	cx,(14ch - 0a8h)/4
	rep	stosd
	pop	di
	retn
_hwClearStat	endp

_SetSpeedStat	proc	near
	mov	al,MediaSpeed
	mov	ah,0
	dec	ax
	jz	short loc_10M
	dec	ax
	jz	short loc_100M
	dec	ax
	jz	short loc_1G
	xor	eax,eax
	jmp	short loc_1
loc_10M:
	mov	eax,10000000
	jmp	short loc_1
loc_100M:
	mov	eax,100000000
	jmp	short loc_1
loc_1G:
	mov	eax,1000000000
loc_1:
	mov	[MacChar.linkspeed],eax
	retn
_SetSpeedStat	endp


_hwClose	proc	near
	push	offset semTx
	call	_EnterCrit
	push	offset semRx
	call	_EnterCrit

	mov	dx,IOaddr
	xor	ax,ax
	add	dx,IntEnable
	mov	regIntMask,ax
	out	dx,ax
	add	dx,(MACCtrl - IntEnable)
	in	eax,dx
	or	eax,StatisticsDisable or TxDisable or RxDisable
	out	dx,eax
	xor	eax,eax
	add	dx,(TFDListPtr - MACCtrl)
	out	dx,eax
	add	dx,(RFDListPtr - TFDListPtr)
	out	dx,eax
	add	dx,(Countdown - RFDListPtr)
	out	dx,eax

	call	_LeaveCrit
	pop	dx
	call	_LeaveCrit
	pop	dx

	mov	ax,SUCCESS
	retn
_hwClose	endp

_hwReset	proc	near	; call in bind process
	enter	6,0
	mov	dx,IOaddr
	add	dx,AsicCtrl
	mov	eax,GlobalReset or DMA or FIFO or Network or \
		  Host or AutoInit
	out	dx,eax		; Global reset with AutoInit
	mov	bx,20480	; about 1 second wait
loc_1:
	mov	cx,offset DosIODelayCnt
	loop	short $
	in	eax,dx
	test	eax,ResetBusy
	jz	short loc_2
	dec	bx
	jnz	short loc_1
	mov	ax,HARDWARE_FAILURE
	leave
	retn
loc_2:
	add	dx,(DMACtrl - AsicCtrl)
	in	eax,dx
	and	eax,not MWIDisable
	cmp	[stsMWI],0	; Cache Line size valid?
	jnz	short loc_3
	or	eax,MWIDisable
loc_3:
	out	dx,eax

	add	dx,(WakeEvent - DMACtrl)
	in	al,dx
	mov	al,0
	out	dx,al		; kill Wake on Lan

	add	dx,(DebugCtrl - WakeEvent)
	mov	ax,dbDisableDnHalt or dbDisableUpHalt or dbFrCurDoneAck
	out	dx,ax		; bug work-around?? IMPORTANT SPELL

	push	eepStationAddress
	call	_eepRead
	mov	[bp-6],ax
	push	eepStationAddress +1
	call	_eepRead
	mov	[bp-4],ax
	push	eepStationAddress +2
	call	_eepRead
	mov	[bp-2],ax
	add	sp,3*2
	push	offset semFlt
	call	_EnterCrit
	mov	ax,[bp-6]
	mov	cx,[bp-4]
	mov	dx,[bp-2]
	mov	word ptr MacChar.mctpsa,ax	; parmanent
	mov	word ptr MacChar.mctpsa[2],cx
	mov	word ptr MacChar.mctpsa[4],dx
;	mov	word ptr MacChar.mctcsa,ax	; current
;	mov	word ptr MacChar.mctcsa[2],cx
;	mov	word ptr MacChar.mctcsa[4],dx
	mov	word ptr MacChar.mctVendorCode,ax ; vendor
	mov	byte ptr MacChar.mctVendorCode,cl
	call	_LeaveCrit
	add	sp,2
	call	_hwSetMACaddr		; update station address
	mov	ax,SUCCESS
	leave
	retn
_hwReset	endp


; USHORT miiRead( UCHAR phyaddr, UCHAR phyreg)
_miiRead	proc	near
	enter	2,0
	push	offset semMii
	call	_EnterCrit
	mov	dx,IOaddr
	add	dx,PhyCtrl
	in	al,dx
	and	al,(PhyDuplexPolarity or PhyLnkPolarity)
	mov	[bp-2],al	; backup current status
;	push	8
	push	1

	mov	al,MgmtData or MgmtDir
	out	dx,al
	call	__IODelayCnt
	or	al,MgmtClk
	out	dx,al		; idle
	call	__IODelayCnt

	mov	al,[bp+4]	; physaddr (5bit)
	mov	cl,[bp+6]	; phyreg   (5bit)
	mov	bx,0110b	; start(01) + opcode(10)
	shl	ax,5
	and	cl,1fh
	shl	bx,10
	and	ax,3E0h
	or	bl,cl
	or	bx,ax
	mov	cx,13

loc_1:
	mov	al,0
	bt	bx,cx
	rcl	al,2
	or	al,MgmtDir
	out	dx,al
	call	__IODelayCnt
	or	al,MgmtClk
	out	dx,al
	call	__IODelayCnt
	dec	cx
	jge	short loc_1

;	mov	al,0		; TA (z0)
;	out	dx,al
;	mov	al,MgmtClk
;	out	dx,al
	mov	al,0
	out	dx,al
	call	__IODelayCnt
	mov	al,MgmtClk
	out	dx,al
	call	__IODelayCnt

	mov	cx,16
loc_2:
	mov	al,0
	out	dx,al
	call	__IODelayCnt
	mov	al,MgmtClk
	out	dx,al
	call	__IODelayCnt
	in	al,dx
	bt	ax,1		; MgmtData
	rcl	bx,1
	dec	cx
	jnz	short loc_2

	mov	al,0
	out	dx,al
	call	__IODelayCnt
	mov	al,MgmtClk
	out	dx,al		; idle
	call	__IODelayCnt
	mov	ax,[bp-2]
	mov	[bp-2],bx
	out	dx,al		; restore previous status
	pop	cx	; stack adjust
	call	_LeaveCrit
	mov	ax,[bp-2]
	leave
	retn
_miiRead	endp

; VOID miiWrite( UCHAR phyaddr, UCHAR phyreg, USHORT value)
_miiWrite	proc	near
	enter	2,0
	push	offset semMii
	call	_EnterCrit
	mov	dx,IOaddr
	add	dx,PhyCtrl
	in	al,dx
	and	al,(PhyDuplexPolarity or PhyLnkPolarity)
	mov	[bp-2],al	; backup current status
;	push	8
	push	1

	mov	al,MgmtData or MgmtDir
	out	dx,al
	call	__IODelayCnt
	or	al,MgmtClk
	out	dx,al		; idle
	call	__IODelayCnt

	mov	al,[bp+4]	; physaddr (5bit)
	mov	cl,[bp+6]	; phyreg   (5bit)
	mov	bx,0101b	; start(01) + opcode(01)
	shl	ax,5
	and	cl,1fh
	shl	bx,10
	and	ax,3E0h
	or	bl,cl
	or	bx,ax
	mov	cx,13

loc_1:
	mov	al,0
	bt	bx,cx
	rcl	al,2
	or	al,MgmtDir
	out	dx,al
	call	__IODelayCnt
	or	al,MgmtClk
	out	dx,al
	call	__IODelayCnt
	dec	cx
	jge	short loc_1

	mov	al,MgmtData or MgmtDir	; TA (10)
	out	dx,al
	call	__IODelayCnt
	or	al,MgmtClk
	out	dx,al
	call	__IODelayCnt
	mov	al,MgmtDir
	out	dx,al
	call	__IODelayCnt
	or	al,MgmtClk
	out	dx,al
	call	__IODelayCnt

	mov	bx,[bp+8]
	mov	cx,15
loc_2:
	bt	bx,cx
	mov	al,0
	rcl	al,2
	or	al,MgmtDir
	out	dx,al
	call	__IODelayCnt
	or	al,MgmtClk
	out	dx,al
	call	__IODelayCnt
	dec	cx
	jge	short loc_2

	mov	al,MgmtData or MgmtDir
	out	dx,al
	call	__IODelayCnt
	or	al,MgmtClk
	out	dx,al		; idle
	call	__IODelayCnt
	mov	al,[bp-2]
	out	dx,al		; restore previous status
	pop	cx	; stack adjust
	call	_LeaveCrit
	leave
	retn
_miiWrite	endp

; VOID miiReset( VOID )
_miiReset	proc	near
	push	offset semMii
	call	_EnterCrit
	mov	dx,IOaddr
	add	dx,PhyCtrl
	in	al,dx
	mov	ah,al
	mov	cx,32		; 32clock high
	and	ah,(PhyDuplexPolarity or PhyLnkPolarity)
;	push	8
	push	1
loc_1:
	mov	al,MgmtData or MgmtDir
	out	dx,al
	call	__IODelayCnt
	or	al,MgmtClk
	out	dx,al
	call	__IODelayCnt
	dec	cx
	jnz	short loc_1
	pop	cx	; stack adjust
	mov	al,ah
	out	dx,al
	call	_LeaveCrit
	pop	ax
	retn
_miiReset	endp

IF 0
; VOID _DelayShort( UCHAR count)
__DelayShort	proc	near
	push	bp
	mov	bp,sp
	push	dx
	push	ax
	mov	dx,[IOaddr]
	mov	bp,[bp+4]
	add	dx,WakeEvent
loc_1:
	dec	bp
	in	al,dx
	jnz	short loc_1
	pop	ax
	pop	dx
	pop	bp
	retn
__DelayShort	endp
ENDIF

; void _IODelayCnt( USHORT count )
__IODelayCnt	proc	near
	push	bp
	mov	bp,sp
	push	cx
	mov	bp,[bp+4]
loc_1:
	mov	cx,offset DosIODelayCnt
	dec	bp
	loop	$
	jnz	short loc_1
	pop	cx
	pop	bp
	retn
__IODelayCnt	endp

; USHORT eepRead( UCHAR addr )
_eepRead	proc	near
	push	bp
	mov	bp,sp
	mov	dx,IOaddr
	add	dx,EepromCtrl
loc_1:
	in	ax,dx
	shl	ax,1
	jc	short loc_1	; busy
	mov	al,[bp+4]
	mov	ah,2		; opcode Read
	and	al,3fh		; write disable
	out	dx,ax
loc_2:
	mov	ax,32
loc_3:
	mov	cx,DosIODelayCnt
	loop	$
	dec	ax
	jnz	short loc_3
	in	ax,dx
	shl	ax,1
	jc	short loc_2	; busy
	add	dx,(EepromData - EepromCtrl)
	in	ax,dx
	pop	bp
	retn
_eepRead	endp

_TEXT	ends
end
