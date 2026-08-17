# ThreeBodyHelper

ThreeBodyHelper is a lightweight World of Warcraft Retail addon for raid and party interaction helpers.

Current features:

- Group utility slash command: `/mqq`
- Battle resurrection charge display
- Raid/party social auto-replies and announcements
- Voice wheel module with local playback, optional chat text, and same-addon group sync
- Key binding entry: `ThreeBodyHelper / Open voice wheel`

## Installation

Copy the `ThreeBodyHelper` folder into:

```text
World of Warcraft\_retail_\Interface\AddOns\
```

Restart the game or run `/reload`.

## Voice Wheel

Open the wheel with one of:

```text
/mqq voice
/mqq wheel
/mqqwheel
```

Open voice wheel settings with:

```text
/mqq voice config
/mqq voice options
```

The voice wheel sends only phrase IDs over addon messages. Teammates must install the same addon and sound pack to hear the same custom audio.

Current built-in sync identity:

```text
packId: threebody-default-v1
payload: VW1\t<packId>\t<phraseId>
example: VW1\tthreebody-default-v1\twan_bu_liao_la
```

Receivers use the same local catalog to resolve phrase ids to local files such as `Media\Voice\wan_bu_liao_la.ogg`.
The first built-in voice pack contains 8 wheel entries: `wan_bu_liao_la`, `chong_feng`, `huan_hu`, `bei_shang_xiao_hao`, `tian_huo_tian_huo`, `bai_tuo_shui_qu_sha_le_ta_ba`, `piao_liang`, and `dui_you_ne`.

Useful commands:

```text
/mqq voice receive on|off
/mqq voice sync on|off
/mqq voice text on|off
/mqq voice text auto|say|party|raid|instance|guild
/mqq voice sound master|sfx|dialog|music|ambience
/mqq voice list
/mqq voice slots
/mqq voice slot 1 chong_feng
/mqq voice slot 1 clear
/mqq voice resetslots
/mqq voice scale 0.6-1.6
/mqq voice pos x y
/mqq voice unlock
/mqq voice lock
/mqq voice center
/mqq voice resetpos
/mqq voice resetlayout
/mqq voice status
/mqq voice cooldown global|sender|send seconds
```

The settings panel covers the same core options as the commands: receive sync, send sync, chat text, text channel, sound channel, movement lock, scale, layout reset, and cooldowns. It also links to a separate wheel phrase configuration panel.

The wheel phrase configuration panel is separate from the quick wheel and the main settings panel. Open it with `/mqq voice slots`, `/mqq voice wheelconfig`, or the settings-panel button. It shows the global voice catalog on the left and the user's 8 wheel slots on the right. Select a slot, then select a catalog phrase to bind it. The panel also supports local preview, clearing a slot, restoring the default 8 slots, and opening the wheel preview.

Internally, the addon keeps the built-in voice catalog separate from the user's slot choices. Group sync still sends the stable phrase ID, not the local wheel slot number, so users may put the same phrase in different wheel positions without breaking synchronized playback.

`/mqq voice text ...` controls the single selected channel used for normal chat text when a wheel entry is sent. Addon sync still uses party/raid/instance addon messages so teammates with the same addon can play local audio.

Custom voice playback defaults to the WoW `Dialog` sound channel. `/mqq voice sound ...` changes the saved playback channel for custom files and built-in fallback sound kits.

The wheel position and scale are saved per account. Wheel dragging is locked by default. Unlock movement in the settings panel or with `/mqq voice unlock`; this opens the wheel immediately for placement. Locking movement saves the current wheel position and hides it. `pos x y` sets its center offset from screen center. `resetpos` only recenters the wheel; `resetlayout` resets both position and scale.

## Custom Voice Files

Put original `.ogg` or `.mp3` clips under:

```text
Media\Voice\
```

Then point phrase entries to paths such as:

```text
Media\Voice\wan_bu_liao_la.ogg
```

`soundKitID` is optional and only used as a fallback built-in WoW sound when a phrase has no playable custom file.

Do not include copyrighted voice assets unless you have the right to redistribute them.

## License

MIT. See [LICENSE](LICENSE).
