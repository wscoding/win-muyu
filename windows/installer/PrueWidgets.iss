; Prue Widgets — Windows 安装包脚本（Inno Setup）
;
; 原始脚本此前放在 test/build-demo.txt，且引用了已不存在的
; wooden_fish_for_windows.exe 与作者本机的绝对路径（E:\develop\muyu、
; C:\Users\...\Desktop\ls\4\）。这里迁到 windows/installer/ 并改为相对路径，
; 让脚本可以跟随仓库一起工作。
;
; 使用方式：
;   1. flutter build windows --release
;   2. 用 Inno Setup Compiler 打开本文件并 Compile
;   产物默认输出到仓库根的 release/ 目录。

#define MyAppName "Prue Widgets"
#define MyAppVersion "3.0.0"
#define MyAppPublisher "Wsoft, Inc."
#define MyAppURL "http://pw.0gg.cc/"
; 必须与 windows/CMakeLists.txt 里的 BINARY_NAME 一致
#define MyAppExeName "prue_widgets.exe"

#define ProjectRoot "..\.."

[Setup]
; NOTE: The value of AppId uniquely identifies this application. Do not use the same AppId value in installers for other applications.
; (To generate a new GUID, click Tools | Generate GUID inside the IDE.)
AppId={{E275CB8C-3C8C-4106-B5F9-F2E3B2F4595A}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\Prue Widgets
DisableProgramGroupPage=yes
; 这三个文件在原始工程里是作者本机路径，仓库中没有对应内容。
; 若要恢复安装前后的说明页，请把文件放进 windows/installer/ 并取消注释。
;LicenseFile=lie.txt
;InfoBeforeFile=bef.txt
;InfoAfterFile=aft.txt
; 仅当前用户安装，避免每次安装都要管理员权限
PrivilegesRequired=lowest
OutputDir={#ProjectRoot}\release
OutputBaseFilename=PrueWidgets-Setup
SetupIconFile=..\runner\resources\app_icon.ico
Compression=lzma
SolidCompression=yes
WizardStyle=modern
; 与 macos 侧的 LSMinimumSystemVersion 对齐
MinVersion=10.0

[Languages]
Name: "chinese"; MessagesFile: "compiler:Languages\Chinese.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#ProjectRoot}\build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#ProjectRoot}\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; NOTE: Don't use "Flags: ignoreversion" on any shared system files

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent