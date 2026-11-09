# Build without the helper scripts

Used by game-smoke section 3 when `~/.claude/skills/game-new-project/scripts/` is absent.

Use the project's build script. `<ns>` is the full namespace after the
`namespace` keyword in `Assets/Editor/Build/BuildScript.cs`, ending in `.Editor.Build`; without that
file, Build is `NOT RUN`.

```bash
"$UNITY" -batchmode -nographics -quit -projectPath "$PWD" -buildTarget Android -executeMethod <ns>.BuildScript.BuildAndroid -cmposeOut "$PWD/Builds/game.apk" -logFile Builds/logs/android.log
"$UNITY" -batchmode -nographics -quit -projectPath "$PWD" -buildTarget iOS -executeMethod <ns>.BuildScript.BuildIOS -cmposeOut "$PWD/Builds/ios" -cmposeSimulator -logFile Builds/logs/ios-unity.log
```

Each succeeded when its log has `CMPOSE_BUILD_RESULT` with `result=Succeeded`. For iOS, then in
`Builds/ios` run `pod install` when there is a `Podfile`, and build with `-workspace Unity-iPhone.xcworkspace`
in that case, `-project Unity-iPhone.xcodeproj` otherwise:

```bash
xcodebuild -workspace Unity-iPhone.xcworkspace -scheme Unity-iPhone -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath ../ios-dd CODE_SIGNING_ALLOWED=NO build
```

