#define MyAppName      "Safira Assistant"
#define MyAppVersion   "1.0.0"
#define DockerInstaller "DockerDesktopInstaller.exe"

[Setup]
AppName={#MyAppName}
AppVersion={#MyAppVersion}
DefaultDirName={autopf}\Safira
DefaultGroupName={#MyAppName}
WizardStyle=modern
Compression=lzma2
SolidCompression=yes
OutputDir=userdocs:Safira Installer
OutputBaseFilename=SafiraSetup
InfoBeforeFile=welcome.txt
LicenseFile=license.txt
PrivilegesRequired=admin
ArchitecturesInstallIn64BitMode=x64
MinVersion=10.0
DisableProgramGroupPage=yes
ShowLanguageDialog=no
LanguageDetectionMethod=none
AppPublisher=Safira WAMGIA
AppPublisherURL=https://safira.ai
AppSupportURL=https://github.com/Safira-WAMGIA/issues

[Files]
Source: "compose\base.yml";               DestDir: "{app}\compose"; Flags: ignoreversion
Source: "compose\evolution_api.yml";      DestDir: "{app}\compose"; Flags: ignoreversion; Components: evolution_api
Source: "compose\instagrapi.yml";         DestDir: "{app}\compose"; Flags: ignoreversion; Components: instagrapi
Source: "compose\stt_whisper.yml";        DestDir: "{app}\compose"; Flags: ignoreversion; Components: stt
Source: "compose\tts_coqui.yml";          DestDir: "{app}\compose"; Flags: ignoreversion; Components: tts
Source: "compose\wiki.yml";               DestDir: "{app}\compose"; Flags: ignoreversion; Components: wiki
Source: "compose\redis.yml";              DestDir: "{app}\compose"; Flags: ignoreversion; Components: redis
Source: "compose\postgres.yml";           DestDir: "{app}\compose"; Flags: ignoreversion; Components: postgres
Source: "compose\prometheus.yml";         DestDir: "{app}\compose"; Flags: ignoreversion; Components: prometheus
Source: "compose\grafana.yml";            DestDir: "{app}\compose"; Flags: ignoreversion; Components: grafana
Source: "compose\ollama.yml";             DestDir: "{app}\compose"; Flags: ignoreversion; Components: ollama
Source: "scripts\post_install.bat";       DestDir: "{app}"; Flags: ignoreversion
Source: "{#DockerInstaller}";             DestDir: "{tmp}"; Flags: deleteafterinstall

[Dirs]
Name: "{app}\compose"

[Icons]
Name: "{group}\Safira Dashboard (Grafana)"; Filename: "http://localhost:3000"
Name: "{group}\Abrir n8n";                 Filename: "http://localhost:5678"
Name: "{group}\Pasta de Configuração";     Filename: "{app}"

[Types]
Name: "minima";        Description: "minima (Minimo possivel)"
Name: "basica";        Description: "Básica (n8n + Whatsapp)" 
Name: "basica2";       Description: "Básica + AI (n8n + Whatsapp + Olhama)" 
Name: "comunicacao";   Description: "Comunicação (Básica + Comunicações)"
Name: "metricas";      Description: "Metricas (Básica + Metricas)"
Name: "ai";            Description: "AI (Básica + AI)"
Name: "completa";      Description: "Completa (todos os módulos)"
Name: "personalizada"; Description: "Personalizada"; Flags: iscustom 

[Components]
Name: "Docker_Desktop";Description: "Docker Desktop";           Types:minima basica basica2 comunicacao metricas ai completa personalizada; ExtraDiskSpaceRequired: 524288000;
Name: "core";          Description: "n8n";                      Types:minima basica basica2 comunicacao metricas ai completa personalizada; ExtraDiskSpaceRequired: 262144000;
Name: "evolution_api"; Description: "Evolution API (Whatsapp)"; Types:basica basica2 comunicacao completa personalizada;                    ExtraDiskSpaceRequired: 125829120	; 
Name: "instagrapi";    Description: "Instagrapi (Instagram)";   Types:comunicacao completa personalizada;                                   ExtraDiskSpaceRequired: 272629760	;
Name: "domini_api";    Description: "Domini API (Linkedin)";    Types:comunicacao completa personalizada;                                   ExtraDiskSpaceRequired: 524288000;
Name: "shcross";       Description: "SHCross (TikTok)";         Types:comunicacao completa personalizada;                                   ExtraDiskSpaceRequired: 524288000;
Name: "traefik";       Description: "Traefik";                  Types:minima basica basica2 comunicacao metricas ai completa personalizada; ExtraDiskSpaceRequired: 524288000;
Name: "nginx";         Description: "Nginx";                    Types:completa personalizada;                                               ExtraDiskSpaceRequired: 650117120	;
Name: "wiki";          Description: "Wiki.js";                  Types:basica basica2 comunicacao metricas ai completa personalizada;        ExtraDiskSpaceRequired: 891289600	; 
Name: "redis";         Description: "Redis Cache";              Types:minima basica basica2 comunicacao metricas ai completa personalizada; ExtraDiskSpaceRequired: 1610612736	; 
Name: "postgres";      Description: "PostgreSQL";               Types:minima basica basica2 comunicacao metricas ai completa personalizada; ExtraDiskSpaceRequired: 650117120	; 
Name: "prometheus";    Description: "Prometheus";               Types:metricas completa personalizada;                                      ExtraDiskSpaceRequired: 8589934592	; 
Name: "grafana";       Description: "Grafana";                  Types:metricas completa personalizada;                                      ExtraDiskSpaceRequired: 1417339207	; 
Name: "ollama";        Description: "Ollama LLM Server";                     Types:basica2 ai completa personalizada;                       ExtraDiskSpaceRequired: 5368709120; 
Name: "tti";           Description: "Texto  -> Imagem (Stable Diffusion)";   Types:ai completa personalizada; ExtraDiskSpaceRequired: 10737418240 ;
Name: "ttv";           Description: "Texto  -> Video  (SVD XT / ModelScope)";Types:ai completa personalizada; ExtraDiskSpaceRequired: 16106127360 ;
Name: "tts";           Description: "Texto  -> Audio  (Coqui)";              Types:ai completa personalizada; ExtraDiskSpaceRequired: 20401094656	; 
Name: "stt";           Description: "Audio  -> Texto  (Whisper)";            Types:ai completa personalizada; ExtraDiskSpaceRequired: 1438814044	; 
Name: "vtt";           Description: "Video  -> Texto  (Whisper + BLIP-2)";   Types:ai completa personalizada; ExtraDiskSpaceRequired: 6442450944 ;
Name: "itt";           Description: "Imagem -> Texto  (LLaVA-1.6)";          Types:ai completa personalizada; ExtraDiskSpaceRequired: 8589934592 ;

[Tasks]
Name: "desktopicon"; Description: "Criar atalho na área de trabalho"; GroupDescription: "Extras:"; Flags: unchecked

[Run]
Filename: "{tmp}\{#DockerInstaller}"; \
  Parameters: "install --quiet"; \
  StatusMsg: "Instalando Docker Desktop..."; Flags: shellexec runhidden waituntilterminated; \
  Check: not IsDockerInstalled

Filename: "{cmd}"; \
  Parameters: "/C ""{app}\post_install.bat"" ""{app}"""; \
  Flags: runhidden; StatusMsg: "Configurando e iniciando Safira..."

[Code]
var
  ComposeArgs: String;
  EnvPage: TInputQueryWizardPage;

function IsDockerInstalled(): Boolean;
begin
  Result := RegKeyExists(HKLM64, 'SOFTWARE\Docker Inc.\Docker');
end;

function IsCompSelected(const Comp: String): Boolean;
begin
  Result := WizardIsComponentSelected(Comp);
end;

procedure BuildComposeArgs;
begin
  ComposeArgs := '-f "' + ExpandConstant('{app}\compose\base.yml') + '"';

  if IsCompSelected('evolution_api') then
    ComposeArgs := ComposeArgs + ' -f "' + ExpandConstant('{app}\compose\evolution_api.yml') + '"';
  if IsCompSelected('instagrapi') then
    ComposeArgs := ComposeArgs + ' -f "' + ExpandConstant('{app}\compose\instagrapi.yml') + '"';
  if IsCompSelected('stt') then
    ComposeArgs := ComposeArgs + ' -f "' + ExpandConstant('{app}\compose\stt.yml') + '"';
  if IsCompSelected('tts') then
    ComposeArgs := ComposeArgs + ' -f "' + ExpandConstant('{app}\compose\tts.yml') + '"';
  if IsCompSelected('wiki') then
    ComposeArgs := ComposeArgs + ' -f "' + ExpandConstant('{app}\compose\wiki.yml') + '"';
  if IsCompSelected('redis') then
    ComposeArgs := ComposeArgs + ' -f "' + ExpandConstant('{app}\compose\redis.yml') + '"';
  if IsCompSelected('postgres') then
    ComposeArgs := ComposeArgs + ' -f "' + ExpandConstant('{app}\compose\postgres.yml') + '"';
  if IsCompSelected('prometheus') then
    ComposeArgs := ComposeArgs + ' -f "' + ExpandConstant('{app}\compose\prometheus.yml') + '"';
  if IsCompSelected('grafana') then
    ComposeArgs := ComposeArgs + ' -f "' + ExpandConstant('{app}\compose\grafana.yml') + '"';
  if IsCompSelected('ollama') then
    ComposeArgs := ComposeArgs + ' -f "' + ExpandConstant('{app}\compose\ollama.yml') + '"';
end;

procedure InitializeWizard;
begin
  EnvPage := CreateInputQueryPage(wpSelectComponents,
    'Configurar Safira', 'Variáveis de ambiente',
    'Preencha os dados abaixo para gerar o arquivo .env:');

  EnvPage.Add('E-mail do admin:', False);
  EnvPage.Add('Senha do admin:',  True);
  EnvPage.Add('PostgreSQL password:', True);
  EnvPage.Add('Chave OpenAI (opcional):', False);
end;

procedure WriteEnvFile;
var
  L: TStringList;
begin
  L := TStringList.Create;
  try
    L.Add('SAFIRA_ADMIN_EMAIL='    + EnvPage.Values[0]);
    L.Add('SAFIRA_ADMIN_PASSWORD=' + EnvPage.Values[1]);
    L.Add('POSTGRES_PASSWORD='     + EnvPage.Values[2]);

    if EnvPage.Values[3] <> '' then
      L.Add('OPENAI_API_KEY=' + EnvPage.Values[3]);

    L.SaveToFile(ExpandConstant('{app}\.env'));
  finally
    L.Free;
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  RC: Integer;
begin
  if CurStep = ssPostInstall then
  begin
    WriteEnvFile;
    BuildComposeArgs;
    MsgBox('Baixando imagens Docker selecionadas. Isso pode levar alguns minutos...', mbInformation, MB_OK);
    Exec(ExpandConstant('{cmd}'), '/C docker compose ' + ComposeArgs + ' pull', '', SW_HIDE, ewWaitUntilTerminated, RC);
    Exec(ExpandConstant('{cmd}'), '/C docker compose ' + ComposeArgs + ' up -d',  '', SW_HIDE, ewWaitUntilTerminated, RC);
  end;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  if not IsDockerInstalled() then
    MsgBox('Docker Desktop não foi encontrado. Ele será instalado automaticamente.', mbInformation, MB_OK);
end;

[UninstallDelete]
Type: filesandordirs; Name: "{app}"
