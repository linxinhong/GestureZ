; 初始化 {{{1
If FileExist(A_ScriptDir "\GestureZ.exe")
Menu,Tray,Icon,%A_ScriptDir%\GestureZ.exe,1
#SingleInstance Force
#Include %A_ScriptDir%\Lib\Gdip.ahk
#Include %A_ScriptDir%\Lib\INI.ahk
#Include %A_ScriptDir%\Lib\SCI.ahk
#Include %A_ScriptDir%\Lib\Include.ahk
Critical
appINI := new INI(A_ScriptDir "\Config\Application.ini")
actINI := new INI(A_ScriptDir "\Config\Action.ini")
gebINI := new INI(A_ScriptDir "\Config\GestureBasic.ini")
gesINI := new INI(A_ScriptDir "\Config\GestureUser.ini")
cmdINI := new INI(A_ScriptDir "\Config\Command.ini")
configINI := new INI(A_ScriptDir "\Config\Config.ini")
Language := new INI(A_ScriptDir "\Config\Language.ini")
AhkThread := AhkDllThread(A_Scriptdir "\lib\Autohotkey.dll")
SCI  := new scintilla
Lang := "zh-cn"

; 优先级最高
denyDB   := []
; 优先级第二
gzDB     := []
; 优先级第三
permitDB := []
; 保存排错信息
debugDB  := []

Menu,Tray,Click,1
Menu,Tray,Add,% Language.GetValue(Lang,"Editor"),GestureConfigShow
Menu,Tray,Default,% Language.GetValue(Lang,"Editor")

Gui,GZRead:Add,Text,,_GestureZ
GUI,GZRead:Add,Edit,gGZRead

; 加载配置
gz_Load()
; 初始化配置界面
GoSub,LoadCUR
GoSub,GestureConfig
Critical,off

return

GZRead:
	GUI,GZRead:Default
	GuiControlGet,Text,,Edit1
	SCI.InsertText(SCI.GetCurrentPos(),&Text)
  SCI.SetCurrentPos(SCI.GetCurrentPos()+GetStringLen(Text))
return


; 热键定义 {{{1
RButton::
	LastGesture := MG_Recognize()	
	;GZ_RecoginzeInit()
return

f1::
	GZ_DebugShow()
return

; 主函数 {{{1
; GZ_Load() {{{2
; 加载配置
GZ_Load(){
	Global AppINI,ActINI,gzDB,denyDB,permitDB
	gzDB := []
	loadApp := "Global Permit`n" appINI.GetSections()
	Loop,Parse,LoadApp,`n,`r
	{
		If Not Strlen(A_LoopField)
			continue
		App := A_LoopField
		If Strlen(LoadIdent := appINI.GetKeys(App)){
			Loop,Parse,LoadIdent,`n,`r
			{
				If Not Strlen(A_LoopField)
					continue
				Ident := A_LoopField
				;加载到 DenyDB
				If RegExMatch(App,"i)^Global\sDeny$")
				{
					denyDB[appINI.GetValue(App,Ident) "`n" Ident] := true
					continue
				}
				act := ActINI.GetKeys(App)
				Loop,Parse,Act,`n,`r
				{
					If Not Strlen(A_LoopField)
						continue
					gzDB[appINI.GetValue(App,Ident) "`n" Ident "`n" A_LoopField] := App
				}
			}
		}
		Else
		{
			If RegExMatch(App,"i)^Global\sDeny$")
					continue
			; 这部分是什么功能呢？是加载Action.ini
			act := ActINI.GetKeys(App)
			Loop,Parse,act,`n,`r
			{
				If Not Strlen(A_LoopField)
					continue
				If RegExMatch(App,"i)^Global\spermit$")
					permitDB[A_LoopField] := App
				Else
					gzDB[A_LoopField] := App
			}
		}
	}
}
; GZ_ReadName(ges) {{{2
; 获取手势对应的手势名
GZ_ReadName(ges){
	Global gesINI,gebINI
	If not strlen(g := gesINI.GetValue("Gesture",ges))
	   g := gebINI.GetValue("Gesture",ges)
	return g
}
; GZ_WriteName(ges,name) {{{2
; 写入手势对应的手势名到识别库中
GZ_WriteName(ges,name){
	Global gesINI,gebINI
	gesINI.INIWrite("Gesture",ges,Name)
}
; GZ_ActionDo(id,ges) {{{2
GZ_ActionDo(id,ges){
	Global gzDB,permitDB,ActINI,AhkThread,gz_win
	WinGetClass,gClass,ahk_id %id%
	winGet,gfile,ProcessName,ahk_id %id%
	If Strlen(app := gzDB["class`n" gClass "`n" ges])
	{
		file := A_ScriptDir "\Config\Commands\" ActINI.GetValue(app,ges) ".ahk"
		GZ_Debug(Level := 1,app "`n" ges "`n" file)
	}
	Else If Strlen(app := gzDB["file`n" gfile "`n" ges])
	{
		file := A_ScriptDir "\Config\Commands\" ActINI.GetValue(app,ges) ".ahk"
		GZ_Debug(Level := 2,app "`n" ges "`n" file)
	}
	Else If Strlen(app := gzDB[ges])
	{
		file := A_ScriptDir "\Config\Commands\" ActINI.GetValue(app,ges) ".ahk"
		GZ_Debug(Level := 3,app "`n" ges "`n" file)
	}
	Else If Strlen(app := permitDB[ges])
	{
		file := A_ScriptDir "\Config\Commands\" ActINI.GetValue(app,ges) ".ahk"
		GZ_Debug(Level := 4,app "`n" ges "`n" file)
	}
	Else
		return
	If not FileExist(file)
	{
			Msgbox % file "`n" Lang("info Not Exist")
			return
	}
	AhkThread.ahktextdll()
	AhkThread.ahkAssign.winx := gz_win["x"]
	AhkThread.ahkAssign.winy := gz_win["y"]
	AhkThread.ahkAssign.winid := gz_win["id"]
	AhkThread.ahkAssign.winclass := gz_win["class"]
	AhkThread.ahkAssign.wincontrol := gz_win["control"]
	If !(pointerLine := AhkThread.addFile(file))
 		MsgBox, % Lang("info run error")
	AhkThread.ahkExecuteLine(pointerLine, 1, 0)
}
; GZ_Debug(Level,string) {{{2
GZ_Debug(Level,string){
	Global debugDB
	idx := (i := debugDB[0]) ? i++ : 1
	debugDB[idx] := Level "`n" string
	debugDB[0] := idx
}
; GZ_DebugShow() {{{2
GZ_DebugShow(){
	Global debugDB
	Loop, % debugDB[0]
		m .= debugDB[A_Index]
	msgbox % m
}
; MG_Recognize() {{{2
; 手势判断
MG_Recognize() {
	; Modify from [module] Mouse gestures
	; http://www.autohotkey.com/board/topic/52201-module-mouse-gestures/
	; Thanks Learning one
	Global LastGesturePos,LastGesture,hGUI,gz_win,configINI,denyDB
	Critical
	MGHotkey := RegExReplace(A_ThisHotkey,"^(\w* & |\W*)")
	gz_win := []
	LastGesture := ""
	LastGesturePos := []
	LastGesturePos[0] := 0
	CoordMode, mouse, Screen
	MouseGetPos, StartX , StartY, gz_win_id, gz_win_control
	WinGetClass,gz_win_class,ahk_id %gz_win_id%
	winGet,gz_win_file,ProcessName,ahk_id %gz_win_id%
; 判断DenyDB
	If denyDB["class`n" gz_win_class] or denyDB["file`n" gz_win_file]
	{
		SendInput, {%MGHotkey%}
		return
	}
	ControlGetFocus, gz_win_control ,ahk_id %gz_win_id% 
	gz_win["id"] := gz_win_id
	gz_win["control"] := gz_win_control
	gz_win["class"] := gz_win_class
	gz_win["x"] := startX
	gz_win["y"] := startY

	If (gz_win_id = hGUI)
	{
		SendInput, {%MGHotkey%}
		return 
	}
	If configINI.GetValue("config","draw")
	{
		If !pToken := Gdip_Startup()
			return
		Width := A_ScreenWidth , Height := A_ScreenHeight
		Gui, 1: -Caption +E0x80000 +LastFound +OwnDialogs +Owner +AlwaysOnTop
		Gui, 1: Show, NA
		hwnd1 := WinExist()
		hbm := CreateDIBSection(Width, Height)
		hdc := CreateCompatibleDC()
		obm := SelectObject(hdc, hbm)
		G := Gdip_GraphicsFromHDC(hdc)

		Gdip_SetSmoothingMode(G, 4)
		pPen := Gdip_CreatePen(ARGB_FromRGB(0xAA,configINI.GetValue("config","color")),3)
	}
	Loop
	{
		if !(GetKeyState(MGHotkey, "p")) or ( Timeout > 250 ) {
			If FileExist(A_ScriptDir "\GestureZ.exe")
			Menu,Tray,Icon,%A_ScriptDir%\GestureZ.exe,1
			If pToken And configINI.GetValue("config","draw")
			{
				Gdip_DeletePen(pPen)
				SelectObject(hdc, obm)
				DeleteObject(hbm)
				DeleteDC(hdc)
				Gdip_DeleteGraphics(G)
				Gdip_Shutdown(pToken)
				GUI,1:Destroy
				WinActive("ahk_id " gz_win_id)
			}
			Tooltip 
			If (TimeOut > 250){
				x1 := gz_win["x"]
				y1 := gz_win["y"]
				x2 := xx
				y2 := yy
				;MouseClickDrag,L,%x1%,%y1%,%x2%,%y2%
				key := SubStr(MGHotkey,1,1)
				SendEvent {click %x1%,%y1%,%key%,down}
				MouseMove ,%x2% ,%y2%,0
				Loop
				{
					if !(GetKeyState(MGHotkey, "p"))
					{
						SendEvent {click,%x2%,%y2%,%key%,up}
						return
					}
				}
			}
			Else If not RegExMatch(LastGesture,"\d"){
				SendInput, {%MGHotkey%}
				return
			}
			
			If ( ges := GZ_ReadName(LastGesture))
					GZ_ActionDo(gz_win_id,ges)
			Else
			{
					;If configINI.GetValue("config","autolearn")
					GestureLearn(LastGesture)
			}
			Return LastGesture
		}
		EndX_Old := EndX
		EndY_Old := EndY
		MouseGetPos, xx, yy
		If (xx == EndX) AND ( yy == EndY)
		{
				timeout := A_TickCount - Timestamp
				sleep,20
				continue
		}
		Else
			timeout := 0
		Timestamp := A_TickCount
		EndX := xx
		EndY := yy
		Radius := MG_GetRadius(StartX, StartY, EndX, EndY)
		MoveRadius := MG_GetRadius(EndX_Old, EndY_Old, EndX, EndY) 
		;Tooltip % Radius
		; 画笔
		If ( MoveRadius >= 1 ) And  configINI.GetValue("config","draw")
		{
			Gdip_DrawLine(G, pPen, EndX_Old, EndY_Old, EndX , EndY)
			MG_Review_Date(EndX_Old , EndY_Old, EndX, EndY)
		}
		If ( MoveRadius >= 3 )
		{
			If not init 
			{
				If FileExist(A_ScriptDir "\GestureZ.exe")
				Menu,Tray,Icon,%A_ScriptDir%\GestureZ.exe,7
				init := true
			}
			if configINI.GetValue("config","draw")
			UpdateLayeredWindow(hwnd1, hdc, 0, 0, Width, Height)
		}
	
		; 当移动半径超过10象素才进行角度判断
		If (Radius < 10)
		Continue
		Angle := MG_GetAngle(StartX, StartY, EndX, EndY)
		MouseGetPos, StartX, StartY

		CurMove := MG_GetMove(Angle)
		if !(CurMove = LastMove)
		{
			LastGesture .= CurMove
			if configINI.GetValue("config","tooltip")
				Tooltip % MG_Say(LastGesture)
			LastMove := CurMove
		}
	}
	Critical,off
}
; MG_Review() {{{2
; 重绘出最后一次的手势
MG_Review(){
	Global LastGesturePos,ReviewLock
	ReviewLock := True
	critical
	If !pToken := Gdip_Startup()
		return
	xmin := A_ScreenWidth
	ymin := A_ScreenHeight
	xmax := 0	
	ymax := 0	
	Loop,% LastGesturePos[0]
	{
		pos := LastGesturePos[A_Index]
		If Pos.x1 > xmax
			xmax := Pos.x1
		If Pos.x2 > xmax
			xmax := Pos.x2
		If Pos.x1 < xmin
			xmin := Pos.x1
		If Pos.x2 < xmin
			xmin := Pos.x2
		If Pos.y1 > ymax
			ymax := Pos.y1
		If Pos.y2 > ymax
			ymax := Pos.y2
		If Pos.y1 < ymin
			ymin := Pos.y1
		If Pos.y2 < ymin
			ymin := Pos.y2
	}
	Width := A_ScreenWidth , Height := A_ScreenHeight
	Gui, review: -Caption +E0x80000 +LastFound +OwnDialogs +Owner +AlwaysOnTop
	Gui, review: Show, NA
	hwnd1 := WinExist()
	hbm := CreateDIBSection(Width, Height)
	hdc := CreateCompatibleDC()
	obm := SelectObject(hdc, hbm)
	G := Gdip_GraphicsFromHDC(hdc)
	Gdip_SetSmoothingMode(G, 4)
	pBrush := Gdip_BrushCreateSolid(0xff112211)
	Gdip_FillRectangle(G, pBrush, xmin-12, ymin-12, xmax-xmin+24, ymax-ymin+24)
	pBrushWhite := Gdip_BrushCreateSolid(0xffffffff)
	Gdip_FillRectangle(G, pBrushWhite, xmin-10, ymin-10, xmax-xmin+20, ymax-ymin+20)
	UpdateLayeredWindow(hwnd1, hdc, 0, 0, Width, Height)
	pPen := Gdip_CreatePen(0xffff0000,3)
	Loop,% LastGesturePos[0]
	{
		Sleep,50
		pos := LastGesturePos[A_Index]
		Gdip_DrawLine(G, pPen,Pos.x1, Pos.y1, Pos.x2, Pos.y2)
		UpdateLayeredWindow(hwnd1, hdc, 0, 0, Width, Height)
	}
	Sleep,1400
	Gdip_DeleteBrush(pBrush)
	Gdip_DeleteBrush(pBrushWhite)
	Gdip_DeletePen(pPen)
	SelectObject(hdc, obm)
	DeleteObject(hbm)
	DeleteDC(hdc)
	Gdip_DeleteGraphics(G)
	Gdip_Shutdown(pToken)
	MG_Review_SaveImg()
	critical,off
	ReviewLock := False
	GUI,review:Destroy
}
reviewGuiEscape:
	If not ReviewLock
	GUI,review:Destroy
return
; MG_Review_SaveImg() {{{2
MG_Review_SaveImg(){
	Critical
	pFile := A_Temp "\GestureZ.png"
	pFileHtml := A_Temp "\GestureZ.html"
	Global LastGesturePos
	If !pToken := Gdip_Startup()
		return
	xmin := A_ScreenWidth
	ymin := A_ScreenHeight
	xmax := 0	
	ymax := 0	
	Loop,% LastGesturePos[0]
	{
		pos := LastGesturePos[A_Index]
		If Pos.x1 > xmax
			xmax := Pos.x1
		If Pos.x2 > xmax
			xmax := Pos.x2
		If Pos.x1 < xmin
			xmin := Pos.x1
		If Pos.x2 < xmin
			xmin := Pos.x2
		If Pos.y1 > ymax
			ymax := Pos.y1
		If Pos.y2 > ymax
			ymax := Pos.y2
		If Pos.y1 < ymin
			ymin := Pos.y1
		If Pos.y2 < ymin
			ymin := Pos.y2
	}
	pBitmap := Gdip_CreateBitmap(w:= xmax-xmin+20,h:=ymax-ymin+20)
	xmin -= 10
	ymin -= 10
	G2 := Gdip_GraphicsFromImage(pBitmap)
	Gdip_SetSmoothingMode(G2, 4)
	pBrushWhite := Gdip_BrushCreateSolid(0xffffffff)
	Gdip_FillRectangle(G2, pBrushWhite, 0, 0, w, h)
	Gdip_DeleteBrush(pBrushWhite)
	pPen := Gdip_CreatePen(0xffff0000,3)
	Loop,% LastGesturePos[0]
	{
		pos := LastGesturePos[A_Index]
		Gdip_DrawLine(G2, pPen,Pos.x1-xmin, Pos.y1-ymin, Pos.x2-xmin, Pos.y2-ymin)
		UpdateLayeredWindow(hwnd1, hdc, 0, 0, Width, Height)
	}
	Gdip_DeletePen(pPen)
	Gdip_SaveBitmapToFile(pBitmap, pfile)
	Gdip_DisposeImage(pBitmap)
	Gdip_DeleteGraphics(G2)
	Gdip_Shutdown(pToken)
	If FileExist(pFileHtml)
		FileDelete,%pFileHtml%
FileAppend,
(
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" 
"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html>
 <head>
  <title> 自学HTML+CSS </title>
  <style type="text/css">
    .test{
        margin:0 auto;
        display:block;
        }
  </style>
 </head>
 <body>
<img class="test" src="%pFile%"/>
 </body>
</html> 
),%pFileHtml%
	Critical,off
	return pFileHtml
}

; MG_Review_Date(x1,y1,x2,y2) {{{2
; 保存手势路径数据
MG_Review_Date(x1,y1,x2,y2){
	Global LastGesturePos
	Pos := []
	Pos.x1 := x1
	Pos.y1 := y1
	Pos.x2 := x2
	Pos.y2 := y2
	LastGesturePos[LastGesturePos[0]+1] := Pos
	LastGesturePos[0] += 1
}
; MG_Review_Save(name) {{{2
; 保存数据到INI
MG_Review_Save(name){
	Global LastGesturePos
	INIdelete,%A_ScriptDir%\Config\GestureView.ini,%name%
	Loop,% LastGesturePos[0]
	{
		pos := LastGesturePos[A_Index]
		save := Pos.x1 "," Pos.y1 "," Pos.x2 "," Pos.y2
		INIWrite,%save%,%A_ScriptDir%\Config\GestureView.ini,%name%,%A_Index%
	}
}
; MG_Review_Load(name) {{{2
MG_Review_Load(name){
	Global LastGesturePos
	INIRead,load,%A_SCRIPTDIR%\Config\GestureView.ini,%name%
	Loop,Parse,Load,`n,`r
	{
		If not Strlen(A_LoopField)
			continue
		Pos := []
		PosData := RegExReplace(A_LoopField,"^\d*=")
		Loop,Parse,PosData,`,
		{
			If A_Index = 1
				Pos.x1 := A_LoopField
			If A_Index = 2
				Pos.y1 := A_LoopField
			If A_Index = 3
				Pos.x2 := A_LoopField
			If A_Index = 4
				Pos.y2 := A_LoopField
		}
		idx := RegExReplace(A_LoopField,"=.*$")
		LastGesturePos[idx] := Pos
	}
	LastGesturePos[0] := idx
}

; MG_Say(Gestures) {{{2
; 转换为手势名，易于直观显示
MG_Say(Gestures){
	Gestures := RegExReplace(Gestures,"1","↑")
	Gestures := RegExReplace(Gestures,"2","↗")
	Gestures := RegExReplace(Gestures,"3","→")
	Gestures := RegExReplace(Gestures,"4","↘")
	Gestures := RegExReplace(Gestures,"5","↓")
	Gestures := RegExReplace(Gestures,"6","↙")
	Gestures := RegExReplace(Gestures,"7","←")
	Return Gestures := RegExReplace(Gestures,"8","↖")
}

; MG_GetMove(Angle) {{{2
; 根据角度获取方向
MG_GetMove(Angle) {
	If ( Angle > 337.5 ) OR ( Angle <= 22.5)
		return 1
	If ( Angle > 22.5 ) And ( Angle <= 67.5)
		return 2
	If ( Angle > 67.5 ) And ( Angle <= 112.5)
		return 3
	If ( Angle > 112.5 ) And ( Angle <= 157.5)
		return 4
	If ( Angle > 157.5 ) And ( Angle <= 202.5)
		return 5
	If ( Angle > 202.5 ) And ( Angle <= 247.5)
		return 6
	If ( Angle > 247.5 ) And ( Angle <= 292.5)
		return 7
	If ( Angle > 292.5 ) And ( Angle <= 337.5)
		return 8
}

; MG_GetAngle(StartX, StartY, EndX, EndY) {{{2
; 获取角度
MG_GetAngle(StartX, StartY, EndX, EndY) {
    x := EndX-StartX, y := EndY-StartY
    if x = 0
    {
        if y > 0
        return 180
        Else if y < 0
        return 360
        Else
        return
    }
    deg := ATan(y/x)*57.295779513
    if x > 0
    return deg + 90
    Else
    return deg + 270	
}
; MG_GetRadius(StartX, StartY, EndX, EndY) {{{2
; 获取半径
MG_GetRadius(StartX, StartY, EndX, EndY) {
	a := Abs(endX-startX), b := Abs(endY-startY), Radius := Sqrt(a*a+b*b)
    Return Radius    
}

; 界面 {{{1

; GestureConfig {{{2
GestureConfig:

	Menu,Config ,Add,% Lang("Menu Gestrue"),MenuBarGo
	Menu,Config ,Add,% Lang("Menu Option"),MenuBarGo
	Menu,Help   ,Add,% Lang("Menu Show Help"),MenuBarGo
	Menu,Help   ,Add,% Lang("Menu About"),MenuBarGo
	Menu,MenuBar,Add,% Lang("Menu Config"),:Config
	Menu,MenuBar,Add,% Lang("Menu Help"),:Help

If configINI.GetValue("config","tree colum viewer")
{
;=========================================================
; 三列界面

	GUI,GesConfig:Default
	GUI,GesConfig:+hwndhGUI +LastFound +Resize
	GUI,GesConfig:Font,s10 ,Microsoft YaHei
	GUI,GesConfig:Add,TreeView,x10  y10 w180 h450 gTreeViewCommand AltSubmit
	GUI,GesConfig:Add,Groupbox,x200 y10 w240 h240
	GUI,GesConfig:Add,ListBox ,x210 y32 w220 h140
	GUI,GesConfig:Add,Button,x210 y180 w100 h24 gGestureConfigFinder,% Language.GetValue(Lang,"Add") "(&A)"
	GUI,GesConfig:Add,Button,x330 y180 w100 h24 gGestureConfigAppEdit,% Language.GetValue(Lang,"Edit") 
	GUI,GesConfig:Add,Button,x210 y210 w100 h24 gGestureConfigAppDelete,% Language.GetValue(Lang,"Delete")
	GUI,GesConfig:Add,Button,x210 y180 w100 h24 gGestureConfigActAdd,% Language.GetValue(Lang,"Add") "(&A)"
	GUI,GesConfig:Add,Button,x330 y180 w100 h24 gGestureConfigActDelete,% Language.GetValue(Lang,"Delete")
	GUI,GesConfig:Add,CheckBox,x334 y208 w100 h30 , % Language.GetValue(Lang,"Disable Gestrue")
	GUI,GesConfig:Add,Groupbox,x450 y10 w340 h450,% Language.GetValue(Lang,"AHK Code")
	GUI,GesConfig:Add,Text,x212 y264 w220 h200,% "    " Lang("Application help info1") "`n    " Lang("Application help info2")
	GUI,GesConfig:TreeView,SysTreeView321
	GUI,GesConfig:Menu,MenuBar
}
Else
{
;========================================================
;传统界面
	GUI,GesConfig:Default
	GUI,GesConfig:+hwndhGUI +LastFound
	GUI,GesConfig:Font,s10 ,Microsoft YaHei
	GUI,GesConfig:Add,TreeView,x10  y10 w180 h450 gTreeViewCommand AltSubmit
	GUI,GesConfig:Add,Groupbox,x200 y10 w390 h170
	GUI,GesConfig:Add,ListBox ,x210 y32 w280 h140
	GUI,GesConfig:Add,Button,x502 y35 w80 h24 gGestureConfigFinder,% Language.GetValue(Lang,"Add") "(&A)"
	GUI,GesConfig:Add,Button,x502 y65 w80 h24 gGestureConfigAppEdit,% Language.GetValue(Lang,"Edit") 
	GUI,GesConfig:Add,Button,x502 y95 w80 h24 gGestureConfigAppDelete,% Language.GetValue(Lang,"Delete")
	GUI,GesConfig:Add,Button,x502 y35 w80 h24 gGestureConfigActAdd,% Language.GetValue(Lang,"Add") "(&A)"
	GUI,GesConfig:Add,Button,x502 y65 w80 h24 gGestureConfigActDelete,% Language.GetValue(Lang,"Delete")
	GUI,GesConfig:Add,CheckBox,x504 y138 w80 h30 , % Language.GetValue(Lang,"Disable Gestrue")
	GUI,GesConfig:Add,Groupbox,x200 y190 w390 h270,% Language.GetValue(Lang,"AHK Code")
	GUI,GesConfig:Add,Text,x220 y240 w350 h200,% "    " Lang("Application help info1") "`n    " Lang("Application help info2")
	GUI,GesConfig:TreeView,SysTreeView321
	GUI,GesConfig:Menu,MenuBar
}

	GoSub,LoadSCI
	GoSub,LoadToolbar
	GoSub,LoadHK

return

GesConfigGUISize:
	IfWinActive,ahk_id %hGUI%
	{
		Anchor("SysTreeView321","h")
		Anchor("Button8","wh")
		Anchor("Scintilla1","wh")
	}
return

MenuBarGo:
	If RegExMatch(A_ThisMenuItem,"&D")
		GoSub,ConfigOption
	If RegExMatch(A_ThisMenuItem,"&G")
		GestureLearn("",false)
return

; ConfigOption {{{2
ConfigOption:
;=====================
	GUI,ConfigOption:Destroy
	GUI,ConfigOption:Default
	GUI,ConfigOption:Font,s10 ,Microsoft YaHei
;=====================
	GUI,ConfigOption:Add,Button,x275 y320 w80 h24 gConfigOption_OK Default,% Language.GetValue(Lang,"Button OK")
	GUI,ConfigOption:Add,Button,x375 y320 w80 h24 gConfigOption_Close,% Language.GetValue(Lang,"Button Close")
	GUI,ConfigOption:Add,Tab2,x5 y5 w450 h310 ,% Lang("Tab option")
;=====================
	GUI,ConfigOption:Tab,2
	GUI,ConfigOption:Add,GroupBox,x15 y35 w430 h170,% Lang("Inside Editor")
	Gui,ConfigOption:Add,Checkbox,x24 y62 w100 h24 gConfigOption_InsideEditor_AutoSave,% Language.GetValue(Lang,"AutoSave") 
	If configINI.GetValue("Config","AutoSave")
		GuiControl,,Button4,1
	Else
		GuiControl,,Button4,0
;---------------------
	GUI,ConfigOption:Add,GroupBox,x15 y210 w430 h90 ,% Lang("OutSide Editor")
	GUI,ConfigOption:Add,Text,x24 y237 w60 h24,% Lang("Editor Path")
	GUI,ConfigOption:Add,Edit,x60 y235 w304 h24,% configINI.GetValue("config","Editor") 
	GUI,ConfigOption:Add,Button,x370 y234 w70 h26 gConfigOption_OutSideEditor_Browse,% Lang("Button Browse")
	GUI,ConfigOption:Add,Text,x24 y267 w60 h24,% Lang("Editor Param")
	GUI,ConfigOption:Add,Edit,x60 y265 w304 h24 gConfigOption_OutSideEditor_Param,% configINI.GetValue("config","Editor Param") 
	GUI,ConfigOption:Add,Button,x370 y264 w70 h26 gConfigOption_OutSideEditor_help,% Lang("Button Help")
;=====================
	GUI,ConfigOption:Show,w460 h350,% Language.GetValue(Lang,"ConfigOption") 
return
ConfigOption_OutSideEditor_help:
	Msgbox ,64,% Lang("OutSide Editor") ,% Lang("OutSide Editor Help")
return
ConfigOption_OutSideEditor_Browse:
	FileSelectFile,outside_editor,1,%A_ProgramFiles%,% Lang("OutSide Editor"),*.EXE
	If not FileExist(outside_editor)
		return
	GUI,ConfigOption:Default
	GUIControl,,Edit1,%outside_editor%
	configINI.iniWrite("Config","Editor",outside_editor)
	configINI.Read()
return
ConfigOption_OutSideEditor_Param:
	GUI,ConfigOption:Default
	GUIControlGet,Param,,Edit2
	configINI.iniWrite("Config","Editor Param",Param)
	configINI.Read()
return
ConfigOption_InsideEditor_AutoSave:
	GUI,ConfigOption:Default
	GUIcontrolGet,autosave,,Button4
	configINI.iniWrite("config","AutoSave",autosave)
	configINI.Read()
return
ConfigOption_OK:
	GUI,ConfigOption:Destroy
return
ConfigOption_Close:
	GUI,ConfigOption:Destroy
return
AutoSave:
	config_ActionSave()
return

; GestureConfigShow {{{2
GestureConfigShow:
	If not WinExist("ahk_id " hGUI)
	{
		If configINI.GetValue("config","tree colum viewer")
			GUI,GesConfig:Show,w800 h470,GestureZ
		Else
			GUI,GesConfig:Show,w600 h470,GestureZ
	}
	IfWinNotActive ,ahk_id %hGUI%
	{
		WinActivate,ahk_id %hGUI%
		return
	}
	GestureConfigLoad()
return
; GestureConfigHide {{{2
GestureConfigHide:
	GUI,GesConfig:Hide
return
; Config_Menu_NewApp {{{2
Config_Menu_NewApp:
	GUI,GesConfig_NewApp:Destroy
	GUI,GesConfig_NewApp:Default
	GUI,GesConfig_NewApp:Font,s10 ,Microsoft YaHei
	GUI,GesConfig_NewApp:Add,Text,w200 h24  x10 y10 ,% Language.GetValue(Lang,"New Application")
	GUI,GesConfig_NewApp:Add,Edit,w200 h24  x10 y40
	GUI,GesConfig_NewApp:Add,Button,w90 h24 x10  y80  gConfig_Menu_NewApp_OK Default,% Language.GetValue(Lang,"Button OK")
	GUI,GesConfig_NewApp:Add,Button,w90 h24 x120 y80  gConfig_Menu_NewApp_Close ,% Language.GetValue(Lang,"Button Close")
	GUI,GesConfig_NewApp:Show,w220 h120 ,GestureZ
return
Config_Menu_NewApp_Close:
	GUI,GesConfig_NewApp:Destroy
return
Config_Menu_NewApp_OK:
	GUI,GesConfig_NewApp:Default
	GUIControlGet,newApp,,Edit1
	If RegExMatch(newApp,"^[\s\t]*$")
		return
	If not appINI.Content[newApp]
	{
			GUI,GesConfig:Default
			GUI,GesConfig:TreeView,SysTreeView321
			TV_Add(newApp,0,"icon1 vis select")
		 	i := appINI.filePath
		 	iniWrite,%null%,%i%,%newApp%
			appINI.Read()
			GUI,GesConfig_NewApp:Destroy
	}
	Else
		Msgbox % Language.GetValue(Lang,"Application Exist")
return
; Config_Menu_NewAct {{{2
Config_Menu_NewAct:
	GUI,GesConfig:Default
	GUI,GesConfig:TreeView,SysTreeView321
	id := TV_GetParent(TV_GetSelection()) ? TV_GetParent(TV_GetSelection()) : TV_GetSelection()
	TV_GetText(s,id)
	GUI,GesConfig_NewAct:Destroy
	GUI,GesConfig_NewAct:Default
	GUI,GesConfig_NewAct:Font,s10 ,Microsoft YaHei
	GUI,GesConfig_NewAct:Add,Text,w200 h24  x10 y10 ,% Language.GetValue(Lang,"New Action")
	GUI,GesConfig_NewAct:Add,Edit,w200 h24  x10 y40 ,%s%_
	GUI,GesConfig_NewAct:Add,Button,w90 h24 x10  y80  gConfig_Menu_NewAct_OK Default,% Language.GetValue(Lang,"Button OK")
	GUI,GesConfig_NewAct:Add,Button,w90 h24 x120 y80  gConfig_Menu_NewAct_Close ,% Language.GetValue(Lang,"Button Close")
	GUI,GesConfig_NewAct:Show,w220 h120 ,GestureZ
return
Config_Menu_NewAct_Close:
	GUI,GesConfig_NewAct:Destroy
return
Config_Menu_NewAct_OK:
	GUI,GesConfig_NewAct:Default
	GUIControlGet,newAct,,Edit1
	If RegExMatch(newAct,"^[\t\s]*$")
		return
	GUI,GesConfig:Default
	GUI,GesConfig:TreeView,SysTreeView321
	id := TV_GetParent(TV_GetSelection()) ? TV_GetParent(TV_GetSelection()) : TV_GetSelection()
	TV_GetText(Sec,id)
	If (id = permit_ID)
		sec := "Global Permit"
;	If not actINI.GetValue(Sec,newAct)
	If Not FileExist(A_ScriptDir "\Config\Commands\" newAct ".ahk")
	{
		TV_Add(newAct,id,"icon2 vis select")
		TV_Modify(id,"Expand")
		i := cmdINI.filePath
		;k := ( idx := cmdINI.GetKeyCount(sec)) ? idx + 1 : 1
		Loop,1000
		{
			If not strlen(cmdINI.GetValue(sec,A_Index)){
				k := A_index
				break
			}
		}
		iniWrite,%newAct%,%i%,%Sec%,%k%
		cmdINI.Read()
		If Not FileExist(cmds := A_ScriptDir "\config\commands")
		FileCreateDir,%cmds%
		FileAppend,
		(
		`;%newAct%`r`n
		),%A_ScriptDir%\Config\Commands\%newAct%.ahk
		GUI,GesConfig_NewAct:Destroy
	}
	Else
		Msgbox % Language.GetValue(Lang,"Action Exist")
return

; Config_Menu_Rename {{{2
Config_Menu_Rename:
	GUI,GesConfigRename:Add,Edit,w200
	GUI,GesConfigRename:Add,Edit,w200
	GUI,GesConfigRename:Show
return
Config_Menu_Rename_OK:
	Config_Menu_Rename(src,dst)
return
Config_Menu_Rename(src,dst)
{
	Global appINI,actINI,cmdINI,permit_ID
	GUI,GesConfig:Default
	GUI,GesConfig:TreeView,SysTreeView321
	If TV_GetParent(TV_GetSelection()) {
	}
	Else
	{
	}
}
; Config_Menu_Delete {{{2
Config_Menu_Delete:
	Config_Menu_Delete()
return
Config_Menu_Delete()
{
	Global appINI,actINI,cmdINI,permit_ID
	GUI,GesConfig:Default
	GUI,GesConfig:TreeView,SysTreeView321
	; 删除动作
	If TV_GetParent(TV_GetSelection()) {
		MsgBox, 68,, % Lang("Would you like to Delete Action")
		IfMsgBox Yes
		{
			TV_GetText(text,TV_GetSelection())
			TV_GetText(sec,id := TV_GetParent(TV_GetSelection()))
			If (id = Permit_ID)
				sec := "Global Permit"
			TV_Delete(TV_GetSelection())
			FileDelete,% A_ScriptDir "\config\commands\" text ".ahk"
			acts := actINI.GetKeys(sec)
			Loop,Parse,acts,`n
			{
				If not Strlen(A_LoopField)
					continue
				If RegExMatch(actINI.GetValue(sec,A_LoopField),"i)^" ToMatch(text) "$")
					actINI.iniDelete(sec,A_LoopField)
			}
			i := 1
			newcmd := []
			Loop,% cmdINI.GetKeyCount(sec)
			{
				If RegExMatch(new := cmdINI.GetValue(sec,A_Index),"i)^" ToMatch(text) "$")
					continue
				Else If Strlen(new){
					newcmd[i] := new
					i++
				}
			}
			cmdINI.iniDelete(sec)
			for i , k in newcmd
				cmdINI.iniWrite(sec,i,k)
		}
	}
	; 删除程序集
	Else {
		MsgBox, 68,, % Lang("Would you like to Delete Application")
		IfMsgBox Yes
		{
			TV_GetText(text,TV_GetSelection())
			TV_Delete(TV_GetSelection())
			cmds := cmdINI.GetKeys(text)
			Loop,Parse,cmds,`n
			{
				If not Strlen(A_LoopField)
					continue
				file := cmdINI.GetValue(text,A_LoopField)
				FileDelete,% A_ScriptDir "\config\commands\" file ".ahk"
			}
			cmdINI.iniDelete(text,"")
			appINI.iniDelete(text,"")
			actINI.iniDelete(text,"")
		}
	}
}
;=============
; IconSelect: {{{2
Config_Menu_AppIcon:
IconSelect:
GUI,GesConfig:Default
GUI,GesConfig:TreeView,SysTreeView321
TV_GetText(ThisApp,(ThisAppid := TV_GetParent(TV_GetSelection())) ?  ThisAppid : (ThisAppid := TV_GetSelection()))
GUI,IconSelect:Destroy
GUI,IconSelect:Default
GUI,IconSelect:+theme +Resize +hwndhIconGUI
GUI,IconSelect:Font,s9,Microsoft YaHei
GUI,IconSelect:Add,Radio   ,x10  y40   w90 h24 gGoReport checked,% Language.GetValue(Lang,"Report view")
GUI,IconSelect:Add,Radio   ,x120 y40   w90 h24 gGoList,% Language.GetValue(Lang,"List view") 
GUI,IconSelect:Add,Radio   ,x225 y40   w100 h24 gGoIcons,% Language.GetValue(Lang,"Icons view")
GUI,IconSelect:Add,Radio   ,x340 y40   w100 h24 gGoSmallIcons,% Language.GetValue(Lang,"smallicons view")
GUI,IconSelect:Add,ListView,x10  y70   w500 h300 nosort -Multi altsubmit gIconSelect_OK ,% Language.GetValue(Lang,"select Icon listview")
GUI,IconSelect:Add,Edit,x10  y380  w500 r1,% configINI.GetValue("config","icon folder")
GUI,IconSelect:Add,Radio   ,x10  y419  h24 gButton_Icon_Open, % Language.GetValue(Lang,"button file")
GUI,IconSelect:Add,Radio   ,x85  y419  h24 checked gButton_Icon_Open, % Language.GetValue(Lang,"button folder")
GUI,IconSelect:Add,Button  ,x165 y418  h24 w80 gButton_Icon_Search Default,% Language.GetValue(Lang,"Button Search")
GUI,IconSelect:Add,Button  ,x431 y418  h24 w80 gButton_Icon_Cancel,% Language.GetValue(lang,"Button Close")
GUI,IconSelect:Add,Button  ,x320 y418  h24 w100 gIconSelect_Clear,% Language.GetValue(lang,"Button Delete Icon")
GUI,IconSelect:ListView,SysTreeView321
LV_ModifyCol(1,60)
;GUI,IconSelect:Add,Text    ,x10  y10   w400 h24 ,%  TV_SelectItem "  >>  " Language.GetValue(Lang,"select icon") 
GUI,IconSelect:Add,Edit,    x10 y10 w500 h24 ReadOnly ,% ThisApp
GUI,IconSelect:Show,w520 ,% Language.GetValue(Lang,"select icon") 
WinMove,ahk_id %hIconGUI%,,,,535
Icon_Search_stop := False
Icon_Search()
return
; IconGUI_Size(w,p) {{{3
IconSelectGUISize:
	IfWinActive ahk_id %hIconGUI%
	{
		Anchor("SysListView321","wh")
		Anchor("Edit1","wy")
		Anchor("Button5","y")
		Anchor("Button6","y")
		Anchor("Button7","xy")
		Anchor("Button8","xy")
		Anchor("Button9","xy")
		GUI,IconSelect:Default
		GUI,IconSelect:ListView,SysListView321
		ControlGetPos , , , w, ,SysListView321,ahk_id %hIconGUI%
		LV_ModifyCol(2,w-60)
	}
	IfWinActive ahk_id %hTypeGUI%
	{
		Anchor("SysListView321","wh")
		Anchor("Button1","y")
		Anchor("Button2","y")
		Anchor("Button3","y")
		Anchor("Button4","xy")
	}
return
; IconSelect_Clear: {{{3
IconSelect_Clear:
	GUI,IconSelect:Destroy
	GUI,GesConfig:Default
	GUI,GesConfig:TreeView,SysTreeView321
	TV_Modify(ThisAppID,"Icon1")
	appINI.iniDelete(ThisApp,"Icon")
return
; IconSelect_OK: {{{3
IconSelect_OK:
	If A_GuiEvent = DoubleClick
	{
		GUI,IconSelect:Default
		GUI,IconSelect:ListView,SysTreeView321
		LV_GetText(icon,A_EventInfo,2)
		appINI.iniWrite(ThisApp,"Icon",Icon)
		Gui,IconSelect:Destroy
		GUI,GesConfig:Default
		GUI,GesConfig:TreeView,SysTreeView321
		If Strlen(Icon){
				iconfile := RegExReplace(icon,",.*$")
				iconidx  := RegExReplace(icon,"^.*,")
				idx := IL_Add(IconList,configINI.ReplaceEnv(iconfile),iconidx)
				TV_Modify(ThisAppid,"icon" idx)
		}
	}
return
; Button_Icon_Cancel: {{{3
Button_Icon_Cancel:
	GUI,IconSelect:Destroy
return
; Button_Icon_Open: {{{3
Button_Icon_Open:
	Button_Icon_Open()
return
Button_Icon_Open()
{
	Global Language,Lang
	GUI,IconSelect:Default
	GUI,IconSelect:ListView,SysTreeView321
	GUIControlGet,type,,Button5
	If type
		FileSelectFile,file	,3,  , ,% Language.GetValue(Lang,"select Icon file") "(*.ICO; *.CUR; *.ANI; *.EXE; *.DLL; *.CPL; *.SCR; *.PNG)"
	Else
		FileSelectFolder,file ,*%A_ScriptDir%\Icons\,2, % Language.GetValue(Lang,"select icon folder")
	If not strlen(file)
		return
	GUIControl,,Edit1,%file%
	GoSub,Icon_Search
}
; Button_Icon_Search: {{{3
Button_Icon_Search:
	If Icon_Search_stop
		Settimer,Icon_Search,20
	Else
		Icon_Search_stop := True
return
; Icon_Search: {{{3
Icon_Search:
	Settimer,Icon_Search,off
	Icon_Search_stop := False
	Icon_Search()
return
Icon_Search(){
	Global Language,Lang,Icon_Search_stop,configINI
	GUI,IconSelect:Default
	GUI,IconSelect:ListView,SysTreeView321
	GUIControlGet,file,,Edit1
	GUIControlGet,type,,Button5
	GUIControl,,Button7,% Language.GetValue(Lang,"Button Stop")
	file := configINI.ReplaceEnv(file)
	LV_Delete()
	iconfile := file
	iconfilerel := iRelativePath(file)
	IconListSmall := IL_Create(100,100,0)
	ListID   := LV_SetImageList(IconListSmall)
	If ListID
		IL_Destroy(ListID)
	IconListLarge := IL_Create(100,100,1)
	ListID   := LV_SetImageList(IconListLarge)
	If ListID
		IL_Destroy(ListID)
	If Type
	{
		m := 0
		Loop, 9999
		{
			If (id := IL_Add(IconListSmall,Iconfile,A_Index)) {
				IL_Add(IconListLarge,iconfile,A_Index)
				LV_Add("Icon"  id,A_Index,iconfilerel "," A_Index)
				m++
			}
			Else
				Break
		}
		If (not m) And (id := IL_Add(IconListSmall,A_LoopFileFullPath)){
			IL_Add(IconListLarge,A_LoopFileFullPath,A_Index)
			LV_Add("Icon" id ,i,iRelativePath(A_LoopFileFullPath))
			i++
		}
	}
	Else
	{
		i := 1
		If InStr(FileExist(IconFile),"D")
		{
			If RegExMatch(IconFile,"\\$")
				IconFile := SubStr(IconFile,1,Strlen(IconFile)-1)
			Loop,%iconfile%\*.*,0,1
			{
				If RegExMatch(A_LoopFileFullPath,"i)(\.ICO)|(\.CUR)|(\.ANI)|(\.EXE)|(\.DLL)|(\.CPL)|(\.SCR)|(\.PNG)$")
				{
					m := 0
					Loop,9999
					{
						If (id := IL_Add(IconListSmall,A_LoopFileFullPath,A_Index)) {
							IL_Add(IconListLarge,A_LoopFileFullPath,A_Index)
							LV_Add("Icon" id ,i,iRelativePath(A_LoopFileFullPath)"," A_Index)
							i++
							m++
						}
						Else
							Break
						If Icon_Search_stop
							Break
					}
					If ( not m ) and (id := IL_Add(IconListSmall,A_LoopFileFullPath)){
						IL_Add(IconListLarge,A_LoopFileFullPath,A_Index)
						LV_Add("Icon" id ,i,iRelativePath(A_LoopFileFullPath))
						i++
					}
				}
				If Icon_Search_stop
					Break
			}
		}
		Icon_Search_stop := True
		If i = 0
			MsgBox % Language.GetValue(Lang,"select icon folder error")
	}
	GUIControl,,Button7,% Language.GetValue(Lang,"Button Search")
}
; GoReport: {{{3
GoReport:
GUI,IconSelect:Default
GUI,IconSelect:ListView,SysListView321
GuiControl,+Report, SysListView321
Return

; GoIcons: {{{3
GoIcons:
GUI,IconSelect:Default
GUI,IconSelect:ListView,SysListView321
GuiControl,+Icon, SysListView321
Return

; GoSmallIcons: {{{3
GoSmallIcons:
GUI,IconSelect:Default
GUI,IconSelect:ListView,SysListView321
GuiControl,+IconSmall,SysListView321
Return

; GoList: {{{3
GoList:
GUI,IconSelect:Default
GUI,IconSelect:ListView,SysListView321
GuiControl,+List, SysListView321
Return
return

; iRelativePath(i) {{{3
iRelativePath(file){
	file := RegExReplace(file,"i)" ToMatch(A_ScriptDir "\Config"),"%CONFIG%")
	file := RegExReplace(file,"i)" ToMatch(A_ScriptDir "\Plugins"),"%PLUGINS%")
	file := RegExReplace(file,"i)" ToMatch(A_ScriptDir "\Script"),"%SCRIPT%")
	file := RegExReplace(file,"i)" ToMatch(A_ScriptDir "\Icons"),"%ICONS%")
	file := RegExReplace(file,"i)" ToMatch(A_ScriptDir "\Apps"),"%APPS%")
	file := RegExReplace(file,"i)" ToMatch(A_ScriptDir),"%A_SCRIPTDIR%")
	file := RegExReplace(file,"i)" ToMatch(A_WinDir),"%A_WINDIR%")
	return file
}

; TreeViewCommand {{{2
TreeViewCommand:
	Critical
	GUI,GesConfig:Default
	GUI,GesConfig:TreeView,SysTreeView321 
	If A_GuiEvent = RightClick
	{
		MouseGetPos,posx,posy
		Menu,RightClick,Add
		Menu,RightClick,DeleteAll
		Menu,RightClick,Add, % Language.GetValue(Lang,"New Application") "(&D)",Config_Menu_NewApp
		Menu,RightClick,Icon, % Language.GetValue(Lang,"New Application") "(&D)", shell32.dll, 3
		If A_EventInfo 
		{
			TV_Modify(A_EventInfo,"select")
			If (A_EventInfo <> deny_ID)
			{
				Menu,RightClick,Add, % Language.GetValue(Lang,"New Action")  "(&F)",Config_Menu_NewAct
				Menu,RightClick,icon, % Language.GetValue(Lang,"New Action")  "(&F)",% a_ahkpath ,2
			}
		}
		If not TV_GetParent(A_EventInfo) And (A_EventInfo <> deny_ID) And (A_EventInfo <> permit_ID)
		{
			Menu,RightClick,Add
			Menu,RightClick,Add, % Language.GetValue(Lang,"Application Icon")  "(&I)",Config_Menu_AppIcon
		}
		If (A_EventInfo <> deny_ID) And (A_EventInfo <> permit_ID)
		{
			Menu,RightClick,Add
			Menu,RightClick,Add, % Language.GetValue(Lang,"Rename"),Config_Menu_Rename
			Menu,RightClick,Add, % Language.GetValue(Lang,"Delete"),Config_Menu_Delete
		}
		Menu, RightClick, Show, %posx%, %posy%
		return
	}
	If TV_GetParent(tid := TV_GetSelection())
	{
			GUIControl,,Button1,% Lang("Button Gestrue")
			GUIcontrol,Hide,Button2
			GUIcontrol,Hide,Button3
			GUIcontrol,Hide,Button4
			GUIcontrol,Show,Button5
			GUIcontrol,Show,Button6
			GUIcontrol,Hide,Button7
			GUIControl,,ListBox1,|
			ControlGet,vis1,Visible,,Static1,ahk_id %hGUI%
			If vis1 
				Control,Hide,,Static1,ahk_id %hGUI%
			ControlGet,vis2,Visible,,Scintilla1,ahk_id %hGUI%
			If not vis2
			{
				Control,Show,,Button8,ahk_id %hGUI%
				Control,Show,,ToolbarWindow321,ahk_id %hGUI%
				Control,Show,,Scintilla1,ahk_id %hGUI%
			}
			TV_GetText(c,tid)
			vs := "i)^" ToMatch(c) "$"
			If (TV_GetParent(tid) = permit_ID)
				s := "Global Permit"
			Else
				TV_GetText(s,TV_GetParent(tid))
			ss := actINI.GetKeys(s)
			Loop,Parse,ss,`n,`r
			{
				If not Strlen(A_LoopField)
					break
				v := ActINI.GetValue(s,A_LoopField)
				If RegExMatch(v,vs)
		 			GuiControl,,ListBox1,% A_LoopField
			}
			p := A_ScriptDir "\Config\Commands\" c ".ahk"
			FileRead,v,%p%
			If v
			{
				SCI.SetText(unused,v)
			}
			Else
				SCI.ClearAll()
			v := ""
	}
	Else
	{
			GUIControl,,Button1,% Lang("Button Application")
			GUIcontrol,Show,Button2
			GUIcontrol,Show,Button3
			GUIcontrol,Show,Button4
			GUIcontrol,Hide,Button5
			GUIcontrol,Hide,Button6
			GUIcontrol,Show,Button7
			ControlGet,vis,Visible,,Static1,ahk_id %hGUI%
			If not vis
				Control,Show,,Static1,ahk_id %hGUI%
			ControlGet,vis,Visible,,Scintilla1,ahk_id %hGUI%
			If vis
			{
				Control,Hide,,Button8,ahk_id %hGUI%
				Control,Hide,,ToolbarWindow321,ahk_id %hGUI%
				Control,Hide,,Scintilla1,ahk_id %hGUI%
			}
			If (tid = permit_ID)
			{
			GUIcontrol,Disable,Button2
			GUIcontrol,Disable,Button3
			GUIcontrol,Disable,Button4
			;GUIcontrol,Disable,Button5
			;GUIcontrol,Disable,Button6
			GUIcontrol,Disable,Button7
			}
			Else
			{
			GUIcontrol,Enable,Button2
			GUIcontrol,Enable,Button3
			GUIcontrol,Enable,Button4
			;GUIcontrol,Enable,Button5
			;GUIcontrol,Enable,Button6
			GUIcontrol,Enable,Button7
			}
			If (tid = deny_ID)
			{
				s := "Global Deny"
				GUIcontrol,hide,Button7
			}
			Else
				TV_GetText(s,tid)
			if strlen(disable := appINI.GetValue(s,"disable")) And (disable <> 0)
				disable := 1
			Else
				disable := 0
			GUIControl,,Button7, % disable
			GUIControl,,ListBox1,|
			ss := appINI.GetKeys(s)
			Loop,Parse,ss,`n,`r
			{
				If not Strlen(A_LoopField)
					break
				v := appINI.GetValue(s,A_LoopField)
				If RegExMatch(v,"i)^class$")
		 			GuiControl,,ListBox1,% "窗口类:  " A_LoopField
				If RegExMatch(v,"i)^file$")
		 			GuiControl,,ListBox1,% "文件名:  " A_LoopField
			}
			;SCI.ClearAll()
	}
	Critical,off
return
; GestureConfigFinder {{{2
GestureConfigFinder:
	ID := ""
	GUI,GesConfigFinder:Destroy
	GUI,GesConfigFinder:Default
	GUI,GesConfigFinder:+hwndhFinderGUI
	GUI,GesConfigFinder:Font,s9 ,Microsoft YaHei
	Gui,GesConfigFinder:Add,GroupBox,x10 w300 h90
	Gui,GesConfigFinder:Add,Radio,x20 y30 w120 gFinderChange Checked,% Lang("Button Class")
	Gui,GesConfigFinder:Add,Radio,x20 y60 w120 gFinderChange,% Lang("Button file")
	GUI,GesConfigFinder:Add,Picture,x240 y45 w32 h32 gSetico,%Full_ico_File%
	Gui,GesConfigFinder:Add,Text,x235 y25 ,% Lang("button Finder")
	Gui,GesConfigFinder:Add,Edit,x10 y112 w300 
	Gui,GesConfigFinder:Add,Button,x140 y150 w80 gFinderOK Default,% Lang("Button OK")
	Gui,GesConfigFinder:Add,Button,x230 y150 w80 gFinderCancel,% Lang("Button Close")
	Gui,GesConfigFinder:Show,h190 ,% Lang("Button Finder")
return
; Setico {{{3
Setico:
IfNotExist,%Cross_CUR_File%
	BYTE_TO_FILE(StrToBin(Cross_CUR),Cross_CUR_File)
IfNotExist,%Null_ico_File%
	BYTE_TO_FILE(StrToBin(Null_ico),Null_ico_File)
GUI,GesConfigFinder:Default
GuiControl,,Static1,%Null_ico_File%
;设置鼠标指针为十字标
CursorHandle := DllCall( "LoadCursorFromFile", Str,Cross_CUR_File )
DllCall( "SetSystemCursor", Uint,CursorHandle, Int,32512 )
SetTimer,GetPos,200
;等待左键弹起
KeyWait,LButton
SetTimer,GetPos,Off
;还原鼠标指针
DllCall( "SystemParametersInfo", UInt,0x57, UInt,0, UInt,0, UInt,0 )
;图标设置为原样
IfNotExist,%Full_ico_File%
	BYTE_TO_FILE(StrToBin(Full_ico),Full_ico_File)
GuiControl,,Static1,%Full_ico_File%
return

; GetPos {{{3
GetPos:
	MouseGetPos,,,id
	GUI,GesConfigFinder:Default
	GuiControlGet,v2,,Button2
	If v2
	{
	   WinGetClass,c,ahk_id %id%
		 GuiControl,,Edit1,%c%
	}
	Else 
	{
	   WinGet,c,ProcessName,ahk_id %id%
		 GuiControl,,Edit1,%c%
	}
return

; FinderChange {{{3
FinderChange:
	GUI,GesConfigFinder:Default
	GuiControlGet,v,,Button2
	If v
	{
	   WinGetClass,c,ahk_id %id%
		 GuiControl,,Edit1,%c%
	}
	Else 
	{
	   WinGet,c,ProcessName,ahk_id %id%
		 GuiControl,,Edit1,%c%
	}
return

; FinderOK {{{3
FinderOK:
	Gui,GesConfig:Default
	Gui,GesConfig:TreeView,SysTreeView321
	If ( deny_ID = TV_GetSelection())
		s := "Global Deny"
	Else
		TV_GetText(s, TV_GetSelection())
	Gui,GesConfigFinder:Default
	GuiControlGet,v,,Button2
	i := appINI.filePath
	If IsEdit
		IniDelete,%i%,%s%,%vs%
	If v
	{
		 GuiControlGet,v,,Edit1
		 INIWrite,class,%i%,%s%,%v%
	}
	Else 
	{
		 GuiControlGet,v,,Edit1
		 INIWrite,file,%i%,%s%,%v%
	}
	Gui,GesConfigFinder:Destroy
	GoSub,TreeViewCommand
	GZ_Load()
	IsEdit := False
return
; FinderCancel {{{3
FinderCancel:
	Gui,GesConfigFinder:Destroy
	IsEdit := False
return

; GestureConfigAppEdit {{{2
GestureConfigAppEdit:
	Gui,GesConfig:Default
	Gui,GesConfig:TreeView,SysTreeView321
	If ( deny_ID = TV_GetSelection())
		s := "Global Deny"
	Else
		TV_GetText(s,TV_GetSelection())
	GUIControlGet,v,,ListBox1
  vs := v := RegExReplace(v,"^[^:\s]*:\s*")
	IsEdit := True
	GoSub,GestureConfigFinder
	If RegExMatch(appINI.GetValue(s,v),"i)^class$")
		GuiControl,,Button2,1
	Else
		GuiControl,,Button3,1
	GuiControl,,Edit1,%v%
return

; GestureConfigAppDelete {{{2
GestureConfigAppDelete:
	Gui,GesConfig:Default
	Gui,GesConfig:TreeView,SysTreeView321
	If ( deny_ID = TV_GetSelection())
		s := "Global Deny"
	Else
		TV_GetText(s,TV_GetSelection())
	GUIControlGet,v,,ListBox1
  vs := v := RegExReplace(v,"^[^:\s]*:\s*")
	i := appINI.filePath
	IniDelete,%i%,%s%,%vs%
	GoSub,TreeViewCommand
	GZ_Load()
return

; GestureConfigActAdd {{{2
GestureConfigActAdd:
	GUI,GesConfigAct:Destroy
	GUI,GesConfigAct:Default
	GUI,GesConfigAct:+hwndhActGUI
	GUI,GesConfigAct:Font,s9 ,Microsoft YaHei
	GUI,GesConfigAct:Add,Text,x10 y10 w240 ,添加手势，请选择并双击.
	GUI,GesConfigAct:Add,ListBox,x10 y40 w240 h360 gGestureConfigActAddOK Sort
	GestureGet()
	GUI,GesConfigAct:Show
return

GestureGet(){
	Global gesINI,gebINI
	gsname := []
	gs := gebINI.GetKeys("Gesture")
	Loop,Parse,gs,`n,`r
	{
		If Not Strlen(A_LoopField)
				break
		If strlen(n := gebINI.GetValue("Gesture",A_LoopField))
			gsname[n] := True
	}
	gs := gesINI.GetKeys("Gesture")
	Loop,Parse,gs,`n,`r
	{
		If Not Strlen(A_LoopField)
				break
		If strlen(n := gesINI.GetValue("Gesture",A_LoopField))
			gsname[n] := True
	}
	
	GUI,GesConfigAct:Default
	For i , k in gsname
		 GUIControl,,ListBox1,%i%
}
; GestureConfigActAddOK {{{3
GestureConfigActAddOK:
	If A_GUIEvent = DoubleClick
	{
	   GUI,GesConfigAct:Default
		 GuiControlGet,k,,ListBox1
		 i := actINI.filePath
		 Gui,GesConfig:Default
		 Gui,GesConfig:TreeView,SysTreeView321
		 TV_GetText(v,TV_GetSelection())
		If (TV_GetParent(tid) = permit_ID)
			s := "Global Permit"
		Else
			TV_GetText(s,TV_GetParent(TV_GetSelection()))
		 iniWrite,%v%,%i%,%s%,%k%
	   GUI,GesConfigAct:Destroy
		 GoSub,TreeViewCommand
		 GZ_Load()
	}
return

; GestureConfigActDelete {{{3
GestureConfigActDelete:
		 i := actINI.filePath
		 Gui,GesConfig:Default
		 Gui,GesConfig:TreeView,SysTreeView321
		If (TV_GetParent(tid) = permit_ID)
			s := "Global Permit"
		Else
			TV_GetText(s,TV_GetParent(TV_GetSelection()))
		 GuiControlGet,k,,ListBox1
		 IniDelete,%i%,%s%,%k%
		 GoSub,TreeViewCommand
		 GZ_Load()
return

; GestureConfigLoad() {{{2
GestureConfigLoad(){
	Global appINI,cmdINI,Language,IconList,permit_ID,deny_ID
	GUI,GesConfig:Default
	GUI,GesConfig:TreeView,SysTreeView321
	IconList := IL_Create(2)
	TV_SetImageList(IconList)
	IL_Add(IconList,"shell32.dll",3)
	IL_Add(IconList,A_ahkPath,2)
	TV_Delete()
	permit_ID := TV_Add(Lang("Global permit"),0,"icon1")
	deny_ID := TV_Add(Lang("Global deny"),0,"icon1")
	LoadApp := appINI.GetSections()
	Loop,Parse,LoadApp,`n,`r
	{
		If RegExMatch(A_LoopField,"i)^Global\sPermit$")
		{
			IsGlobalPermit := True
			Break
		}
	}
	If not IsGlobalPermit
		LoadApp .= "`nGlobal Permit"
	Loop,Parse,LoadApp,`n,`r
	{
		If Not Strlen(A_LoopField)
			continue
		App := A_LoopField
		If (icon := appINI.GetValue(App,"icon")){
			iconfile := RegExReplace(icon,",.*$")
			iconidx  := RegExReplace(icon,"^.*,")
			idx := IL_Add(IconList,iconfile,iconidx)
		}
		If RegExMatch(App,"i)^Global\spermit$")
			AppID := permit_ID 
		Else If RegExMatch(App,"i)^Global\sDeny$")
			AppID := deny_ID
		Else If idx
			AppID := TV_Add(App,0,"icon" idx)
		Else
			AppID := TV_Add(App,0,"icon1")
		idx := 0
		LoadAct := cmdINI.GetKeys(App)
		ActionName := []
		Loop,Parse,LoadAct,`n,`r
		{
			If Not Strlen(A_LoopField)
				continue
			an := cmdINI.GetValue(App,A_LoopField)
			ActionName[an] := ActionName[an] "`n"  A_LoopField
		}
		for i , k in ActionName
			actID := TV_Add(i,AppID,"icon2")
	}
	GuiControl, +Redraw, SysTreeView321
}
; GestureLearn(ges) {{{2
; 手势学习界面 
GestureLearn(ges,load=true){
	Global gesINI,LastGesture,WB
	GUI,gesLearn:Destroy
	GUI,gesLearn:Default
;	GUI,gesLearn:Add,Picture,,% MG_Review_SaveImg()
	;Gui Add, ActiveX, xm w300 h300 vWB, Shell.Explorer
	;ComObjConnect(WB, WB_events)
	GUI,gesLearn:Add,Edit,w200 ReadOnly,% MG_Say(LastGesture)
	GUI,gesLearn:Add,Edit,w200 
	GUI,gesLearn:Add,Button,w100 h24 gButton_MG_Review,回放(&R)
	GUI,gesLearn:Add,Button,w100 h24 gButton_MG_Learn,学习(&L)
	GUI,gesLearn:Add,Button,w100 h24 gButton_MG_Save,保存画法(&L)
	GUI,gesLearn:Add,Button,w100 h24 gButton_MG_Load,加载画法(&L)
	GUI,gesLearn:Show
	;if load
	;WB.Navigate(MG_Review_SaveImg())
}
class WB_events
{
    NavigateComplete2(wb, NewURL)
    {
        GuiControl,, URL, %NewURL%  ; 更新 URL 编辑控件.
    }
}
Button_MG_Learn:
	GUI,gesLearn:Default
	GUIControlGet,name,,Edit2
	StringLower, name, name,T
	GZ_WriteName(LastGesture,Name)
	GUI,gesLearn:Destroy
return
Button_MG_Review:
	MG_Review()
return
Button_MG_Save:
	GUI,gesLearn:Default
	GUIControlGet,name,,Edit2
	If RegExMatch(name,"^[\s\t]*$")
		return
	StringLower, name, name,T
	MG_Review_Save(name)
return
Button_MG_Load:
	GUI,gesLearn:Default
	GUIControlGet,name,,Edit2
	If RegExMatch(name,"^[\s\t]*$")
		return
	StringLower, name, name,T
	MG_Review_Load(name)
	MG_Review()
return


;字符串转二进制
StrToBin(Str) {
XMLDOM:=ComObjCreate("Microsoft.XMLDOM")
xmlver:="<?xml version=`"`"1.0`"`"?>"
XMLDOM.loadXML(xmlver)
Pic:=XMLDOM.createElement("pic")
Pic.dataType:="bin.hex"
pic.nodeTypedValue := Str
StrToByte := pic.nodeTypedValue
return StrToByte
}


; 数据流保存为文件
BYTE_TO_FILE(body, filePath){
  Stream := ComObjCreate("Adodb.Stream")
  Stream.Type := 1
  Stream.Open()
  Stream.Write(body)
  Stream.SaveToFile(filePath,2) ;文件存在的就覆盖
  Stream.Close()
}

; LoadCUR {{{2
LoadCUR:
Cross_CUR:="000002000100202002000F00100034010000160000002800000020000000400000000100010000000000800000000000000000000000020000000200000000000000FFFFFF000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF83FFFFFE6CFFFFFD837FFFFBEFBFFFF783DFFFF7EFDFFFEAC6AFFFEABAAFFFE0280FFFEABAAFFFEAC6AFFFF7EFDFFFF783DFFFFBEFBFFFFD837FFFFE6CFFFFFF83FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF28000000"
Full_ico:="0000010001002020100000000000E8020000160000002800000020000000400000000100040000000000000200000000000000000000100000001000000000000000000080000080000000808000800000008000800080800000C0C0C000808080000000FF0000FF000000FFFF00FF000000FF00FF00FFFF0000FFFFFF00000000000000000000000000000000000000000000000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFF000FFFFFFFFFFFFFFFFFFFFFFFFFFFFF000FFFFFFFFFFFF00000FFFFFFFFFFFF000FFFFFFFFFF00FF0FF00FFFFFFFFFF000FFFFFFFFF0FF00000FF0FFFFFFFFF000FFFFFFFF0FFFFF0FFFFF0FFFFFFFF000FFFFFFF0FFFF00000FFFF0FFFFFFF000FFFFFFF0FFFFFF0FFFFFF0FFFFFFF000FFFFFF0F0F0FF000FF0F0F0FFFFFF000FFFFFF0F0F0F0FFF0F0F0F0FFFFFF000FFFFFF0000000F0F0000000FFFFFF000FFFFFF0F0F0F0FFF0F0F0F0FFFFFF000FFFFFF0F0F0FF000FF0F0F0FFFFFF000FFFFFFF0FFFFFF0FFFFFF0FFFFFFF000FFFFFFF0FFFF00000FFFF0FFFFFFF000FFFFFFFF0FFFFF0FFFFF0FFFFFFFF000FFFFFFFFF0FF00000FF0FFFFFFFFF000FFFFFFFFFF00FF0FF00FFFFFFFFFF000FFFFFFFFFFFF00000FFFFFFFFFFFF000FFFFFFFFFFFFFFFFFFFFFFFFFFFFF000FFFFFFFFFFFFFFFFFFFFFFFFFFFFF000FFFFFFFFFFFFFFFFFFFFFFFFFFFFF000000000000000000000000000000000007770CCCCCCCCCCCCCCCCCCCCC07770007070CCCCCCCCCCCCCCCCCCCCC07070007770CCCCCCCCCCCCCCCCCCCCC0777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000FFFFFFFF80000000800000008000000080000000800000008000000080000000800000008000000080000000800000008000000080000000800000008000000080000000800000008000000080000000800000008000000080000000800000008000000080000000800000008000000080000000FFFFFFFFFFFFFFFFFFFFFFFF"
Null_ico:="0000010001002020100000000000E8020000160000002800000020000000400000000100040000000000000200000000000000000000100000001000000000000000000080000080000000808000800000008000800080800000C0C0C000808080000000FF0000FF000000FFFF00FF000000FF00FF00FFFF0000FFFFFF00000000000000000000000000000000000000000000000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFF000FFFFFFFFFFFFFFFFFFFFFFFFFFFFF000FFFFFFFFFFFFFFFFFFFFFFFFFFFFF000FFFFFFFFFFFFFFFFFFFFFFFFFFFFF000FFFFFFFFFFFFFFFFFFFFFFFFFFFFF000FFFFFFFFFFFFFFFFFFFFFFFFFFFFF000FFFFFFFFFFFFFFFFFFFFFFFFFFFFF000FFFFFFFFFFFFFFFFFFFFFFFFFFFFF000FFFFFFFFFFFFFFFFFFFFFFFFFFFFF000FFFFFFFFFFFFFFFFFFFFFFFFFFFFF000FFFFFFFFFFFFFFFFFFFFFFFFFFFFF000FFFFFFFFFFFFFFFFFFFFFFFFFFFFF000FFFFFFFFFFFFFFFFFFFFFFFFFFFFF000FFFFFFFFFFFFFFFFFFFFFFFFFFFFF000FFFFFFFFFFFFFFFFFFFFFFFFFFFFF000FFFFFFFFFFFFFFFFFFFFFFFFFFFFF000FFFFFFFFFFFFFFFFFFFFFFFFFFFFF000FFFFFFFFFFFFFFFFFFFFFFFFFFFFF000FFFFFFFFFFFFFFFFFFFFFFFFFFFFF000FFFFFFFFFFFFFFFFFFFFFFFFFFFFF000FFFFFFFFFFFFFFFFFFFFFFFFFFFFF000FFFFFFFFFFFFFFFFFFFFFFFFFFFFF000000000000000000000000000000000007770CCCCCCCCCCCCCCCCCCCCC07770007070CCCCCCCCCCCCCCCCCCCCC07070007770CCCCCCCCCCCCCCCCCCCCC0777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000FFFFFFFF80000000800000008000000080000000800000008000000080000000800000008000000080000000800000008000000080000000800000008000000080000000800000008000000080000000800000008000000080000000800000008000000080000000800000008000000080000000FFFFFFFFFFFFFFFFFFFFFFFF"

Cross_CUR_File:= A_Temp "\Cross.CUR"
Full_ico_File := A_Temp "\Full.ico"
Null_ico_File := A_Temp "\Null.ico"

BYTE_TO_FILE(StrToBin(Full_ico),Full_ico_File)
BYTE_TO_FILE(StrToBin(Cross_CUR),Cross_CUR_File)
BYTE_TO_FILE(StrToBin(Null_ico),Null_ico_File)

return



; LoadHK {{{2
LoadHK:
	Hotkey, IfWinActive,ahk_id %hGUI%
	Hotkey, ^s ,HK
	Hotkey, ^e ,HK
	Hotkey, ^w ,HK
	Hotkey, ^q ,HK
return


; LoadToolbar {{{2
LoadToolbar:
	If configINI.GetValue("config","tree colum viewer")
		hToolbar := Toolbar_Add(hGUI,"ToolbarMenu","flat list tooltips",1,"x460 y30 w320 h30")
	Else
		hToolbar := Toolbar_Add(hGUI,"ToolbarMenu","flat list tooltips",1,"x210 y214 w370 h30")
	hILSec := IL_Create(10,10,0)
	IL_Add(hILSec,A_ScriptDir "\GestureZ.exe" ,5)
	IL_Add(hILSec,A_ScriptDir "\GestureZ.exe" ,3)
	IL_Add(hILSec,A_ScriptDir "\GestureZ.exe" ,4)
	IL_Add(hILSec,A_ScriptDir "\GestureZ.exe" ,6)
	Toolbar_SetImageList(hToolbar,hILSec)
  Toolbar_Insert(hToolbar,Language.GetValue(Lang,"Open") "(Ctrl+Q),1,,autosize,100")
  Toolbar_Insert(hToolbar,Language.GetValue(Lang,"Save") "(Ctrl+S),2,,autosize,101")
  Toolbar_Insert(hToolbar,Language.GetValue(Lang,"OutSide Editor") "(Ctrl+E),3,,autosize,102")
  Toolbar_Insert(hToolbar,Language.GetValue(Lang,"Plugin") "(Ctrl+W),4,,dropdown,103")
return

; LoadSCI {{{2
LoadSCI:
If configINI.GetValue("config","tree colum viewer")
	SCI.Add(hGui, 460, 64, 320, 380, A_ScriptDir "\Lib\SciLexer.dll")
Else
	SCI.Add(hGui, 210, 250, 370, 200, A_ScriptDir "\Lib\SciLexer.dll")
Dir=
(
#allowsamelinecomments #clipboardtimeout #commentflag #errorstdout #escapechar #hotkeyinterval
#hotkeymodifiertimeout #hotstring #if #iftimeout #ifwinactive #ifwinexist #include #includeagain
#installkeybdhook #installmousehook #keyhistory #ltrim #maxhotkeysperinterval #maxmem #maxthreads
#maxthreadsbuffer #maxthreadsperhotkey #menumaskkey #noenv #notrayicon #persistent #singleinstance
#usehook #warn #winactivateforce
)

Com=
(
autotrim blockinput clipwait control controlclick controlfocus controlget controlgetfocus
controlgetpos controlgettext controlmove controlsend controlsendraw controlsettext coordmode
critical detecthiddentext detecthiddenwindows drive driveget drivespacefree edit endrepeat envadd
envdiv envget envmult envset envsub envupdate fileappend filecopy filecopydir filecreatedir
filecreateshortcut filedelete filegetattrib filegetshortcut filegetsize filegettime filegetversion
fileinstall filemove filemovedir fileread filereadline filerecycle filerecycleempty fileremovedir
fileselectfile fileselectfolder filesetattrib filesettime formattime getkeystate groupactivate
groupadd groupclose groupdeactivate gui guicontrol guicontrolget hideautoitwin hotkey if ifequal
ifexist ifgreater ifgreaterorequal ifinstring ifless iflessorequal ifmsgbox ifnotequal ifnotexist
ifnotinstring ifwinactive ifwinexist ifwinnotactive ifwinnotexist imagesearch inidelete iniread
iniwrite input inputbox keyhistory keywait listhotkeys listlines listvars menu mouseclick
mouseclickdrag mousegetpos mousemove msgbox outputdebug pixelgetcolor pixelsearch postmessage
process progress random regdelete regread regwrite reload run runas runwait send sendevent
sendinput sendmessage sendmode sendplay sendraw setbatchlines setcapslockstate setcontroldelay
setdefaultmousespeed setenv setformat setkeydelay setmousedelay setnumlockstate setscrolllockstate
setstorecapslockmode settitlematchmode setwindelay setworkingdir shutdown sort soundbeep soundget
soundgetwavevolume soundplay soundset soundsetwavevolume splashimage splashtextoff splashtexton
splitpath statusbargettext statusbarwait stringcasesense stringgetpos stringleft stringlen
stringlower stringmid stringreplace stringright stringsplit stringtrimleft stringtrimright
stringupper sysget thread tooltip transform traytip urldownloadtofile winactivate winactivatebottom
winclose winget wingetactivestats wingetactivetitle wingetclass wingetpos wingettext wingettitle
winhide winkill winmaximize winmenuselectitem winminimize winminimizeall winminimizeallundo winmove
winrestore winset winsettitle winshow winwait winwaitactive winwaitclose winwaitnotactive
fileencoding
)

Param=
(
ltrim rtrim join ahk_id ahk_pid ahk_class ahk_group processname minmax controllist statuscd
filesystem setlabel alwaysontop mainwindow nomainwindow useerrorlevel altsubmit hscroll vscroll
imagelist wantctrla wantf2 vis visfirst wantreturn backgroundtrans minimizebox maximizebox
sysmenu toolwindow exstyle check3 checkedgray readonly notab lastfound lastfoundexist alttab
shiftalttab alttabmenu alttabandmenu alttabmenudismiss controllisthwnd hwnd deref pow bitnot
bitand bitor bitxor bitshiftleft bitshiftright sendandmouse mousemove mousemoveoff
hkey_local_machine hkey_users hkey_current_user hkey_classes_root hkey_current_config hklm hku
hkcu hkcr hkcc reg_sz reg_expand_sz reg_multi_sz reg_dword reg_qword reg_binary reg_link
reg_resource_list reg_full_resource_descriptor caret reg_resource_requirements_list
reg_dword_big_endian regex pixel mouse screen relative rgb low belownormal normal abovenormal
high realtime between contains in is integer float number digit xdigit alpha upper lower alnum
time date not or and topmost top bottom transparent transcolor redraw region id idlast count
list capacity eject lock unlock label serial type status seconds minutes hours days read parse
logoff close error single shutdown menu exit reload tray add rename check uncheck togglecheck
enable disable toggleenable default nodefault standard nostandard color delete deleteall icon
noicon tip click show edit progress hotkey text picture pic groupbox button checkbox radio
dropdownlist ddl combobox statusbar treeview listbox listview datetime monthcal updown slider
tab tab2 iconsmall tile report sortdesc nosort nosorthdr grid hdr autosize range xm ym ys xs xp
yp font resize owner submit nohide minimize maximize restore noactivate na cancel destroy
center margin owndialogs guiescape guiclose guisize guicontextmenu guidropfiles tabstop section
wrap border top bottom buttons expand first lines number uppercase lowercase limit password
multi group background bold italic strike underline norm theme caption delimiter flash style
checked password hidden left right center section move focus hide choose choosestring text pos
enabled disabled visible notimers interrupt priority waitclose unicode tocodepage fromcodepage
yes no ok cancel abort retry ignore force on off all send wanttab monitorcount monitorprimary
monitorname monitorworkarea pid base useunsetlocal useunsetglobal localsameasglobal str astr wstr
int64 int short char uint64 uint ushort uchar float double int64p intp shortp charp uint64p uintp
ushortp ucharp floatp doublep ptr
)

Flow=
(
break continue else exit exitapp gosub goto loop onexit pause repeat return settimer sleep
suspend static global local byref while until for
)

Fun=
(
abs acos asc asin atan ceil chr cos dllcall exp fileexist floor getkeystate numget numput
registercallback il_add il_create il_destroy instr islabel isfunc ln log lv_add lv_delete
lv_deletecol lv_getcount lv_getnext lv_gettext lv_insert lv_insertcol lv_modify lv_modifycol
lv_setimagelist mod onmessage round regexmatch regexreplace sb_seticon sb_setparts sb_settext
sin sqrt strlen substr tan tv_add tv_delete tv_getchild tv_getcount tv_getnext tv_get tv_getparent
tv_getprev tv_getselection tv_gettext tv_modify varsetcapacity winactive winexist trim ltrim rtrim
fileopen strget strput object isobject objinsert objremove objminindex objmaxindex objsetcapacity
objgetcapacity objgetaddress objnewenum objaddref objrelease objclone _insert _remove _minindex
_maxindex _setcapacity _getcapacity _getaddress _newenum _addref _release _clone comobjcreate
comobjget comobjconnect comobjerror comobjactive comobjenwrap comobjunwrap comobjparameter
comobjmissing comobjtype comobjvalue comobjarray
)

BIVar=
(
a_ahkpath a_ahkversion a_appdata a_appdatacommon a_autotrim a_batchlines a_caretx a_carety
a_computername a_controldelay a_cursor a_dd a_ddd a_dddd a_defaultmousespeed a_desktop
a_desktopcommon a_detecthiddentext a_detecthiddenwindows a_endchar a_eventinfo a_exitreason
a_formatfloat a_formatinteger a_gui a_guievent a_guicontrol a_guicontrolevent a_guiheight
a_guiwidth a_guix a_guiy a_hour a_iconfile a_iconhidden a_iconnumber a_icontip a_index a_ipaddress1
a_ipaddress2 a_ipaddress3 a_ipaddress4 a_isadmin a_iscompiled a_issuspended a_keydelay a_language
a_lasterror a_linefile a_linenumber a_loopfield a_loopfileattrib a_loopfiledir a_loopfileext
a_loopfilefullpath a_loopfilelongpath a_loopfilename a_loopfileshortname a_loopfileshortpath
a_loopfilesize a_loopfilesizekb a_loopfilesizemb a_loopfiletimeaccessed a_loopfiletimecreated
a_loopfiletimemodified a_loopreadline a_loopregkey a_loopregname a_loopregsubkey
a_loopregtimemodified a_loopregtype a_mday a_min a_mm a_mmm a_mmmm a_mon a_mousedelay a_msec
a_mydocuments a_now a_nowutc a_numbatchlines a_ostype a_osversion a_priorhotkey a_programfiles
a_programs a_programscommon a_screenheight a_screenwidth a_scriptdir a_scriptfullpath a_scriptname
a_sec a_space a_startmenu a_startmenucommon a_startup a_startupcommon a_stringcasesense a_tab a_temp
a_thishotkey a_thismenu a_thismenuitem a_thismenuitempos a_tickcount a_timeidle a_timeidlephysical
a_timesincepriorhotkey a_timesincethishotkey a_titlematchmode a_titlematchmodespeed a_username
a_wday a_windelay a_windir a_workingdir a_yday a_year a_yweek a_yyyy clipboard clipboardall comspec
programfiles a_thisfunc a_thislabel a_ispaused a_iscritical a_isunicode a_ptrsize errorlevel
true false
)

Keys=
(
shift lshift rshift alt lalt ralt control lcontrol rcontrol ctrl lctrl rctrl lwin rwin appskey
altdown altup shiftdown shiftup ctrldown ctrlup lwindown lwinup rwindown rwinup lbutton rbutton
mbutton wheelup wheeldown xbutton1 xbutton2 joy1 joy2 joy3 joy4 joy5 joy6 joy7 joy8 joy9 joy10 joy11
joy12 joy13 joy14 joy15 joy16 joy17 joy18 joy19 joy20 joy21 joy22 joy23 joy24 joy25 joy26 joy27
joy28 joy29 joy30 joy31 joy32 joyx joyy joyz joyr joyu joyv joypov joyname joybuttons joyaxes
joyinfo space tab enter escape esc backspace bs delete del insert ins pgup pgdn home end up down
left right printscreen ctrlbreak pause scrolllock capslock numlock numpad0 numpad1 numpad2 numpad3
numpad4 numpad5 numpad6 numpad7 numpad8 numpad9 numpadmult numpadadd numpadsub numpaddiv numpaddot
numpaddel numpadins numpadclear numpadup numpaddown numpadleft numpadright numpadhome numpadend
numpadpgup numpadpgdn numpadenter f1 f2 f3 f4 f5 f6 f7 f8 f9 f10 f11 f12 f13 f14 f15 f16 f17 f18 f19
f20 f21 f22 f23 f24 browser_back browser_forward browser_refresh browser_stop browser_search
browser_favorites browser_home volume_mute volume_down volume_up media_next media_prev media_stop
media_play_pause launch_mail launch_media launch_app1 launch_app2 blind click raw wheelleft
wheelright
)

UD1 =
UD2 =

sci.Notify := "SCI_NOTIFY"
;sci.SetWrapMode(true)
SCI.SETHSCROLLBAR(1)
SCI.SETSCROLLWIDTH(500)
SCI.SetMarginWidthN(1, 0) ; this removes the left margin
SCI.CLEARCMDKEY(Asc("S")+(SCMOD_CTRL<<16))
SCI.CLEARCMDKEY(Asc("Q")+(SCMOD_CTRL<<16))
SCI.CLEARCMDKEY(Asc("W")+(SCMOD_CTRL<<16))
SCI.CLEARCMDKEY(Asc("G")+(SCMOD_CTRL<<16))
SCI.CLEARCMDKEY(Asc("F")+(SCMOD_CTRL<<16))
SCI.CLEARCMDKEY(Asc("H")+(SCMOD_CTRL<<16))
SCI.CLEARCMDKEY(Asc("H")+(SCMOD_CTRL<<16))
SCI.CLEARCMDKEY(Asc("E")+(SCMOD_CTRL<<16))
SCI.CLEARCMDKEY(Asc("R")+(SCMOD_CTRL<<16))
SCI.CLEARCMDKEY(Asc("O")+(SCMOD_CTRL<<16))
SCI.CLEARCMDKEY(Asc("P")+(SCMOD_CTRL<<16))
SCI.CLEARCMDKEY(Asc("K")+(SCMOD_CTRL<<16))
SCI.CLEARCMDKEY(Asc("N")+(SCMOD_CTRL<<16))
SCI.CLEARCMDKEY(Asc("B")+(SCMOD_CTRL<<16))
SCI.USEPOPUP(0)
; Set up Margin Symbols
sci.MarkerDefine(SC_MARKNUM_FOLDER, SC_MARK_BOXPLUS)
sci.MarkerDefine(SC_MARKNUM_FOLDEROPEN, SC_MARK_BOXMINUS)
sci.MarkerDefine(SC_MARKNUM_FOLDERSUB, SC_MARK_VLINE)
sci.MarkerDefine(SC_MARKNUM_FOLDERTAIL, SC_MARK_LCORNER)
sci.MarkerDefine(SC_MARKNUM_FOLDEREND, SC_MARK_BOXPLUSCONNECTED)
sci.MarkerDefine(SC_MARKNUM_FOLDEROPENMID, SC_MARK_BOXMINUSCONNECTED)
sci.MarkerDefine(SC_MARKNUM_FOLDERMIDTAIL, SC_MARK_TCORNER)

; Change margin symbols colors
sci.MarkerSetFore(SC_MARKNUM_FOLDER , 0xFFFFFF)
sci.MarkerSetBack(SC_MARKNUM_FOLDER , 0x5A5A5A)
sci.MarkerSetFore(SC_MARKNUM_FOLDEROPEN , 0xFFFFFF)
sci.MarkerSetBack(SC_MARKNUM_FOLDEROPEN , 0x5A5A5A)
sci.MarkerSetFore(SC_MARKNUM_FOLDERSUB , 0xFFFFFF)
sci.MarkerSetBack(SC_MARKNUM_FOLDERSUB , 0x5A5A5A)
sci.MarkerSetFore(SC_MARKNUM_FOLDERTAIL , 0xFFFFFF)
sci.MarkerSetBack(SC_MARKNUM_FOLDERTAIL , 0x5A5A5A)
sci.MarkerSetFore(SC_MARKNUM_FOLDEREND , 0xFFFFFF)
sci.MarkerSetBack(SC_MARKNUM_FOLDEREND , 0x5A5A5A)
sci.MarkerSetFore(SC_MARKNUM_FOLDEROPENMID, 0xFFFFFF)
sci.MarkerSetBack(SC_MARKNUM_FOLDEROPENMID, 0x5A5A5A)
sci.MarkerSetFore(SC_MARKNUM_FOLDERMIDTAIL, 0xFFFFFF)
sci.MarkerSetBack(SC_MARKNUM_FOLDERMIDTAIL, 0x5A5A5A)
sci.SetFoldFlags(SC_FOLDFLAG_LEVELNUMBERS)

; Set Autohotkey Lexer and default options
sci.SetLexer(SCLEX_AHKL)
sci.StyleSetFont(STYLE_DEFAULT, "Courier New"), sci.StyleSetSize(STYLE_DEFAULT, 10), sci.StyleClearAll()

; Set Style Colors
sci.StyleSetFore(SCE_AHKL_IDENTIFIER , 0x000000)

sci.StyleSetFore(SCE_AHKL_COMMENTDOC , 0x008888)
sci.StyleSetFore(SCE_AHKL_COMMENTLINE , 0x008800)
sci.StyleSetFore(SCE_AHKL_COMMENTBLOCK , 0x008800), sci.StyleSetBold(SCE_AHKL_COMMENTBLOCK, true)
sci.StyleSetFore(SCE_AHKL_COMMENTKEYWORD , 0xA50000), sci.StyleSetBold(SCE_AHKL_COMMENTKEYWORD, true)
sci.StyleSetFore(SCE_AHKL_STRING , 0xA2A2A2)
sci.StyleSetFore(SCE_AHKL_STRINGOPTS , 0x00EEEE)
sci.StyleSetFore(SCE_AHKL_STRINGBLOCK , 0xA2A2A2), sci.StyleSetBold(SCE_AHKL_STRINGBLOCK, true)
sci.StyleSetFore(SCE_AHKL_STRINGCOMMENT , 0xFF0000)
sci.StyleSetFore(SCE_AHKL_LABEL , 0x0000DD)
sci.StyleSetFore(SCE_AHKL_HOTKEY , 0x00AADD)
sci.StyleSetFore(SCE_AHKL_HOTSTRING , 0x00BBBB)
sci.StyleSetFore(SCE_AHKL_HOTSTRINGOPT , 0x990099)
sci.StyleSetFore(SCE_AHKL_HEXNUMBER , 0x880088)
sci.StyleSetFore(SCE_AHKL_DECNUMBER , 0xFF9000)
sci.StyleSetFore(SCE_AHKL_VAR , 0xFF9000)
sci.StyleSetFore(SCE_AHKL_VARREF , 0x990055)
sci.StyleSetFore(SCE_AHKL_OBJECT , 0x008888)
sci.StyleSetFore(SCE_AHKL_USERFUNCTION , 0x0000DD)

sci.StyleSetFore(SCE_AHKL_DIRECTIVE , 0x4A0000), sci.StyleSetBold(SCE_AHKL_DIRECTIVE, true)
sci.StyleSetFore(SCE_AHKL_COMMAND , 0x0000DD), sci.StyleSetBold(SCE_AHKL_COMMAND, true)
sci.StyleSetFore(SCE_AHKL_PARAM , 0x0085DD)
sci.StyleSetFore(SCE_AHKL_CONTROLFLOW , 0x0000DD)
sci.StyleSetFore(SCE_AHKL_BUILTINFUNCTION, 0xDD00DD)
sci.StyleSetFore(SCE_AHKL_BUILTINVAR , 0xEE3010), sci.StyleSetBold(SCE_AHKL_BUILTINVAR, true)
sci.StyleSetFore(SCE_AHKL_KEY , 0xA2A2A2), sci.StyleSetBold(SCE_AHKL_KEY, true), sci.StyleSetItalic(SCE_AHKL_KEY, true)
sci.StyleSetFore(SCE_AHKL_USERDEFINED1 , 0x000000)
sci.StyleSetFore(SCE_AHKL_USERDEFINED2 , 0x000000)

sci.StyleSetFore(SCE_AHKL_ESCAPESEQ , 0x660000), sci.StyleSetItalic(SCE_AHKL_ESCAPESEQ, true)
sci.StyleSetFore(SCE_AHKL_ERROR , 0xFF0000)


; Set up keyword lists, the variables are set at the beginning of the code
Loop 9
{
lstN:=a_index-1

sci.SetKeywords(lstN, ( lstN = 0 ? Dir
                      : lstN = 1 ? Com
                      : lstN = 2 ? Param
                      : lstN = 3 ? Flow
                      : lstN = 4 ? Fun
                      : lstN = 5 ? BIVar
                      : lstN = 6 ? Keys
                      : lstN = 7 ? UD1
                      : lstN = 8 ? UD2
                      : null))
}
return

; SCI_NOTIFY(wParam, lParam, msg, hwnd, sciObj) {{{2
SCI_NOTIFY(wParam, lParam, msg, hwnd, sciObj) {
	Global configINI
	If ( sciObj.scnCode = 2007 )
		If ConfigINI.GetValue("config","AutoSave")
			config_ActionSave()
}
; HotkeyFunc {{{2
HK:
	HK_func()
return
HK_func(){
	Global SCI,configINI,hToolbar
	If A_ThisHotkey = ^s
		config_ActionSave()
	If A_ThisHotkey = ^e
		Config_ActionEdit()
	If A_ThisHotkey = ^q
		Config_ActionOpen()
	If A_ThisHotkey = ^w
		Config_ActionPluginMenu(hToolbar,4)
}

; ToolbarMenu(hCtrl,Event,Txt,Pos,ID) {{{2
ToolbarMenu(hCtrl,Event,Txt,Pos,ID){
	If Event = Click
	{
		  If id = 100
				config_ActionOpen()
		  If id = 101
				config_ActionSave()
		  If id = 102 
				Config_ActionEdit()
			If id = 103
				Config_ActionPluginMenu(hCtrl,pos)
	}
	If Event = Menu
		Config_ActionPluginMenu(hCtrl,pos)
}

Config_ActionPluginMenu(hCtrl,pos)
{
	controlGetPos,x,y,,,,ahk_id %hCtrl%
	rect := Toolbar_GetRect(hCtrl,Pos)
	Loop,Parse,Rect,%A_Space%
	{
		If A_Index = 1
			x := x + A_LoopField
		If A_Index = 4
			y := y + A_LoopField
	}
	Menu,PluginMenu,Add
	Menu,PluginMenu,DeleteAll
	Loop,% A_ScriptDir "\Plugin\*.ahk"
	{
		SplitPath,A_LoopFileName,,,,m
		Menu,PluginMenu,Add,%m%,Config_ActionPlugin
	}
	Menu,PluginMenu,show,%x%,%y%
}
; Config_ActionOpen() {{{2
Config_ActionOpen()
{
	Global SCI,hGUI
	GUI,GesConfig:Default
	GUI,GesConfig:TreeView,SysTreeView321
	If TV_GetParent(id := TV_GetSelection())
	{
		TV_GetText(i,id)
		FileSelectFile,file,1,%A_MyDocuments%,% Lang("Open"),*.ahk
		FileRead,Text,%file%
		SCI.SetText(unused,Text)
		FileDelete,%A_ScriptDir%\Config\Commands\%i%.ahk
		FileAppend,%text%,%A_ScriptDir%\Config\Commands\%i%.ahk
	}
}
; Config_ActionEdit() {{{2
Config_ActionEdit()
{
	Global configINI,SCI
	GUI,GesConfig:Default
	GUI,GesConfig:TreeView,SysTreeView321
	If TV_GetParent(id := TV_GetSelection())
	{
		TV_GetText(i,id)
		Editor := configINI.GetValue("config","Editor")
		If not FileExist(A_ScriptDir "\Config\Commands\" i ".ahk")
			return
		parms  := RegExReplace(configINI.GetValue("config","Editor Param"),"%1",A_ScriptDir "\Config\Commands\" i ".ahk")
		runWait % Editor " " parms
		FileRead,newText,%A_ScriptDir%\Config\Commands\%i%.ahk
		SCI.SetText(unused,newText)
	}
}
; config_ActionSave() {{{2
config_ActionSave(){
	Global SCI,hGUI
	GUI,GesConfig:Default
	GUI,GesConfig:TreeView,SysTreeView321
	If TV_GetParent(id := TV_GetSelection())
	{
		TV_GetText(i,id)
		count := SCI.GetLength()
		VarSetCapacity(text,count)
		SCI.GetText(Count+1,&text)
		FileDelete,%A_ScriptDir%\Config\Commands\%i%.ahk
		FileAppend,%text%,%A_ScriptDir%\Config\Commands\%i%.ahk
	}
}
; config_ActionPlugin() {{{2
config_ActionPlugin:
	config_ActionPlugin()
return
config_ActionPlugin(){
	file := A_ScriptDir "\Plugin\" A_ThisMenuItem ".ahk"
	If not FileExist(file)
		return
	Run % A_ScriptDir "\lib\Autohotkey.exe " """" file """"
}

lang(l){
	Global Language,Lang
	return Language.GetValue(Lang,l)
}
; ToMatch(str) {{{2
; 正则表达式转义
ToMatch(str)
{
	str := RegExReplace(str,"\+|\?|\.|\*|\{|\}|\(|\)|\||\^|\$|\[|\]|\\","\$0")
	Return RegExReplace(str,"\s","\s")
}

; GetStringLen(string) {{{2
GetStringLen(string)
{
	;[^\x00-\xff]
	count := 0
	Loop,Parse,String
		If RegExMatch(A_LoopField,"[^\x00-\xff]")
			Count += 2
		Else
			Count++
	return Count
}

/********************************************
* ARGB_GET(ARGB, item)
*
* ARGB: ARGB value
*
* item: A,R,G,B -> field you want
*
*********************************************
*/
ARGB_GET(ARGB, item){

    if(item = "A"){
        return (ARGB >> 24) & 0xFF
    }else if ( item = "R"){
        return (ARGB >> 16) & 0xFF
    }else if (item = "G"){
        return (ARGB >> 8) & 0xFF
    }else if (item = "B"){
        return (ARGB) & 0xFF
    }
}


/********************************************
* ARGB(A,R,G,B)
*
* returns the ARGB value
*
*********************************************
*/
ARGB(A,R,G,B){
    ;---- ensure that the values are max 0xFF (255)
    A := A & 0xFF, R := R & 0xFF
    G := G & 0xFF, B := B & 0xFF
    ;---------------------------------------------
    return ((((((R << 16) | (G << 8)) | B) | (A << 24))) & 0xFFFFFFFF)
}

/********************************************
* ARGB(A,RGB)
*
* returns the ARGB value from RGB
*
*********************************************
*/
ARGB_FromRGB(A,RGB){
    A := A & 0xFF, RGB := RGB & 0xFFFFFF
    return ((RGB | (A << 24)) & 0xFFFFFFFF)
}


/********************************************
* ARGB(A,RGB)
*
* returns the ARGB value from BGR
*
*********************************************
*/
ARGB_FromBGR(A, BGR){
   return ARGB(A & 0xFF, BGR & 0xFF,(BGR >> 8) & 0xFF, (BGR >> 16) & 0xFF)
}

RGBtoHSV(RGB, byref h, byref s, byref v)
{
	_RGBtoHSV(ToFloat(ARGB_GET(RGB, "R")),  ToFloat(ARGB_GET(RGB, "G")),  ToFloat(ARGB_GET(RGB, "B")), h, s, v)
}

;adapted from http://www.cs.rit.edu/~ncs/color/t_convert.html
;// r,g,b values are from 0 to 1
;// h = [0,360], s = [0,1], v = [0,1]
;//      if s == 0, then h = -1 (undefined)
_RGBtoHSV(r,  g,  b, byref h, byref s, byref v)
{
   ;float min, max, delta
   min := Min(r, g, b)
   max := Max(r, g, b)
   v := max           ;// v
   delta := max - min
   if( max != 0 )
      s := delta / max      ;// s
   else {
      ;// r = g = b = 0      // s = 0, v is undefined
      s := 0
      h := -1
      return
   }
   if(r == max)
      h := (g - b) / delta      ;// between yellow & magenta
   else if(g == max)
      h := 2 + (b - r) / delta   ;// between cyan & yellow
   else
      h := 4 + (r - g) / delta   ;// between magenta & cyan
   h *= 60            ;// degrees
   if(h < 0)
      h += 360
}

Min(x,y,z){
	return x < y && x < z ? x : ( z > y ? y : z )	
}
Max(x,y,z){
	return x > y && x > z ? x : ( z < y ? y : z )	
}
;0-1
ToFloat(item){
   return 1 / 0xFF * item
}
