
; 此代码由Hotkey插件产生
;功能：发送热键
Send,
;[全局通用]_Candy
#NoTrayIcon
Detecthiddenwindows,on
Controlsettext,Edit1,^mbutton,ahk_class AutoHotkeyGUI,__CandyCommand
