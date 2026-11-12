# WallTrace

WallTrace is being developed in two tracks:

- **Native iOS ARKit prototype** — the intended markerless workflow: scan a real wall, draw a cable route on the detected vertical surface, save the AR world map, then attempt to relocalize the same space after relaunch. See [ios/README.md](ios/README.md) and [the Xcode project](ios/WallTrace.xcodeproj).
- **GitHub Pages web demo** — an earlier camera/marker experiment. It requires a printed HIRO marker and is not the intended final experience: https://andreybin742-cmd.github.io/WallTrace/

## Native iOS build
Open `ios/WallTrace.xcodeproj` on a Mac with Xcode 15+, select an ARKit-capable iPhone, configure signing, and run. A GitHub Actions workflow attempts an unsigned iOS Simulator build on changes under `ios/`.

## Important
WallTrace records only routes entered by the user. It does not detect hidden cables or pipes and must not be treated as a drilling-safety detector. Markerless relocalization depends on visual features, lighting, and changes in the room.
