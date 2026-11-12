# WallTrace

WallTrace currently has two experimental implementations:

- **Windows / desktop browser webcam prototype (main demo):** GitHub Pages app. Open https://andreybin742-cmd.github.io/WallTrace/ in Chrome or Edge on Windows. It uses OpenCV feature matching and a homography to re-project saved cable strokes onto the live camera view when the same wall is recognized.
- **Native iOS ARKit prototype:** see [ios/README.md](ios/README.md) and [the Xcode project](ios/WallTrace.xcodeproj).

## Windows webcam demo
1. Use a Windows PC with a webcam and open the Pages link in Chrome or Edge.
2. Allow camera access.
3. Point the camera at the wall and click **Запомнить стену**.
4. Draw routes with the mouse.
5. Click **Сохранить стену**.
6. Switch to **Просмотр трасс**, select the saved wall and point the camera at it again.

The web app stores saved walls in browser local storage. Use JSON export for backup or transfer. OpenCV.js is loaded from the OpenCV documentation CDN, so an internet connection is needed.

## Accuracy and safety
This is a computer-vision prototype, not depth-aware AR. It matches visual features and estimates a planar perspective transform. It works best when the wall and nearby static details have visible texture/features and lighting is similar. Plain walls, large viewpoint changes, occlusion, and lighting changes can prevent relocalization. It records only user-drawn routes; it does not detect hidden wires or pipes and is not a drilling-safety detector.
