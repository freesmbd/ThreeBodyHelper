Put custom voice files here.

Recommended format:
- OGG or MP3
- Short clips, ideally under 3 seconds
- File names matching phrase ids, for example wan_bu_liao_la.ogg or pull.ogg

After adding or replacing sound files, run /reload or restart the game before testing.

The built-in pack currently maps these phrase ids to local files:
- wan_bu_liao_la -> Media\Voice\wan_bu_liao_la.ogg
- chong_feng -> Media\Voice\chong_feng.ogg
- huan_hu -> Media\Voice\huan_hu.ogg
- bei_shang_xiao_hao -> Media\Voice\bei_shang_xiao_hao.ogg
- tian_huo_tian_huo -> Media\Voice\tian_huo_tian_huo.ogg
- bai_tuo_shui_qu_sha_le_ta_ba -> Media\Voice\bai_tuo_shui_qu_sha_le_ta_ba.ogg
- piao_liang -> Media\Voice\piao_liang.ogg
- dui_you_ne -> Media\Voice\dui_you_ne.ogg
- xiao_fei_gun -> Media\Voice\xiao_fei_gun.ogg
- ni_you_song_le -> Media\Voice\ni_you_song_le.ogg
- ni_qi_bu_qi -> Media\Voice\ni_qi_bu_qi.ogg
- ni_zhe_me_cai -> Media\Voice\ni_zhe_me_cai.ogg
- mao_chong_ren_lei -> Media\Voice\mao_chong_ren_lei.ogg
- hui_da_wo -> Media\Voice\hui_da_wo.ogg
- da_jia_zhen_de_hao_qiang -> Media\Voice\da_jia_zhen_de_hao_qiang.ogg
- lao_ba_dao_le -> Media\Voice\lao_ba_dao_le.ogg
- kua_zang_o -> Media\Voice\kua_zang_o.ogg
- mei_guan_xi_ge_ge -> Media\Voice\mei_guan_xi_ge_ge.ogg
- zhen_bang -> Media\Voice\zhen_bang.ogg

Addon sync sends only pack id + phrase id. Everyone who should hear a custom
clip needs the same local file at the mapped path.

soundKitID is optional. It is only a fallback built-in WoW sound for phrases
that do not have a custom local file or whose file fails to play.
