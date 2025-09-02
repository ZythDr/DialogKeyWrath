# DialogKeyWrath (WotLK 3.3.5a)

### Keyboard dialog navigation for WotLK 3.3.5. Quickly talk to NPCs, accept/turn-in quests, and handle popups without a single mouse click!

## Features

- **Fast selection with number keys**
  - Press 1–9/0 to choose visible options in Gossip and Quest frames
  - Numbers are shown next to options and quest rewards for easy targeting
- **Spacebar to advance**
  - Space targets the “most sensible” button (accept/complete/continue) or your current list item
  - Optional: use Space to trigger Postal’s “Open All” (when there's unread mail *and* Postal is installed)
- **Scroll wheel selection (optional)**
  - Move the Space target up/down the current list with your mouse wheel
- **Popup control rules**
  - Create simple rules to auto-handle confirmation popups (ignore or click Button1-Button4)
  - Keep interruptions under control while questing
- **Lightweight and native look**
  - Uses Blizzard’s highlights and fonts; minimal overhead 

## Commands

- Open options (full version):  
  `/dkw`

## Settings

- Allowing NumPad keys to also count as number inputs
- Allowing scroll wheel to move selection in dialog lists
- Show/hide numbers on dialog & quest lists
- Require number input for popup frames (Spacebar interactions disabled until a choice is made)
- Spacebar interacting with Postal's “Open All” button (Requires Postal, set to only work when there's *unread* mail)

## Rules (simple and flexible)

Create your own popup rules to match by text or frame and assign any of the following actions:
- Ignore it
- Click Button1 (usually where Accept is)
- Click Button2 (usually where Decline is)
- Click Button3 (used in certain frames, added for flexibility)
- Click Button4 (used in certain frames, added for flexibility)

Perfect for auto-dismissing familiar confirmation popups or streamlining routine actions.

## Compatibility

- Client: Wrath of the Lich King 3.3.5a
- Optional integration: Postal (for “Open All” with Space)

## Credits

- Original DialogKey addon by TonyRaccoon:  https://github.com/TonyRaccoon/wow-dialogkey
- DialogKeyWrath variant authored by ZythDr, adapted for WotLK 3.3.5a with added features and quality-of-life options.
- ChatGPT for helping me create this code.
