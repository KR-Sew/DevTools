
# 📊 Установка Office Online Server 2019 на Windows Server 2022

![Win ACME Version](https://img.shields.io/badge/Win_ACME-v2.2.0-blue)  
![Let's Encrypt](https://img.shields.io/badge/Powered_by-Let's_Encrypt-brightgreen)

## Подготовка
0. **Скачайте установочный пакет Office Online Server 2019** 📦

1. **Установка дополнений на Windows Server 2022** 📦  
   - Установите следующие роли на **Windows Server 2022**: 
   ```powershell
   Add-WindowsFeature Web-Server,Web-Mgmt-Tools,Web-Mgmt-Console,Web-WebServer,Web-Common-Http,Web-Default-Doc,Web-Static-Content,Web-Performance,Web-Stat-Compression,Web-Dyn-Compression,Web-Security,Web-Filtering,Web-Windows-Auth,Web-App-Dev,Web-Net-Ext45,Web-Asp-Net45,Web-ISAPI-Ext,Web-ISAPI-Filter,Web-Includes,NET-Framework-Features,NET-Framework-45-Features,NET-Framework-Core,NET-Framework-45-Core,NET-HTTP-Activation,NET-Non-HTTP-Activ,NET-WCF-HTTP-Activation45,Windows-Identity-Foundation,Server-Media-Foundation
   ```
   - Перезагрузите сервер 

2. **Установите дополнительные пакеты `Visual Studio`** 📦
   - Распространяемые пакеты [`Visual Studio C++ 2013 Redistributable x64`](https://www.microsoft.com/download/details.aspx?id=40784).
   - Распространяемые пакеты [`Visual Studio C++ 2015 Redistributable x64`](https://go.microsoft.com/fwlink/p/?LinkId=620071).

3. **Установите расширение** 📦
   - [`Microsoft Identity Model Extention`](https://go.microsoft.com/fwlink/p/?LinkId=620072).    

## Установка

1. **Запустите установку Office Online Server** 📦
   - Примите условия лиц.соглашения
   - Выберите папку для установки файлов **Office Online Server** 📦
   - По завершению установки **Office Online Server** нажмите кнопку закрыть

2. **Установите языковые пакеты для Office Online Server** 📦
    - Скачайте языковые пакеты **Office Online Server** из Центра загрузки [`Майкрософт`](https://go.microsoft.com/fwlink/p/?LinkId=798136)
    - Языковой пакет для [**Office Online Server**](https://www.microsoft.com/ru-ru/download/details.aspx?id=51963)
    - Запустите файл `wacserverlanguagepack.exe`.
    - Когда установка сервера **Office Online Server** завершится, нажмите кнопку `Закрыть`.

3. **Установите последнее исправление для Office Online Server** 📦
    - Выбирете язык и скачайте [`Security Update for Microsoft Office Online Server (KB5001973)`](https://www.microsoft.com/en-us/download/details.aspx?id=103285)
    - Запустите уствановку исправлений.         

## Дополнения


   Чтобы установить языковые пакеты после создания фермы **Office Online Server**, необходимо удалить сервер из фермы, установить на нем языковой пакет, а затем добавить сервер обратно в ферму.> Чтобы языковой пакет работал правильно, необходимо установить его на всех серверах фермы.

## Развертывание фермы Office Online Server ⚙️

1. Если **Microsoft PowerShell** не распознает командлет `New-OfficeWebAppsFarm` при его выполнении, возможно, вам потребуется импортировать модуль `OfficeWebApps`. Используйте следующую команду:
```powershell
 Import-Module -Name OfficeWebApps
```
---

  **Примечание**
   
  - Настоятельно рекомендуется использовать ПРОТОКОЛ **HTTPS (TLS)** независимо от среды, так как **Office Online Server** использует маркеры `OAuth` для взаимодействия с внешними службами, такими как **SharePoint** или **Exchange Server**. Маркеры `OAuth` содержат сведения, которые потенциально могут быть перехвачены и воспроизведены злоумышленником, предоставляя злоумышленнику те же права, что и пользователь, выполняющий запрос на Office Online Server.

## Создание фермы Office Online Server ⚙️
1. Выполните команду `New-OfficeWebAppsFarm`, чтобы создать новую ферму **Office Online Server**, состоящую из одного сервера, как показано в следующем примере.
 ```powershell
    New-OfficeWebAppsFarm -InternalURL "http://servername" -AllowHttp -EditingEnabled
 ```
   - `-InternalURL` — это имя сервера, на котором работает **Office Online Server**, например `http://servername`.
   - Параметр `-AllowHttp` настраивает ферму на использование протокола **HTTP**.
   - `EditingEnabled` включает редактирование в **Office Online** при использовании с **SharePoint Server**. Данный параметр не используется **Skype** для бизнеса **Server 2015** и **Exchange Server**, поскольку эти узлы не поддерживают редактирование.  
2. Проверка создания фермы **Office Online Server** ⚙️
    - Откройте **url** в браузере вида: `http://servername/hosting/discovery`
      Где ***servername*** имя созданной фермы **Office Online Server**.
    - Если **Office Online Server** работает без ошибок, в веб-браузере должен открыться `XML`-файл обнаружения для интерфейса открытой платформы веб-приложений (`WOPI`). Первые строки этого файла должны содержать примерно следующий текст:
    ```xml
        <?xml version="1.0" encoding="utf-8" ?>
        - <wopi-discovery>
        - <net-zone name="internal-http">
        - <app name="Excel" favIconUrl="http://servername/x/_layouts/images/FavIcon_Excel.ico" checkLicense="true">
      <action name="view" ext="ods" default="true" urlsrc="http://servername/x/_layouts/xlviewerinternal.aspx?<ui=UI_LLCC&amp;><rs=DC_LLCC&amp;>" /> 
      <action name="view" ext="xls" default="true" urlsrc="http://servername/x/_layouts/xlviewerinternal.aspx?<ui=UI_LLCC&amp;><rs=DC_LLCC&amp;>" /> 
      <action name="view" ext="xlsb" default="true" urlsrc="http://servername/x/_layouts/xlviewerinternal.aspx?<ui=UI_LLCC&amp;><rs=DC_LLCC&amp;>" /> 
      <action name="view" ext="xlsm" default="true" urlsrc="http://servername/x/_layouts/xlviewerinternal.aspx?<ui=UI_LLCC&amp;><rs=DC_LLCC&amp;>" />
    ```   
## Развертывание фермы Office Online Server, состоящей из одного сервера и поддерживающей HTTPS

1. **Создание фермы Office Online Server** ⚙️
   - Выполните команду `New-OfficeWebAppsFarm`, чтобы создать новую ферму **Office Online Server**, состоящую из одного сервера, как показано в следующем примере:
   ```powershell
    New-OfficeWebAppsFarm -InternalUrl "https://server.contoso.com" -ExternalUrl "https://wacweb01.contoso.com" -CertificateName "OfficeWebApps Certificate" -EditingEnabled
   ```
   Параметры :
   - `-InternalURL` — это полное доменное имя сервера, на котором работает Office Online Server, например https://servername.contoso.com.
   - `-ExternalURL` — это полное доменное имя, которое будет доступно из Интернета.
   - `-CertificateName` это понятное имя сертификата.
   - `-EditingEnabled` является необязательным и включает редактирование в **Office Online** при использовании с **SharePoint Server**. Данный параметр не используется Skype для бизнеса **Server 2015** и **Exchange Server**, поскольку эти узлы не поддерживают редактирование
2. Проверка создания фермы **Office Online Server** ⚙️
    - Откройте **url** в браузере вида: `https://servername/hosting/discovery`
      Где ***servername*** имя созданной фермы **Office Online Server**.
    - Если **Office Online Server** работает без ошибок, в веб-браузере должен открыться `XML`-файл обнаружения для интерфейса открытой платформы веб-приложений (`WOPI`). Первые строки этого файла должны содержать примерно следующий текст:
    ```xml
        <?xml version="1.0" encoding="utf-8" ?>
        - <wopi-discovery>
        - <net-zone name="internal-http">
        - <app name="Excel" favIconUrl="https://servername/x/_layouts/images/FavIcon_Excel.ico" checkLicense="true">
      <action name="view" ext="ods" default="true" urlsrc="https://servername/x/_layouts/xlviewerinternal.aspx?<ui=UI_LLCC&amp;><rs=DC_LLCC&amp;>" /> 
      <action name="view" ext="xls" default="true" urlsrc="https://servername/x/_layouts/xlviewerinternal.aspx?<ui=UI_LLCC&amp;><rs=DC_LLCC&amp;>" /> 
      <action name="view" ext="xlsb" default="true" urlsrc="https://servername/x/_layouts/xlviewerinternal.aspx?<ui=UI_LLCC&amp;><rs=DC_LLCC&amp;>" /> 
      <action name="view" ext="xlsm" default="true" urlsrc="https://servername/x/_layouts/xlviewerinternal.aspx?<ui=UI_LLCC&amp;><rs=DC_LLCC&amp;>" />
    ```   

### Возможные проблемы

1. При попытке открыть файл на сайте для редактирования ототбражается сообщение:
   `File not found`
   - Откройте **url** `https://servername/hosting/discovery`
      убедитесь что внешнее и внутреннее `FQDN` верные, если нет то выполните:
    ```powershell
      Remove-OfficeWebAppsMachine
    ```
   - ✅ На сервере где установлен **Office Online Server**, затем добавьте ферму заново:
   ```powershell
      New-OfficeWebAppsFarm -InternalUrl "https://your.internal.name" -ExternalUrl "https://your.external.name" -EditingEnabled -CertificateName "server cert name"
   ```
   - ✅ Затем проверить изменения пройда по ссылке `https://servername/hosting/discovery`
     и убедиться в корректности внешнего и внутреннего **url** имени сервера **Office Online Server**
2. При попытке открыть файл может появлятся сообщение что заправшиваемый файл не может быть открыт для редактирования, доступ запрещён.

  - ✅ Решение находится [тут](https://help.nextcloud.com/t/office-online-server-integration-with-nextcloud-configuration/92613/3)

  - ✅ Нужно создать `*.reg` файл со следующим содержимым:
  ```cmd
      Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\.NETFramework\v4.0.30319]
"SchUseStrongCrypto"=dword:00000001

[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols]

[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\PCT 1.0]
@="DefaultValue"

[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\PCT 1.0\Server]
@="DefaultValue"
"Enabled"=dword:00000000

[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0]
@="DefaultValue"

[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Server]
@="DefaultValue"
"Enabled"=dword:00000000

[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0]
@="DefaultValue"

[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Server]
@="DefaultValue"
"Enabled"=dword:00000000

[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0]
@="DefaultValue"

[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server]
@="DefaultValue"
"Enabled"=dword:00000000

[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1]
@="DefaultValue"

[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server]
@="DefaultValue"
"Enabled"=dword:00000000
  ```
   - Добавить его на сервере **Office Online Server** и перезагрузить его.
     Данный файл активирует `TLS 1.2` на **OOS** сервере. В некоторых случаях возможно нужно также активировать `TLS 1.2` в настройках браузера.

### 🚀 Available DevOps Tools


---

🔙 [back to Repos](https://github.com/KR-Sew?tab=repositories)
