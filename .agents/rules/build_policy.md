# APK Build Policy

When the user requests to build or release an APK:

1. **Architecture Target**: Only build the combined ARM universal APK:
   ```bash
   flutter build apk --release --target-platform android-arm,android-arm64 --dart-define-from-file=.env
   ```
   Do not build split-per-abi APKs (`arm64-v8a` or `armeabi-v7a`).

2. **Retention Policy**: In `releases/`, keep at most the 5 most recent universal APK builds (`ls -t releases/*.apk | sed -e '1,5d' | xargs -r rm`). Prune any older APK beyond the 5 most recent.

