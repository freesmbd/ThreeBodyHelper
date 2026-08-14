Put custom voice files here.

Recommended format:
- OGG or MP3
- Short clips, ideally under 3 seconds
- File names matching phrase ids, for example wan_bu_liao_la.ogg or pull.ogg

After adding or replacing sound files, run /reload or restart the game before testing.

The built-in pack currently maps phrase id wan_bu_liao_la to:
Media\Voice\wan_bu_liao_la.ogg

Addon sync sends only pack id + phrase id. Everyone who should hear a custom
clip needs the same local file at the mapped path.

soundKitID is optional. It is only a fallback built-in WoW sound for phrases
that do not have a custom local file or whose file fails to play.
