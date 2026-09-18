# The installer wizard

What a player sees when they run your `Setup.exe`, page by page.

The screenshots are from an installer built by this repository's `build.ps1` with the stock [`config.json`](../config.json). Wording, versions and the list of optional components follow your own config, [`components.json`](../components.json) and `extras\`, so your build will differ in the details: the window title is `installerTitle`, the name in the text is `appName`, and a component only appears if you ship it.

| # | Page | Player chooses |
|---|---|---|
| 1 | [Welcome](#1-welcome) | - |
| 2 | [Readme & Credits](#2-readme--credits) | - |
| 3 | [Select Destination Location](#3-select-destination-location) | Install folder |
| 4 | [Select Components](#4-select-components) | Recommended or Custom, optional components, font size |
| 5 | [Select Additional Tasks](#5-select-additional-tasks) | Desktop shortcuts, skip intro videos |
| 6 | [Ready to Install](#6-ready-to-install) | - (review) |
| 7 | [Installing](#7-installing) | - |
| 8 | [Completing](#8-completing) | Launch the game |

---

## 1. Welcome

![Welcome page](images/wizard/01-welcome.jpg)

Names the game and expansions, then lists every bundled community tool as "name by author", with the version taken from `components.json` at compile time. Tools you exclude are not listed.

The image on the left comes from `branding\WizardImage100.bmp` (and the higher-DPI sizes). Without it, Inno Setup's default image is used - see [branding/README.md](../branding/README.md).

## 2. Readme & Credits

The full credits, links to every project's home page, and notes on what the installer does. It is one scrolling page; here it is in four steps.

![Readme and credits, top](images/wizard/02-readme-credits.jpg)

<details>
<summary>The rest of the page</summary>

Required fixes continued, then the optional components:

![Readme and credits, part 2](images/wizard/03-readme-credits-2.jpg)

![Readme and credits, part 3](images/wizard/04-readme-credits-3.jpg)

And the notes at the end - serial handling, the skip-intro option and how to uninstall:

![Readme and credits, part 4](images/wizard/05-readme-credits-4.jpg)

</details>

## 3. Select Destination Location

![Select Destination Location](images/wizard/06-select-destination.jpg)

The default folder is `defaultInstallDir` in `config.json`. The required disk space is measured at build time.

With `appendEAGamesFolder` on, the installer makes sure the path ends in `EA Games\Battlefield 1942`: whatever the player types or browses to is treated as the parent folder. The **Will install to:** line under the box shows the resulting path as it is typed, so the correction is never a surprise.

## 4. Select Components

![Select Components](images/wizard/07-select-components.jpg)

**Recommended installation** ticks the game, the required fixes and the default font. **Custom installation** (shown) opens up the optional components. The game and the required fixes are always installed and cannot be unticked; the renderer line shows both DXVK and the dgVoodoo2 fallback, because which one is installed is decided by the graphics card, not by the player.

Scrolling down reaches the rest of the extras and the font, where exactly one size can be picked:

![Select Components, font sizes](images/wizard/08-select-components-2.jpg)

Borderless1942 and Battlefield Rich Presence are hidden on 32-bit Windows. Anything listed in `exclude`, or missing from `extras\`, is not offered at all.

## 5. Select Additional Tasks

![Select Additional Tasks](images/wizard/09-additional-tasks.jpg)

Desktop shortcuts and the intro videos. The Borderless1942 shortcut only appears when that component is selected, and **Skip the intro videos** adds `+restart 1` to the shortcut rather than deleting anything. Setting `serverAddress` in `config.json` adds one more shortcut here, which joins your server directly.

## 6. Ready to Install

The last chance to go back. The summary lists the destination, the setup type, every selected component and task - and, below those, what the installer detected about this PC.

![Ready to Install](images/wizard/10-ready-to-install.jpg)

<details>
<summary>The rest of the summary</summary>

![Ready to Install, part 2](images/wizard/11-ready-to-install-2.jpg)

The **Graphics renderer** section is the result of `VulkanCheck.exe`: every GPU is listed with its Vulkan version and whether it supports the bundled DXVK, followed by the choice that was made. Under **Windows prerequisites**, each Microsoft dependency is shown as it will be handled, so a player can see in advance that nothing extra will be installed:

![Ready to Install, part 3](images/wizard/12-ready-to-install-3.jpg)

</details>

## 7. Installing

![Installing](images/wizard/13-installing.jpg)

Extracts the game and the selected components, then runs the prerequisites that were reported as missing.

## 8. Completing

![Completing](images/wizard/14-finish.jpg)

Offers to launch the game. The uninstaller is registered with Windows, so the install can be removed from Settings > Apps > Installed apps.
