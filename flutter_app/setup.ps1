# Generates the platform folders (android/, ios/, web/, windows/) that
# `flutter create` normally makes, then allows the app to talk to the local
# HTTP backend on Android. Run once from this folder:  .\setup.ps1

flutter create --project-name kryptox --platforms=android,ios,web,windows .
if (-not $?) { exit 1 }

$manifest = "android\app\src\main\AndroidManifest.xml"
$xml = Get-Content $manifest -Raw
if ($xml -notmatch 'android.permission.INTERNET') {
    $xml = $xml -replace '<application', "<uses-permission android:name=`"android.permission.INTERNET`"/>`r`n    <application"
}
if ($xml -notmatch 'usesCleartextTraffic') {
    # The dev backend is plain http://, which Android blocks by default.
    $xml = $xml -replace '<application', '<application android:usesCleartextTraffic="true"'
}
$xml = $xml -replace 'android:label="kryptox"', 'android:label="KryptoX"'
[IO.File]::WriteAllText((Resolve-Path $manifest), $xml)  # UTF-8 without BOM

# `flutter create` adds a counter-app test that references a MyApp class we don't have.
if (Test-Path test\widget_test.dart) { Remove-Item test\widget_test.dart }

flutter pub get
