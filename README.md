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

The voice wheel sends only phrase IDs over addon messages. Teammates must install the same addon and sound pack to hear the same custom audio.

Current built-in sync identity:

```text
packId: threebody-default-v1
payload: VW1\t<packId>\t<phraseId>
example: VW1\tthreebody-default-v1\twan_bu_liao_la
```

Receivers use the same local catalog to resolve `wan_bu_liao_la` to `Media\Voice\wan_bu_liao_la.ogg`.

Useful commands:

```text
/mqq voice receive on|off
/mqq voice sync on|off
/mqq voice text on|off
/mqq voice text auto|say|party|raid|instance|guild
/mqq voice sound master|sfx|dialog|music|ambience
/mqq voice list
/mqq voice scale 0.6-1.6
/mqq voice pos x y
/mqq voice center
/mqq voice resetpos
/mqq voice resetlayout
/mqq voice status
/mqq voice cooldown global|sender|send seconds
```

`/mqq voice text ...` controls the single selected channel used for normal chat text when a wheel entry is sent. Addon sync still uses party/raid/instance addon messages so teammates with the same addon can play local audio.

Custom voice playback defaults to the WoW `Dialog` sound channel. `/mqq voice sound ...` changes the saved playback channel for custom files and built-in fallback sound kits.

The wheel position and scale are saved per account. Drag the wheel background to move it, or use `pos x y` to set its center offset from screen center. `resetpos` only recenters the wheel; `resetlayout` resets both position and scale.

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
