#!/usr/bin/env bash
# Generates the Android/iOS platform folders and adds the permissions the app needs.
set -e
cd "$(dirname "$0")"
flutter create --org au.nswtransit --project-name nsw_transit --platforms=android,ios .
rm -f test/widget_test.dart

# Android: internet + location permissions
M=android/app/src/main/AndroidManifest.xml
if ! grep -q ACCESS_FINE_LOCATION "$M"; then
  python3 - "$M" <<'PY'
import sys,re
p=sys.argv[1]; s=open(p).read()
perms='''    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
'''
s=re.sub(r'(<manifest[^>]*>\n)', r'\1'+perms, s, count=1)
open(p,'w').write(s)
PY
fi

# iOS: location usage description
P=ios/Runner/Info.plist
if ! grep -q NSLocationWhenInUseUsageDescription "$P"; then
  python3 - "$P" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
add='''	<key>NSLocationWhenInUseUsageDescription</key>
	<string>Your location is used to plan trips from where you are and show you on the map.</string>
</dict>
</plist>'''
i=s.rstrip().rfind('</dict>')
s=s[:i]+add+'\n'
open(p,'w').write(s)
PY
fi

flutter pub get
echo
echo "Done. Run:  flutter run --dart-define=TFNSW_API_KEY=your_key_here"
