# Release notes

<!-- Write release notes in English. Include only changes for the version. -->

For installation and updates, see the [Android update guide](docs/ANDROID_UPDATES.md#in-app-update).

## v0.1.0-alpha.49

### Changes since alpha.47

- **Custom duel backgrounds.** In the launcher, open **Import more resources → Import duel background** and choose a PNG, JPEG, or WebP. The image is centered and cropped to fill the space around the board without stretching. The same menu restores the original backgrounds.
- **Duel autosave in Yugi, Kaiba, and Joey.** Defeats save as soon as the result appears. Victories that award cards save the result and cards together when you accept the reward. If Google Drive is linked, sync starts at the same point.
- **Deck autosave.** Edits, undo, redo, and accepted deck imports save immediately and start syncing if Drive is linked. Incomplete decks are kept as drafts so the last playable deck remains available.
- **Launcher changelog.** The update dialog shows the last three compatible releases.
- **Duel visuals.** Graveyard effects no longer obscure the deck count, and messages next to the cursor scale with smoother edges.
- Android system settings now show the same release version as the launcher.

## v0.1.0-alpha.48

- Import a PNG, JPEG, or WebP from **Import more resources** to set a custom background around the duel board. Overlay mode fills the window with a centered crop and preserves the image's proportions. The same menu restores the original backgrounds.
- Defeats save as soon as the result screen opens. Victories with card rewards save when you accept the cards. With Google Drive connected, synchronization starts at those points.
- The deck editor saves and syncs changes as they happen, including undo, redo, and accepted deck imports. Incomplete edits reopen as drafts while the last playable deck remains available for duels.
- The launcher update dialog shows the last three compatible releases. Graveyard effects no longer cover the deck count, and cursor prompts scale with smoother edges.

## v0.1.0-alpha.47

- On Windows and Android, **Continue** resumes a local duel against the CPU from its last saved point. The launcher shows both players’ LP and asks before discarding a saved duel.
- On Android, tap once to select the only eligible attacker or to target a face-down monster. Tapping outside a Tribute confirmation answers **No**. Tribute selection uses the game’s localized messages and restores the original artwork for a single Tribute.
- Monsters stay visible as their placement or summon effect plays.
- The results screen saves progress and starts Google Drive synchronization right away when an account is connected. Joey’s reward cards sync after the player accepts the reward.

## v0.1.0-alpha.46

- On Android, the duel engine loads in the background during the rival intro and rock-paper-scissors. This reduces the pause when entering the first duel of a session.
- Yugi's Tribute Summon comic now shows the second line as the SUMMON banner appears (issue #20).
- Yugi's duel effects skip voice waits when the voice is silenced, and the card detail panel refreshes when a duel event and a stationary pointer update it on the same tick.
- In Joey, the field now marks Monster Zones blocked by an active effect.

## v0.1.0-alpha.45

- Cards placed face down show their backs as soon as the placement animation ends.
- In Kaiba, Cyber Jar reveals the cards it takes from each deck and leaves the next card hidden. Kaiba’s match results use the original scoreboard fade, result banner animation, and marker positions (issue #27).
- On Android, tapping outside a duel’s Yes/No prompt keeps the prompt open. The Tribute hint appears only when selecting Tributes for a monster, so setting or activating Spells and Traps no longer flashes the hint (issues #27 and #30).
- Joey’s comic reaction now animates the hand, eyes, and mouth. The Regulation of Tribe and DNA Surgery display the selected monster type on the field (issue #29).
- Yugi and Kaiba tutorials use the interface language selected in the launcher (issue #32).

- On Android, **Import more resources** can now import a save, a deck, or a replay from the device. The importer asks for confirmation and backs up the current save before replacing it (issue #12).

## v0.1.0-alpha.44

- Joey’s deck editor now centers the sort icon in its gold frame. You can click or tap the frame as the collection panel opens (issue #17).
- The touch prompt for selecting monsters to Tribute now follows the selected interface language in Yugi and Kaiba (issue #18).
- Time Wizard’s coin animation now lands on the face that matches the duel outcome (issue #25).
- Kaiba now plays his Trap Hole line when he activates the card. Mirror Force uses the standard trap line, Soul Exchange plays its own line, and Crush Card plays its reaction before it flips (issue #28).

## v0.1.0-alpha.43

- Muting the launcher now silences its music completely. Setting the in-game volume to zero also silences the music (issue #13).
- In Yugi, the damage number disappears when Kuriboh negates the damage. Fusion markers disappear when their material is used, even if an identical copy remains in hand (issue #13).
- Effects that reveal the opponent's hand now show the cards and their details in Yugi, Kaiba, and Joey. The hand and its preview are concealed again when the effect ends (issue #14).

## v0.1.0-alpha.42

- On Windows, **Import more resources** restores the unlocked collection and progress from the original `Common/system.dat` or the remake's `system.json` (issue #12). The same dialog imports `.ydc` decks, `.ydr` replays, and additional voice packs. The launcher asks before replacing files and backs up the active save before replacing it.
- The Windows launcher shows **Build** after an ISO or folder is selected. **Create .pck** and **Download APK** are now under **Android**. The launcher and settings have localized tooltips, and the game reimport button is smaller and easier to read.
- The update dialog shows scrollable release notes before updating. **Changelog** opens the full release list on GitHub.
- Touch controls use a single tap for direct actions and keep confirmation for choices that need it. Joey's Graveyard remains tappable. Transitions retain their opening frames at high refresh rates.
- Fixed duplicate cards briefly appearing during Joey's summon animation and when fusing cards already on the field. Refined Joey's card detail panel and Kaiba's demo presentation to match the originals more closely.
- Improved duel animation timing and radial transitions across the trilogy, along with Kaiba and Joey's post-duel results and rewards, Joey's duel windows, and Exodia's visual effects.

## v0.1.0-alpha.41

- Joey can start a duel with its own imported resources even if Yugi is absent (issue #11).
- On Windows, hover over an installed game and click the small **↻** button in its upper-right corner. Choose **ISO** or **Folder**, then select **Extract for PC** to rebuild that game's resources while keeping your saves and other games (issue #11).
- The launcher remembers whether its music is muted. Windows also restores fullscreen when you reopen the app after enabling it with **F11**, **Alt+Enter**, or the game's display options.

## v0.1.0-alpha.40

- The Windows importer now supports the original 165-card US edition of Yugi the Destiny (issue #7). Select your Yugi disc or ISO, then select your US Kaiba the Revenge disc or ISO when prompted. The importer applies the official December 2003 update automatically. You can import Yugi on its own or add both games. An already updated Yugi installation still works as a source.
- The same import flow can create a private Android resource pack (.pck). Keep both sources accessible during the import.

## v0.1.0-alpha.39

- Kaiba now says the correct line for **Change of Heart**, and chain markers appear on the cards that activated the chain (issue #10).
- When Kaiba Tributes a face-down monster, the card moves to the Graveyard while the flash is still visible, so its back no longer briefly reappears after the flash fades (issue #10).

## v0.1.0-alpha.38

- Joey: with the FORBIDDEN/LIMITED option on, the duel now starts. The starter deck has two forbidden cards (Change of Heart and Harpie's Feather Duster); the first try removes them and shows the deck error as in the original, and the next try starts the duel with the remaining 40 cards. Before, the error came back on every try (issue #8).
- Importer: the original US edition of Yugi the Destiny (2003, 165 cards) is now recognized and reported as not supported yet, instead of suggesting the Data.dat was changed by a mod. Use the European edition (2004) of Yugi (issue #7).

## v0.1.0-alpha.37

- Google Drive: **Connect** now opens Google's normal sign-in page in your browser. Choose your account, allow access and return to the game; no code to type and no YouTube channel selection. If Drive was already connected, nothing changes and you don't need to connect again.

Android browser sign-in has not been tested on a physical device.

## v0.1.0-alpha.36

- Android: new **Import .pck…** option in Settings → Save data. To add a game later (for example Kaiba after Yugi), create a new .pck with all your games in the PC launcher, select it there and reopen the app. Your saves and settings are kept (issue #6).
- Google Drive now has its own cloud button next to Exit, with a status dot, and opens its menu directly.
- At 2× simulation speed, Yugi's voice lines no longer overlap (for example when he activates Swords of Revealing Light) (issue #5).
- Exodia: the five pieces are now revealed by a top-to-bottom sweep as in the original, instead of flashing back to white; sparks, arm fade-in and the falling ball also follow the original (issue #5).
- Smoother card destruction: breaking a card and the character cut-in drops no longer create hundreds of objects per frame, which caused hiccups, especially on phones (issue #5).

## v0.1.0-alpha.35

- Android: choosing the target of a card with a tap works again. After activating an equip card such as Sword of Dark Destruction and pressing OK, tapping the monster kept bringing back "Designate the monster that you wish to equip" instead of equipping it. A single tap now selects the target in Yugi and Kaiba duels (issue #4).

## v0.1.0-alpha.34

- Joey the Passion: the tournament (best of three) result board now shows the right banner and marks. Winning the match showed the small "DRAW" stamp instead of "YOU WIN", the rival's row used the player's blue "LOSE" mark, and a drawn duel would have shown "LOSE".

## v0.1.0-alpha.33

- Fixed a freeze in Yugi and Kaiba duels: after the CPU used Thunder Dragon's effect from the hand (discard it to add two Thunder Dragons from the deck), the game kept showing "Shuffling Deck..." forever. The deck is now shuffled once and the duel continues.
- Joey the Passion: normal duels start with the original's native local player, so who goes first and the saved replays match the original game.
- Kaiba the Revenge: the title screen uses the original random number sequence.

## v0.1.0-alpha.32

- New **Voices +** button in the import screen: add another dub from a compatible copy of the same game (its `Voice.dat`), for example the English voices from a US disc on top of a European Yugi. Pick the game, select the `Voice.dat`, then click **Extract for PC**. Both dubs are kept; the launcher uses the one matching its language.
- The import actions are now four compact buttons: Extract for PC, Voices +, Create .pck and Download APK.

## v0.1.0-alpha.31

- Installations made by some third-party installers, which unpack `Data.dat` into a `data` folder of loose files, can now be imported: the launcher checks that the folder belongs to the selected game and packs it back automatically. Tested with an unpacked US Kaiba the Revenge: same engine data, and all 16 original Kaiba replays play back exactly.

## v0.1.0-alpha.30

- Kaiba the Revenge: the US retail disc (Konami of America, 2004) is now accepted. Its executable only differs from the supported one in how DLL names are written, so the duel engine data is identical; all 16 original Kaiba replays play back exactly with it.
- Import errors no longer repeat the game name ("kaiba: kaiba: …").
- Known limitation: Yugi the Destiny from the US release (2003, and its December 2003 update) is a different build of the game and is not supported yet. Yugi currently works with the later European/Spanish edition.

## v0.1.0-alpha.29

- Clearer import errors. If a Data.dat belongs to another game (for example, several games installed in the same folder) the launcher names that game; if the Data.dat or the executable looks modified by a mod or card pack, it says so and asks for an original installation or ISO. When an ISO contains the installer, the real reason from inside it is shown instead of "found: 0".
- Import, Android pack and error messages now follow the launcher language (English, Spanish, German, French, Italian and Japanese). Technical details stay available under "Technical details" and in the log.
- Android: a .pck that lacks a game's duel engine data is rejected when you select it, with a message naming the game, instead of failing later with a missing duel-engine data error.

## v0.1.0-alpha.28

- Launcher dialogs (reset, Google Drive, update, import errors) now match the gold style of the settings panel.
- Fixed animation glitches introduced in alpha.26:
  - Coins and dice no longer show flattened ghost copies beside them, and the coin shine is clean again.
  - Damage numbers no longer slide in from another digit (most visible when Joey takes damage).
  - Joey: "Draw Phase" no longer plays twice at the start of each turn.

## v0.1.0-alpha.27

- Optional Google Drive save sync between PC and Android: open the launcher settings, **Save data → Google Drive… → Connect**, enter the code shown at google.com/device and allow access. Cards, decks, results and progress sync when you return to the game selector and shortly after each save. If both devices changed, the launcher asks which save to keep; the other stays as a backup. Each player's save goes to their own Drive, and the game can only see the files it creates. Music volume, touch controls and display options stay per device. Privacy policy: docs/PRIVACY.md.
- Google may show "unverified app" when connecting; continue with **Advanced → Go to Power of Chaos Remake**.

## v0.1.0-alpha.26

- Overlay mode is now as sharp as Stretch: the duel is drawn at your screen's resolution instead of being upscaled from 800×600.
- Smoother animations at your display's refresh rate:
  - Destruction smoke and other frame-by-frame effects blend between frames instead of jumping.
  - Phase names ("Main Phase"…) no longer flicker when their two copies join.
  - The darkening and sweeping band at the start of a duel, the Kaiba and Joey title intros and Joey's level-change stars move every frame.
  - Android: the Display option no longer caps the game at 60 FPS on 90/120 Hz screens.
- Card collection works like the original: a new game starts empty and each game gives its starter deck the first time you open it. Kaiba and Joey only treat you as a player with previous cards (stronger CPU decks, Joey's full card set) if you really played the earlier games. Existing saves keep their cards; reset from the launcher settings to start over.
- Yugi and Kaiba: surrendering no longer counts as a loss or breaks your winning streak, as in the original.

## v0.1.0-alpha.25

- Demo mode: leaving the title menu idle starts the attract duel in Kaiba (recorded demos) and in Joey, where two CPU players duel live with the original decks, as in the original game. Any key or click returns to the title.
- Duels in all three games were checked against recordings of the original games, value by value (detail panel, dialogs, life points, music and every sound). Most differences found are fixed:
  - Yugi and Kaiba: CPU voices when it activates spells and traps (card-specific lines, Kaiba's reaction to damage), and portraits that no longer pause the duel.
  - Kaiba: phase, draw, attack and life-point timing now follow the original.
  - Sounds: summoning, equipping, changing position and direct attacks use the original sounds and timing; music returns after a summon portrait at the right moment.
  - Dialogs: a quick double click on OK no longer goes through to the field and selects a card by accident.
  - The detail panel keeps the card that asked for a target and no longer flips to a card back while choosing.

## v0.1.0-alpha.24

- Joey: the duel now matches recordings of the original game much more closely. Three full recorded duels (normal, spells and traps) replay with every engine command identical to the original.
- Joey: the card-set effect (frame, light and falling sparkles) is now ported method by method from the original.
- Joey: the card detail panel follows played and activated cards, including your own spells; a card shown by the duel wins over the pointer on the same frame.
- Joey: the phase banner no longer delays summons, the end-of-duel banner waits for the shade opening from the centre, and the first portrait reactions use the original turn counter.
- Joey: the hand keeps cards sharp at 800x600 and hover works under a still pointer.
