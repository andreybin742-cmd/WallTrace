# WallTrace — native iOS AR prototype

This folder contains the native iOS direction for WallTrace. Unlike the GitHub Pages demo, this implementation uses Apple's ARKit world tracking and vertical-plane raycasts.

## What it is intended to test
- Scan a real wall with the iPhone camera.
- Draw a cable route by dragging a finger over the detected vertical plane.
- Save the ARWorldMap and route geometry locally.
- Relaunch and restore the saved world map so ARKit can relocalize the same physical area and show the route at its original position.

## Build requirements
- Mac with Xcode 15 or newer.
- iPhone with ARKit world tracking support.
- Camera permission.
- For installation on a personal iPhone: Xcode signing with an Apple ID; for TestFlight distribution: Apple Developer Program membership and App Store Connect setup.

## Important limitations of this first prototype
- Relocalization depends on visual features and lighting. A blank, repetitive, moved, or redecorated wall may not relocalize reliably.
- This prototype stores one local world map and a local route document on the device. It is not yet cloud-synced or multi-room.
- The route is only a record entered by the user; the app does not detect hidden utilities and must not be used as a drilling-safety detector.
- The current GitHub Pages version is a marker-based web demo, not this native ARKit implementation.

## Project
Open `WallTrace.xcodeproj` in Xcode, select an iPhone, set your signing team, and run.
