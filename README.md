Bing Desktop Mac
================

A status bar application for macOS which looks for the latest background on the Bing homepage, downloads it and sets it as the wallpaper for your Mac. Supports macOS 10.8+ (tested on macOS 10.11-13). Currently development is still ongoing, but will upload the app when confident in it. 

Not in any way intended to infringe Microsoft's or Bing's property.

![Screenshot of the app in the status bar](doc/img/statusBar.png)

Features
--------
- Able to self-download the latest Bing wallpaper each day (GMT only)
- Can check if wallpaper is already downloaded and/or set as background
- Waits until internet connection is available
- Can set background on multiple monitors (not workspaces)
- Issues a notification to the Notification Center of the new image

Further Work
------------
- Add support for global time zones
- Remove duplication in scheduling functions
- Tidy up, simplify and de-clutter code
- Increase internet wait time after successive failures
- Close memory leaks and manage memory better
- Update header file to match main file
- Move to Swift instead of Objective-C
