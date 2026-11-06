@echo off
rem Uygulamanin web surumunu derler; sunucu bunu https://<adres>/uygulama/ altinda sunar (build\web).
rem Mobil kodu degisince tekrar calistirin; sunucuyu yeniden baslatmaya gerek yok.
cd /d "%~dp0"
set MSYS_NO_PATHCONV=1
flutter build web --release --base-href /uygulama/ --dart-define=API= --pwa-strategy=none
