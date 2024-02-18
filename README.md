# windowsizer
Window resizer tool for Windows programs.

This tool allows you to forcefully resize the window of a game that does not allow you to do so, for example to comfortably play older games that run in a small 640x480 window on a larger monitor - by forcefully resizing the window to a larger size.

The older the game is, the more likely it is that this tool will work.

## Screenshots
**Kanon running at 2x scale**
![Kanon 2x scale](/assets/windowsizerkanon.png)

**Air running at 2x scale**
![Air 2x scale](/assets/windowsizerair.png)

## Usage
* Grab the latest release. It will contain the binaries, template and profiles for various games.
* Copy **windowsizer.exe** to the same folder as the game you wish to use it with
* If a profile already exists for your game in the **configs** folder, copy it to your game folder and rename it to **windowsizer.ini**
* ...otherwise copy **template.ini**, name it **windowsizer.ini** and edit it to suit your game
* Run **windowsizer.exe** to launch your game with a resized window

## Profiles (configs)
Profiles for a few games I have been using this with are provided under the **configs** folder. They should work out of the box on Windows 10. If you are editing a profile or making your own, you will find **windowsizer_debug.exe** helpful as it will show you what windowsizer is doing (for example the window size in pixels).

If you would like to submit new profiles, please open a pull request or open an issue and attach your profile to it.

## Limitations
* The game must be running in a window, not full screen.
* The content inside the resized window will only render at the correct (new) size if the game uses APIs that automatically scale the output to the size of the window. Many older DirectDraw/Direct3D games do tie the framebuffer blit to the window size, so windowsizer will work well for these games.
* Games that manually specify a blitting rectangle/size when drawing to the window are unlikely to be resizeable. Working around this is outside of the scale of this project.
* Some games may crash if you specify weird window sizes. This is not a bug with the game or with windowsizer - you are doing something the game did not expect.
* The method the game uses to scale the output is not controllable by windowsizer. For example, VisualArts RealLive engine visual novels will do a blocky/nearest neighbour stretch. For games that do not support bilinear filtering, I recommend sticking to integer scaling e.g. 2x or 3x.

## Known issues
Check the issues tab, but:
* There are issues locating a window by name if the window title uses unicode (e.g. Japanese characters). This will be fixed in the future. Many of these games should be resizeable using `windowfindmethod=pidonly` in the INI file.
* Window size autodetection is broken for some games. You can work around this by manually specifying a new window size.
* Border size autodetection is broken for some games. You can work around this by setting `autodetectbordersize=0` under `[tweaks]` and filling in sizes manually.

These issues will be fixed in the future!