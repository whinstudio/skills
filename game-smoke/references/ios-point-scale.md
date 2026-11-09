# iOS point scale

Used by the Touch targets check of game-smoke section 5.

iOS point scale: the device's `deviceTypeIdentifier` is in `xcrun simctl list devices -j`; its
`bundlePath` is in `xcrun simctl list devicetypes -j`. Then
`/usr/libexec/PlistBuddy -c 'Print :capabilities:ScreenDimensionsCapability:main-screen-scale' "<bundlePath>/Contents/Resources/capabilities.plist"`
prints the scale (`main-screen-width` and `main-screen-height` beside it are the main display's
pixels). The file or key missing: the scale is unreadable.
