
\ final version should remove debug words and stack checking
\ load everything then take image and that is what's on site
	\ might be more accurate than including source
\ go back and see if dummy value of Monster in tiles is bc messed up color index


\ 0 nc-limit !
    
hex \ 

\ General Forth words
	: 3drop 2drop drop ;
	: 3dup 2 pick 2 pick 2 pick ;
	: >>r r> -rot >r >r >r ; compile-only
	: >>>r r> swap >r -rot >r >r >r ; compile-only
	: r>> r> r> r> rot >r ; compile-only
	: r>>> r> r> r> rot r> swap >r ; compile-only
	\ : byte create 0 c, ;
	: 0>= dup dup 0= swap 0> or ;
	: c@+1 dup c@ 1+ swap c! ;
	: c@-1 dup c@ 1- swap c! ;
	
\ Variables stored in zero page
	0 const cp
	86 const bank_mode					\ whether bank 2 points to code or screen memory
	88 const cp_main					\ copy of normal cp
	8A const cp_banked					\ copy of second cp in bank 2
	8C const cp_dict_game				\ copy of cp for game dictionary
	8E const cp_dict_char_menu			\ copy of cp for char menu dictionary
	90 const cp_dict_skills_menu		\ copy of cp for skill menu dictionary
	92 const cp_dict_res_menu			\ copy of cp for res menu dictionary
	94 const cp_dict_common_menu		\ copy of cp for common menu dictionary
	96 const dict_which					\ which cp is currently enabled
	98 const no_print					\ flag to suppress output while loading
	9A const code_end					\ end of code. dictionary can be stored here
	9C const chartable

\ Hardware 
	FFE1 const bank2_register			\ 0x4000-0x7FFF
	FFE2 const bank3_register			\ 0x8000=0xBFFF
	FFE3 const bank4_register			\ 0xC000=0xFFFF
	1 const bank_gen_ram2				\ banked code goes here (bank 2)
	2 const bank_gen_ram3
	3 const bank_gen_ram4
	4 const bank_gfx_ram1				\ upper half of screen (bank 2)
	5 const bank_gfx_ram2				\ lower half of screen (bank 3)
	6 const bank_ext_ram1
	7 const bank_ext_ram2
	8 const bank_ext_ram3
	9 const bank_ext_ram4
	100 const SCREEN_WIDTH
	80 const SCREEN_HEIGHT
	4000 const SCREEN_ADDRESS
	: hw_key FFE4 c@ ;
	FFEC const LOG_ON
	FFED const LOG_OFF
	FFEE const LOG_SEND

\ Bank constants and variables
	begin_enum
	enum DICT_MAIN
	enum DICT_BANK2
	enum DICT_GAME
	enum DICT_CHAR_MENU
	enum DICT_SKILLS_MENU
	enum DICT_RES_MENU
	enum DICT_COMMON_MENU
	variable third_dict						\ Third dictionary in ROM with Tali Forth

\ Other constants and variables
	wordlist constant bank2_wordlist		\ second word list stored in bank 2
	wordlist constant game_wordlist			\ game word list stored in extra ROM
	wordlist constant menu_char_wordlist	\ char menu word list stored in extra ROM
	wordlist constant menu_skills_wordlist	\ skills menu word list stored in extra ROM
	wordlist constant menu_res_wordlist		\ res menu word list stored in extra ROM
	wordlist constant menu_common_wordlist	\ common to all menus word list 
	variable rand_val

	bank2_wordlist			.
	game_wordlist           .
	menu_char_wordlist      .
	menu_skills_wordlist    .
	menu_res_wordlist       .
	menu_common_wordlist    .

	halt

\ Setup functions

	: forth_copy ( -- )
		C000 4000 3FE0 move 				\ copy entire Forth installation
		;
	: setup ( -- )
		60 FFDF c!							\ poke RTS (60) so FFDD will be BRK/RTS
		4000 cp_banked !					\ cp for banked code
		code_end @
		dup cp_dict_game !					\ cp for game dictionary
		dup cp_dict_char_menu !				\ cp for char menu dictionary
		dup cp_dict_skills_menu !			\ cp for skill menu dictionary
		dup cp_dict_res_menu !				\ cp for res menu dictionary
			cp_dict_common_menu !			\ cp for common menu dictionary
		DICT_MAIN dict_which !				\ main dictionary enabled
		game_wordlist third_dict !			\ which dictionary in ROM with Tali is enabled
		20 rand_val ! 						\ init rng with same value that worked well for C version
		\ bank words not defined yet
		
		bank_ext_ram1 bank2_register c!		\ point bank 2 to extended ram
		forth_copy
		bank_ext_ram2 bank2_register c!		\ point bank 2 to extended ram
		forth_copy
		bank_ext_ram3 bank2_register c!		\ point bank 2 to extended ram
		forth_copy
		bank_ext_ram4 bank2_register c!		\ point bank 2 to extended ram
		forth_copy
		
		bank_gfx_ram1 bank2_register c!		\ restore bank to gfx memory
		
		\ bank_ext_ram1 bank4_register c!		\ try running from copied bank
		\ bank_gen_ram4 bank4_register c!
		;

	: MemMsg
		-rot 2dup - u. ." / " drop 
		swap - u. ." bytes left" CR ;
		
	: startup ( -- )
		0 no_print ! 						\ disable output suppression after loading
		decimal
		CR
		." Tali Forth 2:    " u. ." bytes" CR CR
		." Main RAM:        " MemMsg
		." Bank 2:          " MemMsg
		." Game code:       " MemMsg
		." Char menu code:  " MemMsg
		." Skill menu code: " MemMsg
		." Res menu code:   " MemMsg
		." Common code:     " MemMsg
		
		CR hex 
		\ quit ;
		." Type 'run' to play" ;

\ Debug words that can be left out of final version
	: break FFDD execute ;	( -- )			\ jump to 00 00 (BRK) followed by RTS (60 at FFDF)
	: halt .s cr break ;
	(
	: dump8	( addr u -- )					\ dump 8 bytes at a time to fit screen
		begin
			2dup							\ copy address and count 
			8 > if							\ count > 8 ?
				8 dump						\ show only 8 bytes
				swap 8 +					\ advance address 8
				swap 8 -					\ decrease count by 8
			else
				\ over dump					\ show remaining bytes
				8 dump						\ show remaining bytes aligned to 8
				drop 0						\ set remaining count to 0
			then
		dup	0=								\ loop until 0 bytes left
		until
		2drop								\ drop address and count
		CR ;
	)
	
\ Bank words
	: bank2 bank2_register c! ;	( bank_id -- )
	: bank3 bank3_register c! ; ( bank_id -- )
	
	: BankROM ( -- )
		bank_gen_ram2 bank2 
		bank_gen_ram3 bank3 
		1 bank_mode ! ;
	
	: BankGfx ( -- )
		bank_gfx_ram1 bank2
		bank_gfx_ram2 bank3
		0 bank_mode ! ;
		
	: EnableBankROM ( -- )
		bank_mode @ 0= if
			BankROM
			\ bank2_wordlist dict_game_wordlist forth-wordlist 3 set-order
			bank2_wordlist third_dict @ forth-wordlist 3 set-order
		then ;

	: EnableGfxRAM ( -- )
		bank_mode @ 0<> if
			\ dict_game_wordlist forth-wordlist 2 set-order
			third_dict @ forth-wordlist 2 set-order
			BankGfx
		then ;

	: SaveDict ( -- )
		here
		dict_which @ case
			DICT_MAIN			of cp_main endof
			DICT_BANK2			of cp_banked endof
			DICT_GAME 			of cp_dict_game endof
			DICT_CHAR_MENU		of cp_dict_char_menu endof
			DICT_SKILLS_MENU	of cp_dict_skills_menu endof
			DICT_RES_MENU		of cp_dict_res_menu endof
			DICT_COMMON_MENU	of cp_dict_common_menu endof
		endcase ! ;
		
	: DictMainRAM ( -- )
		SaveDict
		cp_main @ cp !
		forth-wordlist set-current 
		DICT_MAIN dict_which ! ;
		
	: DictBankROM ( -- )
		SaveDict
		cp_banked @ cp !
		bank2_wordlist set-current		
		DICT_BANK2 dict_which ! ;	
	
	\ written for Enable words below but useful here too
	: EnableCommon ( wordlist bank -- )
		bank4_register c!
		bank_mode @ 0= if		\ opposite from above since doesnt change bank_mode
			forth-wordlist 2 set-order
		else
		 	bank2_wordlist swap forth-wordlist 3 set-order
		then
		;
		
	\ : ThirdDictCommon ( wordlist bank -- )
	\ 	bank4_register c!		
	\ 	SaveDict
	\ 	@ cp !						\ load new cp
	\ 	dict_which !				\ store which dictionary is active
	\ 	dup third_dict !			\ which word list is active for set-order		
	\ 	set-current
	\ 	;

	: ThirdDictCommon ( wordlist bank -- )
		SaveDict
		@ cp !						\ load new cp
		dict_which !				\ store which dictionary is active
		dup third_dict !			\ which word list is active for set-order		
		dup rot EnableCommon
		set-current
		;
	
	: DictGame ( -- )
		bank_gen_ram4
		game_wordlist
		DICT_GAME
		cp_dict_game
		ThirdDictCommon
		;
	
	: DictCharMenu ( -- )
		bank_ext_ram1
		menu_char_wordlist 
		DICT_CHAR_MENU
		cp_dict_char_menu
		ThirdDictCommon
		;
	
	: DictSkillsMenu ( -- )
		bank_ext_ram2
		menu_skills_wordlist
		DICT_SKILLS_MENU
		cp_dict_skills_menu
		ThirdDictCommon
		;
		
	: DictResMenu ( -- )
		bank_ext_ram3
		menu_res_wordlist 
		DICT_RES_MENU
		cp_dict_res_menu
		ThirdDictCommon
		;
	
	: DictCommonMenu ( -- )
		bank_ext_ram4
		menu_common_wordlist
		DICT_COMMON_MENU
		cp_dict_common_menu
		ThirdDictCommon
		;
	
	: EnableGameROM ( -- )
		game_wordlist
		bank_gen_ram4
		EnableCommon
		;
	
	: EnableCharMenuROM
		menu_char_wordlist
		bank_ext_ram1
		EnableCommon
		;
	
	: EnableSkillsMenuROM
		menu_skills_wordlist
		bank_ext_ram2
		EnableCommon
		;
		
	: EnableResMenuROM
		menu_res_wordlist
		bank_ext_ram3
		EnableCommon
		;
		
	: EnableCommonMenuROM
		menu_common_wordlist
		bank_ext_ram4
		EnableCommon
		;
			
		
\ ***HARDWARE SETUP***

	setup \ set up BankROM cp and break address before game code
	
	EnableBankROM							\ leave bank ROM enabled until graphics is needed
	
\ ***GAME SPECIFIC***

\ Game constants
			
	28 const MAP_WIDTH
	14 const MAP_HEIGHT
		
	60 const LEGEND_WIDTH 
	80 const LEGEND_HEIGHT 
	A0 const LEGEND_LEFT 
	0 const LEGEND_TOP 

	5 const FRAME_WIDTH 
	4 const FRAME_HEIGHT 

	0 const DIRECTION_NONE 
	1 const DIRECTION_UP 
	2 const DIRECTION_DOWN 
	3 const DIRECTION_LEFT 
	4 const DIRECTION_RIGHT 

	0 const OUTPUT_GAME 
	1 const OUTPUT_CHARACTER 
	2 const OUTPUT_SKILLS 
	3 const OUTPUT_RESOURCES 
	4 const OUTPUT_GAME_OVER 
		
	14 const MAP_LAVA_COUNT 
	3C const MAP_WALL_COUNT 
	5 const MAP_LAVA_SIZE 
	5 const MAP_WALL_SIZE 
	0 const MAP_BLANK 
	1 const MAP_BLANK_90 
	2 const MAP_BLANK_180 
	3 const MAP_BLANK_270 
	4 const MAP_ROCK 
	5 const MAP_LAVA 
	6 const MAP_EXIT 

	1 const HERO_START_X 
	1 const HERO_START_Y 

	1E const BOT_HP 

	0 const SKILL_BATTERY_SAVER 
	1 const SKILL_BOUNTY_HUNTER 
	2 const SKILL_FAST_DIGGER 
	3 const SKILL_LUCKY_DRILLER 
	4 const SKILL_MASTER_MINER 
	5 const SKILL_LUCKY_CRIT 
	6 const SKILL_CRIT_LORD 
	7 const SKILL_EXPERIENCED 
	8 const SKILL_INSTAKILL 
	9 const SKILL_GHOST 
	A const SKILL_FREE_LUNCH 
	B const SKILL_WISE_REWARDS 
	C const SKILL_BIG_DISCOUNT 
	D const SKILL_ONLY_THE_BEST 
	E const SKILL_CRYSTALSMITH 
	F const SKILL_COUNT 

	0 const COLOR_BLACK 
	3F const COLOR_WHITE 
	C const COLOR_GREEN 
	3 const COLOR_RED 
	2 const COLOR_DARK_RED 
	30 const COLOR_BLUE 
	20 const COLOR_DARK_BLUE 
	8 const COLOR_DARK_GREEN 
	32 const COLOR_PURPLE 
	21 const COLOR_DARK_PURPLE 
	B const COLOR_ORANGE 
	6 const COLOR_DARK_ORANGE 
	F const COLOR_YELLOW 
	A const COLOR_DARK_YELLOW 
	15 const COLOR_GRAY_1 
	2A const COLOR_GRAY_2 
	40 const COLOR_TRANSPARENT 

	15 const COLOR_LEGEND_BG 
	21 const COLOR_ROCK 
	3B const COLOR_DIRT 
	B const COLOR_LAVA 
	17 const COLOR_CRYSTAL_RED1 
	2B const COLOR_CRYSTAL_RED2 
	1F const COLOR_CRYSTAL_YELLOW1 
	2F const COLOR_CRYSTAL_YELLOW2 
	35 const COLOR_CRYSTAL_BLUE1 
	3A const COLOR_CRYSTAL_BLUE2 
	35 const COLOR_EXIT 
	1 const COLOR_MONSTER 

	3 const COLOR_HP 
	30 const COLOR_BATT 
	1 const COLOR_DMG 
	1 const COLOR_CRIT 
	17 const COLOR_MINE 
	32 const COLOR_DRILL 
	B const COLOR_LAVA_RES 

	8 const COLOR_MENU_CHAR 
	20 const COLOR_MENU_SKILLS 
	2 const COLOR_MENU_RESOURCES 
	2A const COLOR_MENU_BORDER 

	1E const INVENTORY_COUNT 
	8 const TEXT_LINE_HEIGHT 
	6 const TEXT_CHAR_WIDTH 
	A const TEXT_SPACING_Y 
	28 const MONSTER_COUNT 
	A const MONSTER_HP 
	28 const CRYSTAL_COUNT 
	50 const BAR_WIDTH 
	6 const BAR_HEIGHT 
	54 const LEGEND_MAZE_TOP 
	8 const LEGEND_MAZE_LEFT 
	3 const LEGEND_MAZE_MONSTER_COLOR 
	F const LEGEND_MAZE_CRYSTAL_COLOR 
	A const LEGEND_BOX_WIDTH 
	8 const LEGEND_BOX_HEIGHT 
	8 const LEGEND_STATS_LEFT 
	4 const LEGEND_HP_TOP 
	D const LEGEND_HP_BAR_TOP 
	18 const LEGEND_BATT_TOP 
	21 const LEGEND_BATT_BAR_TOP 
	2C const LEGEND_EXP_TOP 
	35 const LEGEND_EXP_BAR_TOP 
	40 const LEGEND_TARGET_TOP 
	49 const LEGEND_TARGET_BAR_TOP 
	2 const DRAWITEM_RES_LEFT 
	2 const DRAWITEM_RES_TOP 
	12 const DRAWITEM_ITEM_LEFT 
	4 const DRAWITEM_ITEM_TOP 
	F const DRAWITEM_STAT_TOP 
	A const DRAWITEM_STAT_HEIGHT 
	9 const MENU_CHAR_LEFT 
	9 const MENU_TITLE_TOP 
	4C const MENU_SKILL_LEFT 
	7C const MENU_RES_LEFT 
	9 const MENU_BG_LEFT 
	11 const MENU_BG_TOP 
	EE const MENU_BG_WIDTH 
	66 const MENU_BG_HEIGHT 
	1B const MENU_CHAR_ROBOT_LEFT 
	15 const MENU_CHAR_ROBOT_TOP 
	D const MENU_CHAR_STAT_LEFT 
	38 const MENU_CHAR_HP_TOP 
	41 const MENU_CHAR_BATT_TOP 
	4A const MENU_CHAR_DMG_TOP 
	53 const MENU_CHAR_CRIT_TOP 
	5C const MENU_CHAR_MINE_TOP 
	65 const MENU_CHAR_DRILL_TOP 
	6E const MENU_CHAR_LAVA_TOP 
	4 const MENU_CHAR_BOX_COLOR 
	50 const MENU_CHAR_BOX_LEFT 
	16 const MENU_CHAR_BOX1_TOP 
	46 const MENU_CHAR_BOX2_TOP 
	50 const MENU_CHAR_BOX_WIDTH 
	2D const MENU_CHAR_BOX_HEIGHT 
	12 const MENU_CHAR_BOX_TITLE_OFFSET_X 
	4 const MENU_CHAR_BOX_TITLE_OFFSET_Y 
	12 const MENU_CHAR_BOX_STAT_OFFSET_X 
	F const MENU_CHAR_BOX_STAT_OFFSET_Y 
	A4 const MENU_CHAR_GRID_LEFT 
	14 const MENU_CHAR_GRID_TOP 
	74 const MENU_CHAR_GRID_LINE_TOP 
	50 const MENU_CHAR_GRID_LINE_WIDTH 
	F4 const MENU_CHAR_GRID_LINE_LEFT 
	61 const MENU_CHAR_GRID_LINE_HEIGHT 
	5 const MENU_CHAR_BOX_X_COUNT 
	6 const MENU_CHAR_BOX_Y_COUNT 
	B const MENU_SKILL_POINTS_LEFT 
	14 const MENU_SKILL_POINTS_TOP 
	2E const MENU_SKILL_BOX1_COLOR 
	3A const MENU_SKILL_BOX2_COLOR 
	2B const MENU_SKILL_BOX3_COLOR 
	9 const MENU_SKILL_BOX_LEFT 
	1D const MENU_SKILL_BOX1_TOP 
	3B const MENU_SKILL_BOX2_TOP 
	59 const MENU_SKILL_BOX3_TOP 
	8C const MENU_SKILL_BOX_WIDTH 
	1E const MENU_SKILL_BOX_HEIGHT 
	1C const MENU_SKILL_X_SPACING 
	1E const MENU_SKILL_Y_SPACING 
	B const MENU_SKILL_SKILL_LEFT 
	20 const MENU_SKILL_SKILL_TOP 
	10 const MENU_SKILL_DBOX_COLOR 
	98 const MENU_SKILL_DBOX_LEFT 
	1D const MENU_SKILL_DBOX_TOP 
	5C const MENU_SKILL_DBOX_WIDTH 
	57 const MENU_SKILL_DBOX_HEIGHT 
	9A const MENU_SKILL_DBOX_TEXT_LEFT 
	2B const MENU_SKILL_DBOX_TEXT_TOP 
	1F const MENU_SKILL_DBOX_TITLE_TOP 
	8 const MENU_SKILL_TITLE1_COLOR 
	35 const MENU_SKILL_TITLE2_COLOR 
	17 const MENU_SKILL_TITLE3_COLOR 
	9A const MENU_SKILL_UPGRADE_LEFT 
	6A const MENU_SKILL_UPGRADE_TOP 
	13 const MENU_RES_BLOCK_HEIGHT 
	17 const MENU_RES_BLOCK_WIDTH 
	B const MENU_RES_BLOCK_LEFT 
	13 const MENU_RES_BLOCK_TOP 
	61 const MENU_RES_BLOCK_TOTAL_HEIGHT 
	E const MENU_RES_ITEM_LEFT 
	15 const MENU_RES_ITEM_TOP 
	5C const MENU_RES_BOX_WIDTH 
	57 const MENU_RES_BOX_HEIGHT 
	1 const MENU_RES_BOX_COLOR 
	98 const MENU_RES_BOX_LEFT 
	1D const MENU_RES_BOX_TOP 
	98 const MENU_RES_MONEY_LEFT 
	13 const MENU_RES_MONEY_TOP 
	5C const MENU_RES_MONEY_WIDTH 
	A const MENU_RES_MONEY_HEIGHT 
	15 const MENU_RES_MONEY_VAL_TOP 
	AB const MENU_RES_MONEY_RED_LEFT 
	C3 const MENU_RES_MONEY_BLUE_LEFT 
	DB const MENU_RES_MONEY_YELLOW_LEFT 
	9A const MENU_RES_COST_LEFT 
	6B const MENU_RES_COST_TOP 

	1 const MENU_RES_HP_COLOR1 
	17 const MENU_RES_HP_COLOR2 
	10 const MENU_RES_BATT_COLOR1 
	35 const MENU_RES_BATT_COLOR2 
	5 const MENU_RES_EXP_COLOR1 
	1F const MENU_RES_EXP_COLOR2 

	8 const MENU_BORDER_SIZE 

	2 const HERO_HP_BASE 
	3 const HERO_BATT_BASE 
	8 const HERO_MINE_BASE 
	C const HERO_DRILL_BASE 
	0 const HERO_LAVA_RES_BASE 
	1 const HERO_BATT_RATE_BASE 
	5 const HERO_CRIT_BASE 
	0 const HERO_HP_RECHARGE_BASE 
	4 const HERO_LAVA_DMG_BASE 
	4 const HERO_ATTACK_COST_BASE 
	2 const HERO_MINE_COST_BASE 
	2 const HERO_DRILL_COST_BASE 
	28 const HERO_EXP_MAX_BASE 
	7 const HERO_STAT_COUNT 

	64 const DEAD_LEFT 
	38 const DEAD_TOP 
	37 const DEAD_WIDTH 
	F const DEAD_HEIGHT 
	68 const DEAD_MSG_LEFT 
	3C const DEAD_MSG_TOP 

	FF const NO_MONSTER 
	FF const NO_CRYSTAL 

	0 const CRYSTAL_RED_TYPE 
	1 const CRYSTAL_BLUE_TYPE 
	2 const CRYSTAL_YELLOW_TYPE 	
	
	\ Item types
	begin_enum
		enum head
		enum body
		enum legs
		enum gun
		enum tool
		enum ground
		enum crystal
		enum res_only
		
	\ Item IDs
	begin_enum
		enum Basic_Head
		enum Head_MKII
		enum Head_MKIII
		enum Head_MKIV
		enum Lightning
		enum Basic_Body
		enum Tin_Body
		enum Iron_Body
		enum Steel_Body
		enum Fortress
		enum Basic_Legs
		enum Fast_Legs
		enum Quick_Legs
		enum Agile_Legs
		enum Mustang
		enum Basic_Gun
		enum Blaster
		enum Laser
		enum Phaser
		enum Death_Ray
		enum Basic_Tool
		enum Rock_Pick
		enum Rock_Drill
		enum Rock_Borer
		enum Laser_Bit
		enum Res_HP_Heal_ID
		enum Res_HP_Upgrade_ID
		enum Res_Batt_Heal_ID
		enum Res_Batt_Upgrade_ID
		enum Res_Exp_Upgrade_ID
		enum Res_Dmg_Upgrade_ID
		enum item_IDs_size
		enum item_none
			
	\ Tile IDs
	begin_enum
		\ Colorable tiles created in RAM from other tiles
		enum Ground_0
		enum Ground_90
		enum Ground_180
		enum Ground_270
		enum Rock
		enum Lava
		enum Crystal_red
		enum Crystal_yellow
		enum Crystal_blue
		enum Robot_left
		enum Robot_right
		\ enum Menu_head_temp
		\ enum Menu_body_temp
		\ enum Menu_legs_temp
		\ enum Menu_gun_temp
		\ enum Menu_tool_temp
		enum Menu_item_temp
		enum Skill_temp
		
		\ Colorable tiles
		enum Menu_head
		enum Menu_body
		enum Menu_legs
		enum Menu_gun
		enum Menu_tool
		enum Robot_left_raw
		enum Robot_right_raw
		enum Crystal_raw
		enum Ground_raw
		
		\ Non-colorable tiles in RAM
		enum Monster			
		enum Monster_dead		
		enum Menu_item_slot
		enum Crystal_base
		
		\ 1bpp tiles
		enum Hero_target
		enum Menu_item_selector
		enum Menu_skill_selector
		enum ExitID
		enum Res_HP_Heal		
		enum Res_HP_Upgrade	
		enum Res_Batt_Heal	
		enum Res_Batt_Upgrade	
		enum Res_Exp_Upgrade	
		enum Res_Dmg_Upgrade
		enum Skill0
		enum Skill1
		enum Skill2
		enum Skill3
		enum Skill4
		enum Skill5
		enum Skill6
		enum Skill7
		enum Skill8
		enum Skill9
		enum Skill10
		enum Skill11
		enum Skill12
		enum Skill13
		enum Skill14
		enum tile_IDs_size
			
\ Tile data

	\ GENERATED TILES (see asset extraction script for sizes below)
		create tile_Ground_0 B6 allot
		create tile_Ground_90 BA allot
		create tile_Ground_180 B6 allot
		create tile_Ground_270 BA allot
		create tile_Rock B6 allot 
		create tile_Lava B6 allot
		create tile_Crystal_red 22A allot
		create tile_Crystal_yellow 22A allot
		create tile_Crystal_blue 22A allot
		create tile_Robot_left 202 allot
		create tile_Robot_right 202 allot
		\ create tile_Menu_head_temp B2 allot
		\ create tile_Menu_body_temp 92 allot
		\ create tile_Menu_legs_temp A2 allot
		\ create tile_Menu_gun_temp 70 allot
		\ create tile_Menu_tool_temp 5E allot
		create tile_Menu_item_temp 
			\ start here
			\ 1 allot	\ at least loads with this then underflow on run
			B2 allot \ doesnt even load. nonsense underflow while loading
		create tile_Skill_temp 4B allot
		
	\ COLORABLE TILES
		DictBankROM
		
			create tile_Menu_head 10 c, 10 c, 10 c, 40 c, 0 c, 3 c, 40 c, 1 c, 47 c, 3 c, 48 c, 9 c, 40 c, 0 c, 2 c, 40 c, 3 c, 47 c, 3 c, 48 c, 8 c, 40 c, 0 c, 3 c, 40 c, 1 c, 47 c, 2 c, 40 c, 2 c, 48 c, 8 c, 40 c, 0 c, 7 c, 40 c, 2 c, 48 c, 7 c, 40 c, 
			0 c, 7 c, 40 c, 2 c, 48 c, 7 c, 40 c, 0 c, 2 c, 40 c, c c, 49 c, 2 c, 40 c, 0 c, 1 c, 40 c, 2 c, 49 c, a c, 4a c, 2 c, 49 c, 1 c, 40 c, 0 c, 1 c, 40 c, 1 c, 49 c, c c, 4a c, 1 c, 49 c, 1 c, 40 c, 0 c, 1 c, 40 c, 1 c, 49 c, 3 c, 4a c, 1 c, 3f c, 
			1 c, 0 c, 3 c, 4a c, 1 c, 3f c, 1 c, 0 c, 2 c, 4a c, 1 c, 49 c, 1 c, 40 c, 0 c, 1 c, 40 c, 1 c, 49 c, 3 c, 4a c, 2 c, 3f c, 3 c, 4a c, 2 c, 3f c, 2 c, 4a c, 1 c, 49 c, 1 c, 40 c, 0 c, 1 c, 40 c, 1 c, 49 c, c c, 4a c, 1 c, 49 c, 1 c, 40 c, 0 c, 
			1 c, 40 c, 1 c, 49 c, 3 c, 4a c, 1 c, 4b c, 8 c, 4a c, 1 c, 49 c, 1 c, 40 c, 0 c, 1 c, 40 c, 1 c, 49 c, 4 c, 4a c, 5 c, 4b c, 3 c, 4a c, 1 c, 49 c, 1 c, 40 c, 0 c, 1 c, 40 c, 2 c, 49 c, a c, 4a c, 2 c, 49 c, 1 c, 40 c, 0 c, 2 c, 40 c, c c, 
			49 c, 2 c, 40 c, 0 c, 
			
			create tile_Menu_body 10 c, 10 c, 10 c, 40 c, 0 c, 10 c, 40 c, 0 c, 10 c, 40 c, 0 c, 10 c, 40 c, 0 c, 5 c, 40 c, 6 c, 41 c, 5 c, 40 c, 0 c, 3 c, 40 c, 3 c, 41 c, 4 c, 42 c, 3 c, 41 c, 3 c, 40 c, 0 c, 2 c, 40 c, 1 c, 41 c, 1 c, 42 c, 1 c, 41 c, 
			6 c, 42 c, 1 c, 41 c, 1 c, 42 c, 1 c, 41 c, 2 c, 40 c, 0 c, 1 c, 40 c, 1 c, 41 c, 2 c, 42 c, 1 c, 41 c, 6 c, 42 c, 1 c, 41 c, 2 c, 42 c, 1 c, 41 c, 1 c, 40 c, 0 c, 1 c, 41 c, 3 c, 42 c, 1 c, 41 c, 6 c, 42 c, 1 c, 41 c, 3 c, 42 c, 1 c, 41 c, 
			0 c, 1 c, 41 c, 2 c, 42 c, 2 c, 41 c, 6 c, 42 c, 2 c, 41 c, 2 c, 42 c, 1 c, 41 c, 0 c, 1 c, 40 c, 2 c, 41 c, 1 c, 40 c, 1 c, 41 c, 6 c, 42 c, 1 c, 41 c, 1 c, 40 c, 2 c, 41 c, 1 c, 40 c, 0 c, 4 c, 40 c, 2 c, 41 c, 4 c, 42 c, 2 c, 41 c, 4 c, 
			40 c, 0 c, 5 c, 40 c, 6 c, 41 c, 5 c, 40 c, 0 c, 10 c, 40 c, 0 c, 10 c, 40 c, 0 c, 10 c, 40 c, 0 c, 
			
			create tile_Menu_legs 10 c, 10 c, 10 c, 40 c, 0 c, 10 c, 40 c, 0 c, 10 c, 40 c, 0 c, 10 c, 40 c, 0 c, 10 c, 40 c, 0 c, 3 c, 40 c, 3 c, 43 c, 3 c, 40 c, 3 c, 43 c, 4 c, 40 c, 0 c, 3 c, 40 c, 1 c, 43 c, 1 c, 44 c, 1 c, 43 c, 3 c, 40 c, 1 c, 43 c, 
			1 c, 44 c, 1 c, 43 c, 4 c, 40 c, 0 c, 3 c, 40 c, 1 c, 43 c, 1 c, 44 c, 1 c, 43 c, 3 c, 40 c, 1 c, 43 c, 1 c, 44 c, 1 c, 43 c, 4 c, 40 c, 0 c, 3 c, 40 c, 1 c, 43 c, 1 c, 44 c, 1 c, 43 c, 3 c, 40 c, 1 c, 43 c, 1 c, 44 c, 1 c, 43 c, 4 c, 40 c, 
			0 c, 3 c, 40 c, 1 c, 43 c, 1 c, 44 c, 1 c, 43 c, 3 c, 40 c, 1 c, 43 c, 1 c, 44 c, 1 c, 43 c, 4 c, 40 c, 0 c, 3 c, 40 c, 1 c, 43 c, 2 c, 44 c, 1 c, 43 c, 2 c, 40 c, 1 c, 43 c, 2 c, 44 c, 1 c, 43 c, 3 c, 40 c, 0 c, 3 c, 40 c, 1 c, 43 c, 3 c, 
			44 c, 1 c, 43 c, 1 c, 40 c, 1 c, 43 c, 3 c, 44 c, 1 c, 43 c, 2 c, 40 c, 0 c, 3 c, 40 c, 5 c, 43 c, 1 c, 40 c, 5 c, 43 c, 2 c, 40 c, 0 c, 10 c, 40 c, 0 c, 10 c, 40 c, 0 c, 10 c, 40 c, 0 c, 
			
			create tile_Menu_gun 10 c, 10 c, 10 c, 40 c, 0 c, 10 c, 40 c, 0 c, 10 c, 40 c, 0 c, 9 c, 40 c, 1 c, 45 c, 6 c, 40 c, 0 c, 8 c, 40 c, 3 c, 45 c, 5 c, 40 c, 0 c, 7 c, 40 c, 1 c, 45 c, 2 c, 46 c, 2 c, 45 c, 4 c, 40 c, 0 c, 6 c, 40 c, 1 c, 45 c, 
			3 c, 46 c, 1 c, 45 c, 5 c, 40 c, 0 c, 6 c, 40 c, 1 c, 45 c, 2 c, 46 c, 3 c, 45 c, 4 c, 40 c, 0 c, 5 c, 40 c, 8 c, 45 c, 3 c, 40 c, 0 c, 4 c, 40 c, 3 c, 45 c, 3 c, 40 c, 4 c, 45 c, 2 c, 40 c, 0 c, 3 c, 40 c, 2 c, 46 c, 1 c, 45 c, 5 c, 40 c, 
			3 c, 45 c, 2 c, 40 c, 0 c, 3 c, 40 c, 2 c, 46 c, 7 c, 40 c, 1 c, 45 c, 3 c, 40 c, 0 c, 10 c, 40 c, 0 c, 10 c, 40 c, 0 c, 10 c, 40 c, 0 c, 10 c, 40 c, 0 c, 
			
			create tile_Menu_tool 10 c, 10 c, 10 c, 40 c, 0 c, 10 c, 40 c, 0 c, 10 c, 40 c, 0 c, 9 c, 40 c, 2 c, 4c c, 5 c, 40 c, 0 c, 8 c, 40 c, 2 c, 4c c, 6 c, 40 c, 0 c, 8 c, 40 c, 2 c, 4c c, 2 c, 40 c, 1 c, 4c c, 3 c, 40 c, 0 c, 7 c, 40 c, 6 c, 4c c, 
			3 c, 40 c, 0 c, 6 c, 40 c, 6 c, 4c c, 4 c, 40 c, 0 c, 5 c, 40 c, 5 c, 4c c, 6 c, 40 c, 0 c, 4 c, 40 c, 5 c, 4c c, 7 c, 40 c, 0 c, 3 c, 40 c, 5 c, 4c c, 8 c, 40 c, 0 c, 3 c, 40 c, 4 c, 4c c, 9 c, 40 c, 0 c, 4 c, 40 c, 2 c, 4c c, a c, 40 c, 0 c, 
			10 c, 40 c, 0 c, 10 c, 40 c, 0 c, 10 c, 40 c, 0 c, 
					
			create tile_Robot_left_raw 20 c, 20 c, 20 c, 40 c, 0 c, 12 c, 40 c, 3 c, 48 c, 1 c, 47 c, a c, 40 c, 0 c, 11 c, 40 c, 3 c, 48 c, 3 c, 47 c, 9 c, 40 c, 0 c, 11 c, 40 c, 2 c, 48 c, 2 c, 40 c, 1 c, 47 c, a c, 40 c, 0 c, 10 c, 40 c, 2 c, 48 c, e c, 
			40 c, 0 c, 10 c, 40 c, 2 c, 48 c, e c, 40 c, 0 c, b c, 40 c, c c, 49 c, 9 c, 40 c, 0 c, a c, 40 c, 2 c, 49 c, a c, 4a c, 2 c, 49 c, 8 c, 40 c, 0 c, a c, 40 c, 1 c, 49 c, c c, 4a c, 1 c, 49 c, 8 c, 40 c, 0 c, a c, 40 c, 1 c, 49 c, 2 c, 4a c, 
			1 c, 0 c, 1 c, 3f c, 3 c, 4a c, 1 c, 0 c, 1 c, 3f c, 3 c, 4a c, 1 c, 49 c, 8 c, 40 c, 0 c, a c, 40 c, 1 c, 49 c, 2 c, 4a c, 2 c, 3f c, 3 c, 4a c, 2 c, 3f c, 3 c, 4a c, 1 c, 49 c, 8 c, 40 c, 0 c, a c, 40 c, 1 c, 49 c, c c, 4a c, 1 c, 49 c, 8 c, 
			40 c, 0 c, a c, 40 c, 1 c, 49 c, 8 c, 4a c, 1 c, 4b c, 3 c, 4a c, 1 c, 49 c, 8 c, 40 c, 0 c, a c, 40 c, 1 c, 49 c, 3 c, 4a c, 5 c, 4b c, 4 c, 4a c, 1 c, 49 c, 8 c, 40 c, 0 c, 6 c, 40 c, 1 c, 45 c, 3 c, 40 c, 2 c, 49 c, a c, 4a c, 2 c, 49 c, 
			8 c, 40 c, 0 c, 5 c, 40 c, 3 c, 45 c, 3 c, 40 c, c c, 49 c, 5 c, 40 c, 2 c, 4c c, 2 c, 40 c, 0 c, 4 c, 40 c, 1 c, 45 c, 2 c, 46 c, 2 c, 45 c, 3 c, 40 c, a c, 41 c, 5 c, 40 c, 2 c, 4c c, 3 c, 40 c, 0 c, 3 c, 40 c, 1 c, 45 c, 3 c, 46 c, 1 c, 
			45 c, 1 c, 40 c, 4 c, 41 c, 8 c, 42 c, 4 c, 41 c, 2 c, 40 c, 2 c, 4c c, 2 c, 40 c, 1 c, 4c c, 0 c, 3 c, 40 c, 1 c, 45 c, 2 c, 46 c, 2 c, 45 c, 1 c, 41 c, 2 c, 42 c, 1 c, 41 c, a c, 42 c, 1 c, 41 c, 2 c, 42 c, 1 c, 41 c, 6 c, 4c c, 0 c, 2 c, 
			40 c, 5 c, 45 c, 1 c, 41 c, 3 c, 42 c, 1 c, 41 c, a c, 42 c, 1 c, 41 c, 3 c, 42 c, 1 c, 41 c, 4 c, 4c c, 1 c, 40 c, 0 c, 1 c, 40 c, 3 c, 45 c, 2 c, 40 c, 1 c, 41 c, 3 c, 42 c, 2 c, 41 c, a c, 42 c, 2 c, 41 c, 3 c, 42 c, 1 c, 41 c, 1 c, 4c c, 
			3 c, 40 c, 0 c, 2 c, 46 c, 1 c, 45 c, 3 c, 40 c, 1 c, 41 c, 2 c, 42 c, 1 c, 41 c, 1 c, 40 c, 1 c, 41 c, a c, 42 c, 1 c, 41 c, 1 c, 40 c, 1 c, 41 c, 2 c, 42 c, 1 c, 41 c, 4 c, 40 c, 0 c, 2 c, 46 c, 5 c, 40 c, 2 c, 41 c, 1 c, 45 c, 1 c, 40 c, 
			2 c, 41 c, 8 c, 42 c, 2 c, 41 c, 1 c, 40 c, 1 c, 4c c, 2 c, 41 c, 5 c, 40 c, 0 c, c c, 40 c, a c, 41 c, 1 c, 40 c, 3 c, 4c c, 6 c, 40 c, 0 c, d c, 40 c, 3 c, 43 c, 3 c, 40 c, 3 c, 43 c, 1 c, 40 c, 2 c, 4c c, 7 c, 40 c, 0 c, d c, 40 c, 1 c, 
			43 c, 1 c, 44 c, 1 c, 43 c, 3 c, 40 c, 1 c, 43 c, 1 c, 44 c, 1 c, 43 c, a c, 40 c, 0 c, d c, 40 c, 1 c, 43 c, 1 c, 44 c, 1 c, 43 c, 3 c, 40 c, 1 c, 43 c, 1 c, 44 c, 1 c, 43 c, a c, 40 c, 0 c, d c, 40 c, 1 c, 43 c, 1 c, 44 c, 1 c, 43 c, 3 c, 
			40 c, 1 c, 43 c, 1 c, 44 c, 1 c, 43 c, a c, 40 c, 0 c, d c, 40 c, 1 c, 43 c, 1 c, 44 c, 1 c, 43 c, 3 c, 40 c, 1 c, 43 c, 1 c, 44 c, 1 c, 43 c, a c, 40 c, 0 c, c c, 40 c, 1 c, 43 c, 2 c, 44 c, 1 c, 43 c, 2 c, 40 c, 1 c, 43 c, 2 c, 44 c, 1 c, 
			43 c, a c, 40 c, 0 c, b c, 40 c, 1 c, 43 c, 3 c, 44 c, 1 c, 43 c, 1 c, 40 c, 1 c, 43 c, 3 c, 44 c, 1 c, 43 c, a c, 40 c, 0 c, b c, 40 c, 5 c, 43 c, 1 c, 40 c, 5 c, 43 c, a c, 40 c, 0 c, 
			
			create tile_Robot_right_raw 20 c, 20 c, 
			20 c, 40 c, 	0 c, 
			c c, 40 c, 		1 c, 47 c, 		3 c, 48 c, 		10 c, 40 c, 	0 c, 
			b c, 40 c, 		3 c, 47 c, 		3 c, 48 c, 		f c, 40 c, 		0 c,
			c c, 40 c, 		1 c, 47 c, 		2 c, 40 c, 		2 c, 48 c, 		f c, 40 c, 		0 c, 
			10 c, 40 c, 	2 c, 48 c, 		e c, 40 c, 
			0 c, 10 c, 40 c, 2 c, 48 c, e c, 40 c, 0 c, b c, 40 c, c c, 49 c, 9 c, 40 c, 0 c, a c, 40 c, 2 c, 49 c, a c, 4a c, 2 c, 49 c, 8 c, 40 c, 0 c, a c, 40 c, 1 c, 49 c, c c, 4a c, 1 c, 49 c, 8 c, 40 c, 0 c, a c, 40 c, 1 c, 49 c, 3 c, 4a c, 1 c, 
			3f c, 1 c, 0 c, 3 c, 4a c, 1 c, 3f c, 1 c, 0 c, 2 c, 4a c, 1 c, 49 c, 8 c, 40 c, 0 c, a c, 40 c, 1 c, 49 c, 3 c, 4a c, 2 c, 3f c, 3 c, 4a c, 2 c, 3f c, 2 c, 4a c, 1 c, 49 c, 8 c, 40 c, 0 c, a c, 40 c, 1 c, 49 c, c c, 4a c, 1 c, 49 c, 8 c, 40 c, 
			0 c, a c, 40 c, 1 c, 49 c, 3 c, 4a c, 1 c, 4b c, 8 c, 4a c, 1 c, 49 c, 8 c, 40 c, 0 c, a c, 40 c, 1 c, 49 c, 4 c, 4a c, 5 c, 4b c, 3 c, 4a c, 1 c, 49 c, 8 c, 40 c, 0 c, 6 c, 40 c, 1 c, 45 c, 3 c, 40 c, 2 c, 49 c, a c, 4a c, 2 c, 49 c, 8 c, 
			40 c, 0 c, 5 c, 40 c, 3 c, 45 c, 3 c, 40 c, c c, 49 c, 5 c, 40 c, 2 c, 4c c, 2 c, 40 c, 0 c, 4 c, 40 c, 1 c, 45 c, 2 c, 46 c, 2 c, 45 c, 3 c, 40 c, a c, 41 c, 5 c, 40 c, 2 c, 4c c, 3 c, 40 c, 0 c, 3 c, 40 c, 1 c, 45 c, 3 c, 46 c, 1 c, 45 c, 
			1 c, 40 c, 4 c, 41 c, 8 c, 42 c, 4 c, 41 c, 2 c, 40 c, 2 c, 4c c, 2 c, 40 c, 1 c, 4c c, 0 c, 3 c, 40 c, 1 c, 45 c, 2 c, 46 c, 2 c, 45 c, 1 c, 41 c, 2 c, 42 c, 1 c, 41 c, a c, 42 c, 1 c, 41 c, 2 c, 42 c, 1 c, 41 c, 6 c, 4c c, 0 c, 2 c, 40 c, 
			5 c, 45 c, 1 c, 41 c, 3 c, 42 c, 1 c, 41 c, a c, 42 c, 1 c, 41 c, 3 c, 42 c, 1 c, 41 c, 4 c, 4c c, 1 c, 40 c, 0 c, 1 c, 40 c, 3 c, 45 c, 2 c, 40 c, 1 c, 41 c, 3 c, 42 c, 2 c, 41 c, a c, 42 c, 2 c, 41 c, 3 c, 42 c, 1 c, 41 c, 1 c, 4c c, 3 c, 
			40 c, 0 c, 2 c, 46 c, 1 c, 45 c, 3 c, 40 c, 1 c, 41 c, 2 c, 42 c, 1 c, 41 c, 1 c, 40 c, 1 c, 41 c, a c, 42 c, 1 c, 41 c, 1 c, 40 c, 1 c, 41 c, 2 c, 42 c, 1 c, 41 c, 4 c, 40 c, 0 c, 2 c, 46 c, 5 c, 40 c, 2 c, 41 c, 1 c, 45 c, 1 c, 40 c, 2 c, 
			41 c, 8 c, 42 c, 2 c, 41 c, 1 c, 40 c, 1 c, 4c c, 2 c, 41 c, 5 c, 40 c, 0 c, c c, 40 c, a c, 41 c, 1 c, 40 c, 3 c, 4c c, 6 c, 40 c, 0 c, c c, 40 c, 3 c, 43 c, 3 c, 40 c, 3 c, 43 c, 2 c, 40 c, 2 c, 4c c, 7 c, 40 c, 0 c, c c, 40 c, 1 c, 43 c, 
			1 c, 44 c, 1 c, 43 c, 3 c, 40 c, 1 c, 43 c, 1 c, 44 c, 1 c, 43 c, b c, 40 c, 0 c, c c, 40 c, 1 c, 43 c, 1 c, 44 c, 1 c, 43 c, 3 c, 40 c, 1 c, 43 c, 1 c, 44 c, 1 c, 43 c, b c, 40 c, 0 c, c c, 40 c, 1 c, 43 c, 1 c, 44 c, 1 c, 43 c, 3 c, 40 c, 
			1 c, 43 c, 1 c, 44 c, 1 c, 43 c, b c, 40 c, 0 c, c c, 40 c, 1 c, 43 c, 1 c, 44 c, 1 c, 43 c, 3 c, 40 c, 1 c, 43 c, 1 c, 44 c, 1 c, 43 c, b c, 40 c, 0 c, 
			\ first line below leg with 2 wide inner part
			c c, 40 c, 		1 c, 43 c, 		2 c, 44 c, 		1 c, 43 c, 		2 c, 40 c, 		1 c, 43 c, 		2 c, 44 c, 		1 c, 43 c, 
			a c, 40 c, 		0 c, 
			\ second line below leg with 3 wide inner part
			c c, 40 c, 		1 c, 43 c, 		3 c, 44 c, 		1 c, 43 c, 		1 c, 40 c, 		1 c, 43 c, 		3 c, 44 c, 		1 c, 43 c, 
			9 c, 40 c, 		0 c, 
			\ bottom with no inner part
			c c, 40 c, 		5 c, 43 c, 		1 c, 40 c, 		5 c, 43 c, 		9 c, 40 c, 		0 c, 
			
			create tile_Crystal_raw 20 c, 20 c, 20 c, 40 c, 0 c, b c, 40 c, 1 c, 4d c, 14 c, 40 c, 0 c, a c, 40 c, 1 c, 4d c, 1 c, 4e c, 1 c, 4d c, 7 c, 40 c, 1 c, 4d c, b c, 40 c, 0 c, a c, 40 c, 1 c, 4d c, 2 c, 4e c, 1 c, 4d c, 6 c, 40 c, 1 c, 4d c, b c, 
			40 c, 0 c, 9 c, 40 c, 1 c, 4d c, 4 c, 4e c, 1 c, 4d c, 4 c, 40 c, 2 c, 4d c, b c, 40 c, 0 c, 8 c, 40 c, 1 c, 4d c, 6 c, 4e c, 1 c, 4d c, 3 c, 40 c, 1 c, 4d c, 1 c, 4f c, 1 c, 4d c, a c, 40 c, 0 c, 8 c, 40 c, 1 c, 4d c, 6 c, 4e c, 1 c, 4d c, 
			2 c, 40 c, 1 c, 4d c, 2 c, 4f c, 1 c, 4d c, a c, 40 c, 0 c, 8 c, 40 c, 1 c, 4d c, 6 c, 4e c, 1 c, 4d c, 2 c, 40 c, 1 c, 4d c, 2 c, 4f c, 1 c, 4d c, a c, 40 c, 0 c, 8 c, 40 c, 1 c, 4d c, 6 c, 4e c, 1 c, 4d c, 1 c, 40 c, 1 c, 4d c, 3 c, 4f c, 
			1 c, 4d c, a c, 40 c, 0 c, 9 c, 40 c, 1 c, 4d c, 5 c, 4e c, 1 c, 4d c, 1 c, 40 c, 1 c, 4d c, 3 c, 4f c, 1 c, 4d c, a c, 40 c, 0 c, 9 c, 40 c, 1 c, 4d c, 5 c, 4e c, 2 c, 4d c, 4 c, 4f c, 1 c, 4d c, 3 c, 40 c, 1 c, 4d c, 6 c, 40 c, 0 c, 9 c, 
			40 c, 1 c, 4d c, 6 c, 4e c, 1 c, 4d c, 5 c, 4f c, 1 c, 4d c, 1 c, 40 c, 1 c, 4d c, 1 c, 4e c, 2 c, 4d c, 4 c, 40 c, 0 c, 3 c, 40 c, 3 c, 4d c, 3 c, 40 c, 1 c, 4d c, 6 c, 4e c, 1 c, 4d c, 5 c, 4f c, 2 c, 4d c, 4 c, 4e c, 1 c, 4d c, 3 c, 40 c, 
			0 c, 3 c, 40 c, 1 c, 4d c, 2 c, 4f c, 1 c, 4d c, 2 c, 40 c, 1 c, 4d c, 6 c, 4e c, 1 c, 4d c, 4 c, 4f c, 2 c, 4d c, 5 c, 4e c, 1 c, 4d c, 3 c, 40 c, 0 c, 4 c, 40 c, 1 c, 4d c, 1 c, 4f c, 2 c, 4d c, 1 c, 40 c, 1 c, 4d c, 6 c, 4e c, 1 c, 4d c, 
			3 c, 4f c, 1 c, 4d c, 7 c, 4e c, 1 c, 4d c, 3 c, 40 c, 0 c, 4 c, 40 c, 1 c, 4d c, 3 c, 4f c, 1 c, 4d c, 1 c, 40 c, 1 c, 4d c, 5 c, 4e c, 1 c, 4d c, 1 c, 4f c, 2 c, 4d c, 7 c, 4e c, 1 c, 4d c, 4 c, 40 c, 0 c, 5 c, 40 c, 1 c, 4d c, 3 c, 4f c, 
			2 c, 4d c, 5 c, 4e c, 2 c, 4d c, 9 c, 4e c, 1 c, 4d c, 4 c, 40 c, 0 c, 5 c, 40 c, 1 c, 4d c, 4 c, 4f c, 1 c, 4d c, 5 c, 4e c, 1 c, 4d c, a c, 4e c, 1 c, 4d c, 4 c, 40 c, 0 c, 6 c, 40 c, 1 c, 4d c, 3 c, 4f c, 1 c, 4d c, 5 c, 4e c, 1 c, 4d c, 
			9 c, 4e c, 1 c, 4d c, 5 c, 40 c, 0 c, 6 c, 40 c, 1 c, 4d c, 3 c, 4f c, 1 c, 4d c, 6 c, 4e c, 1 c, 4d c, 7 c, 4e c, 1 c, 4d c, 6 c, 40 c, 0 c, 7 c, 40 c, 1 c, 4d c, 2 c, 4f c, 1 c, 4d c, 6 c, 4e c, 1 c, 4d c, 6 c, 4e c, 1 c, 4d c, 7 c, 40 c, 
			0 c, 7 c, 40 c, 1 c, 4d c, 3 c, 4f c, 1 c, 4d c, 5 c, 4e c, 1 c, 4d c, 5 c, 4e c, 1 c, 4d c, 8 c, 40 c, 0 c, 8 c, 40 c, 1 c, 4d c, 2 c, 4f c, 4 c, 4d c, 2 c, 4e c, 1 c, 4d c, 4 c, 4e c, 1 c, 4d c, 9 c, 40 c, 0 c, 8 c, 40 c, 1 c, 4d c, 2 c, 
			4f c, 1 c, 4d c, 2 c, 50 c, 1 c, 4d c, 2 c, 4e c, 3 c, 4d c, 1 c, 4e c, 2 c, 4d c, 9 c, 40 c, 0 c, 7 c, 40 c, 4 c, 4d c, 3 c, 50 c, 4 c, 4d c, 1 c, 50 c, 5 c, 4d c, 8 c, 40 c, 0 c, 6 c, 40 c, 1 c, 4d c, 8 c, 50 c, 2 c, 4d c, 6 c, 50 c, 2 c, 
			4d c, 7 c, 40 c, 0 c, 5 c, 40 c, 1 c, 4d c, 6 c, 50 c, 1 c, 51 c, 8 c, 50 c, 1 c, 51 c, 2 c, 50 c, 2 c, 4d c, 6 c, 40 c, 0 c, 5 c, 40 c, 1 c, 4d c, 1 c, 50 c, 1 c, 52 c, 11 c, 50 c, 1 c, 4d c, 6 c, 40 c, 0 c, 5 c, 40 c, 1 c, 4d c, a c, 50 c, 
			1 c, 52 c, 8 c, 50 c, 1 c, 4d c, 6 c, 40 c, 0 c, 5 c, 40 c, 8 c, 4d c, 6 c, 50 c, 7 c, 4d c, 6 c, 40 c, 0 c, c c, 40 c, 7 c, 4d c, d c, 40 c, 0 c, 20 c, 40 c, 0 c, 
			
			create tile_Ground_raw 20 c, 20 c, 20 c, 53 c, 0 c, f c, 53 c, 1 c, 54 c, 10 c, 53 c, 0 c, 2 c, 53 c, 1 c, 55 c, 1d c, 53 c, 0 c, 20 c, 53 c, 0 c, 17 c, 53 c, 1 c, 55 c, 8 c, 53 c, 0 c, 20 c, 53 c, 0 c, 5 c, 53 c, 1 c, 54 c, 1a c, 53 c, 0 c, 1f c, 
			53 c, 1 c, 54 c, 0 c, b c, 53 c, 1 c, 55 c, 14 c, 53 c, 0 c, 20 c, 53 c, 0 c, 20 c, 53 c, 0 c, 17 c, 53 c, 1 c, 54 c, 8 c, 53 c, 0 c, 11 c, 53 c, 1 c, 55 c, e c, 53 c, 0 c, 3 c, 53 c, 1 c, 55 c, 1c c, 53 c, 0 c, 19 c, 53 c, 1 c, 55 c, 6 c, 
			53 c, 0 c, 1d c, 53 c, 1 c, 55 c, 2 c, 53 c, 0 c, 20 c, 53 c, 0 c, a c, 53 c, 1 c, 54 c, 15 c, 53 c, 0 c, 20 c, 53 c, 0 c, 20 c, 53 c, 0 c, d c, 53 c, 1 c, 55 c, c c, 53 c, 1 c, 54 c, 5 c, 53 c, 0 c, 13 c, 53 c, 1 c, 54 c, c c, 53 c, 0 c, 20 c, 
			53 c, 0 c, 1 c, 55 c, 1f c, 53 c, 0 c, 4 c, 53 c, 1 c, 54 c, 1b c, 53 c, 0 c, 16 c, 53 c, 1 c, 55 c, 9 c, 53 c, 0 c, c c, 53 c, 1 c, 54 c, f c, 53 c, 1 c, 55 c, 3 c, 53 c, 0 c, 20 c, 53 c, 0 c, 20 c, 53 c, 0 c, 20 c, 53 c, 0 c, 15 c, 53 c, 
			1 c, 54 c, a c, 53 c, 0 c, 3 c, 53 c, 1 c, 55 c, 1c c, 53 c, 0 c, 
		
		DictMainRAM
		
	\ 1BPP TILES
		create tile_Hero_target 20 c, 20 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, f c, f0 c, f c, f0 c, f c, f0 c, f c, f0 c, c c, 0 c, 0 c, 30 c, c c, 0 c, 0 c, 30 c, c c, 0 c, 0 c, 30 c, c c, 0 c, 0 c, 30 c, 
		c c, 0 c, 0 c, 30 c, c c, 0 c, 0 c, 30 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, c c, 0 c, 0 c, 30 c, c c, 0 c, 0 c, 30 c, 
		c c, 0 c, 0 c, 30 c, c c, 0 c, 0 c, 30 c, c c, 0 c, 0 c, 30 c, c c, 0 c, 0 c, 30 c, f c, f0 c, f c, f0 c, f c, f0 c, f c, f0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 
		
		DictCharMenu
			create tile_Menu_item_selector 11 c, 11 c, 0 c, 7 c, f0 c, 0 c, 7 c, f0 c, 0 c, 3f c, fe c, 0 c, 3f c, fe c, 0 c, 3f c, fe c, 0 c, ff c, ff c, 80 c, ff c, ff c, 80 c, ff c, ff c, 80 c, ff c, ff c, 80 c, ff c, ff c, 80 c, ff c, ff c, 80 c, ff c, 
			ff c, 80 c, 3f c, fe c, 0 c, 3f c, fe c, 0 c, 3f c, fe c, 0 c, 7 c, f0 c, 0 c, 7 c, f0 c, 0 c, 
		DictGame
		
		DictMainRAM
		
		create tile_Menu_skill_selector 18 c, 18 c, 0 c, 0 c, ff c, 0 c, 0 c, ff c, 0 c, 3f c, ff c, fc c, 3f c, ff c, fc c, 3f c, ff c, fc c, 3f c, ff c, fc c, 3f c, ff c, fc c, 3f c, ff c, fc c, ff c, ff c, ff c, ff c, ff c, ff c, ff c, ff c, ff c, ff c, 
		ff c, ff c, ff c, ff c, ff c, ff c, ff c, ff c, ff c, ff c, ff c, ff c, ff c, ff c, 3f c, ff c, fc c, 3f c, ff c, fc c, 3f c, ff c, fc c, 3f c, ff c, fc c, 3f c, ff c, fc c, 3f c, ff c, fc c, 0 c, ff c, 0 c, 0 c, ff c, 0 c, 
		
		create tile_Exit 20 c, 20 c, 0 c, 7f c, ff c, 0 c, 0 c, 3f c, ff c, 0 c, 1 c, 1f c, ff c, 0 c, 3 c, f c, ff c, 0 c, 7 c, 7 c, ff c, 0 c, f c, 3 c, ff c, 0 c, 1f c, 1 c, ff c, 0 c, 3f c, 0 c, ff c, 0 c, 7f c, 0 c, 7f c, 0 c, ff c, 0 c, 3f c, 1 c, 
		ff c, 0 c, 1f c, 3 c, ff c, 0 c, f c, 7 c, ff c, 0 c, 7 c, f c, ff c, 0 c, 3 c, 1f c, ff c, 0 c, 1 c, 3f c, ff c, 0 c, 0 c, 7f c, ff c, ff c, fe c, 0 c, 0 c, ff c, fc c, 80 c, 0 c, ff c, f8 c, c0 c, 0 c, ff c, f0 c, e0 c, 0 c, ff c, e0 c, f0 c, 
		0 c, ff c, c0 c, f8 c, 0 c, ff c, 80 c, fc c, 0 c, ff c, 0 c, fe c, 0 c, fe c, 0 c, ff c, 0 c, fc c, 0 c, ff c, 80 c, f8 c, 0 c, ff c, c0 c, f0 c, 0 c, ff c, e0 c, e0 c, 0 c, ff c, f0 c, c0 c, 0 c, ff c, f8 c, 80 c, 0 c, ff c, fc c, 0 c, 0 c, 
		ff c, fe c, 
		
		create tile_Res_HP_Heal 10 c, 10 c, 1 c, 7f c, fe c, c0 c, 3 c, 80 c, 1 c, 83 c, c1 c, 83 c, c1 c, 83 c, c1 c, 9f c, f9 c, 9f c, f9 c, 9f c, f9 c, 9f c, f9 c, 83 c, c1 c, 83 c, c1 c, 83 c, c1 c, 80 c, 1 c, c0 c, 3 c, 7f c, fe c, 
		create tile_Res_Batt_Heal 10 c, 10 c, 1 c, 7f c, fe c, c0 c, 3 c, 80 c, 1 c, 83 c, c1 c, 83 c, c1 c, 83 c, c1 c, 9f c, f9 c, 9f c, f9 c, 9f c, f9 c, 9f c, f9 c, 83 c, c1 c, 83 c, c1 c, 83 c, c1 c, 80 c, 1 c, c0 c, 3 c, 7f c, fe c, 
		create tile_Res_HP_Upgrade 10 c, 10 c, 1 c, 7f c, fe c, c0 c, 3 c, 80 c, 1 c, a2 c, 79 c, a2 c, 45 c, a2 c, 45 c, a2 c, 45 c, be c, 79 c, a2 c, 41 c, a2 c, 41 c, a2 c, 41 c, a2 c, 41 c, a2 c, 41 c, 80 c, 1 c, c0 c, 3 c, 7f c, fe c, 
		create tile_Res_Batt_Upgrade 10 c, 10 c, 1 c, 7f c, fe c, c0 c, 3 c, 80 c, 1 c, 87 c, c1 c, 84 c, 21 c, 84 c, 21 c, 84 c, 21 c, 87 c, c1 c, 84 c, 21 c, 84 c, 21 c, 84 c, 21 c, 84 c, 21 c, 87 c, c1 c, 80 c, 1 c, c0 c, 3 c, 7f c, fe c, 
		create tile_Res_Exp_Upgrade 10 c, 10 c, 1 c, 7f c, fe c, c0 c, 3 c, 80 c, 1 c, ba c, b9 c, a2 c, a5 c, a2 c, a5 c, a2 c, a5 c, b9 c, 39 c, a2 c, a1 c, a2 c, a1 c, a2 c, a1 c, a2 c, a1 c, ba c, a1 c, 80 c, 1 c, c0 c, 3 c, 7f c, fe c, 
		create tile_Res_Dmg_Upgrade 10 c, 10 c, 1 c, 7f c, fe c, c0 c, 3 c, 80 c, 1 c, 87 c, 81 c, 84 c, c1 c, 84 c, 61 c, 84 c, 21 c, 84 c, 21 c, 84 c, 21 c, 84 c, 21 c, 84 c, 61 c, 84 c, c1 c, 87 c, 81 c, 80 c, 1 c, c0 c, 3 c, 7f c, fe c, 
		
	\ SKILL TILES
		DictBankROM \ store these tiles in other bank since have to be copied out anyway
		
		\ works
		\ DictSkillsMenu
		\ DictBankROM
		
		\ works
		\ DictSkillsMenu
			\ : test 34 halt drop ;
		\ DictBankROM
		
		\ here u. halt \ 4A16
		\ DictSkillsMenu
			\ : test 34 halt drop ;
			\ here u. halt \ ECB3
		\ DictBankROM
		\ here u. halt \ 4A16
		
		\ DictGame
		
		\ DictBankROM
		
		\ DictMainRAM		
		
	\ NONCOLORABLE TILES
		DictGame
			create tile_Monster 20 c, 20 c, 20 c, 40 c, 0 c, 20 c, 40 c, 0 c, 20 c, 40 c, 0 c, 20 c, 40 c, 0 c, 20 c, 40 c, 0 c, 9 c, 40 c, e c, 0 c, 9 c, 40 c, 0 c, 9 c, 40 c, e c, 0 c, 9 c, 40 c, 0 c, 9 c, 40 c, 2 c, 0 c, 4 c, 3 c, 2 c, 0 c, 4 c, 3 c, 2 c, 
			0 c, 9 c, 40 c, 0 c, 9 c, 40 c, 2 c, 0 c, 4 c, 3 c, 2 c, 0 c, 4 c, 3 c, 2 c, 0 c, 9 c, 40 c, 0 c, 9 c, 40 c, e c, 0 c, 9 c, 40 c, 0 c, 9 c, 40 c, 5 c, 0 c, 4 c, 3 c, 5 c, 0 c, 9 c, 40 c, 0 c, 9 c, 40 c, 4 c, 0 c, 1 c, 3 c, 4 c, 0 c, 1 c, 3 c, 
			4 c, 0 c, 9 c, 40 c, 0 c, 9 c, 40 c, e c, 0 c, 9 c, 40 c, 0 c, 6 c, 40 c, 14 c, 0 c, 6 c, 40 c, 0 c, 5 c, 40 c, 2 c, 0 c, 2 c, 3 c, 1 c, 0 c, c c, 15 c, 1 c, 0 c, 2 c, 3 c, 2 c, 0 c, 5 c, 40 c, 0 c, 4 c, 40 c, 3 c, 0 c, 3 c, 3 c, 2 c, 0 c, 
			8 c, 15 c, 2 c, 0 c, 3 c, 3 c, 3 c, 0 c, 4 c, 40 c, 0 c, 3 c, 40 c, 5 c, 0 c, 4 c, 3 c, 2 c, 0 c, 4 c, 15 c, 2 c, 0 c, 4 c, 3 c, 5 c, 0 c, 3 c, 40 c, 0 c, 2 c, 40 c, 5 c, 0 c, 1 c, 15 c, 2 c, 0 c, 4 c, 3 c, 4 c, 0 c, 4 c, 3 c, 2 c, 0 c, 1 c, 
			15 c, 5 c, 0 c, 2 c, 40 c, 0 c, 1 c, 40 c, 6 c, 0 c, 3 c, 15 c, 1 c, 0 c, a c, 3 c, 1 c, 0 c, 3 c, 15 c, 6 c, 0 c, 1 c, 40 c, 0 c, 1 c, 40 c, 6 c, 0 c, 3 c, 15 c, 1 c, 0 c, a c, 3 c, 1 c, 0 c, 3 c, 15 c, 6 c, 0 c, 1 c, 40 c, 0 c, 1 c, 40 c, 
			4 c, 0 c, 1 c, 40 c, 1 c, 0 c, 1 c, 15 c, 2 c, 0 c, 4 c, 3 c, 4 c, 0 c, 4 c, 3 c, 2 c, 0 c, 1 c, 15 c, 1 c, 0 c, 1 c, 40 c, 4 c, 0 c, 1 c, 40 c, 0 c, 1 c, 40 c, 3 c, 0 c, 2 c, 40 c, 2 c, 0 c, 4 c, 3 c, 2 c, 0 c, 4 c, 15 c, 2 c, 0 c, 4 c, 3 c, 
			2 c, 0 c, 2 c, 40 c, 3 c, 0 c, 1 c, 40 c, 0 c, 1 c, 40 c, 2 c, 0 c, 3 c, 40 c, 1 c, 0 c, 3 c, 3 c, 2 c, 0 c, 8 c, 15 c, 2 c, 0 c, 3 c, 3 c, 1 c, 0 c, 3 c, 40 c, 2 c, 0 c, 1 c, 40 c, 0 c, 6 c, 40 c, 1 c, 0 c, 2 c, 3 c, 1 c, 0 c, c c, 15 c, 1 c, 
			0 c, 2 c, 3 c, 1 c, 0 c, 6 c, 40 c, 0 c, 6 c, 40 c, 14 c, 0 c, 6 c, 40 c, 0 c, 8 c, 40 c, 7 c, 0 c, 2 c, 40 c, 7 c, 0 c, 8 c, 40 c, 0 c, 8 c, 40 c, 7 c, 0 c, 2 c, 40 c, 7 c, 0 c, 8 c, 40 c, 0 c, 8 c, 40 c, 7 c, 0 c, 2 c, 40 c, 7 c, 0 c, 8 c, 
			40 c, 0 c, 8 c, 40 c, 7 c, 0 c, 2 c, 40 c, 7 c, 0 c, 8 c, 40 c, 0 c, 8 c, 40 c, 7 c, 0 c, 2 c, 40 c, 7 c, 0 c, 8 c, 40 c, 0 c, 8 c, 40 c, 7 c, 0 c, 2 c, 40 c, 7 c, 0 c, 8 c, 40 c, 0 c, 8 c, 40 c, 7 c, 0 c, 2 c, 40 c, 7 c, 0 c, 8 c, 40 c, 0 c, 
			
			(
			create tile_Monster_dead 20 c, 20 c, 20 c, 40 c, 0 c, 20 c, 40 c, 0 c, 20 c, 40 c, 0 c, 20 c, 40 c, 0 c, 20 c, 40 c, 0 c, 20 c, 40 c, 0 c, 20 c, 40 c, 0 c, 20 c, 40 c, 0 c, 20 c, 40 c, 0 c, 20 c, 40 c, 0 c, 20 c, 40 c, 0 c, 20 c, 40 c, 0 c, 9 c, 
			40 c, c c, 0 c, b c, 40 c, 0 c, 9 c, 40 c, 1 c, 0 c, 2 c, 2a c, 1 c, 0 c, 1 c, 15 c, 7 c, 0 c, b c, 40 c, 0 c, 2 c, 40 c, 8 c, 0 c, 3 c, 2a c, 6 c, 0 c, 1 c, 2a c, 1 c, 0 c, b c, 40 c, 0 c, 2 c, 40 c, 9 c, 0 c, 1 c, 2a c, 6 c, 0 c, 1 c, 2a c, 
			a c, 0 c, 3 c, 40 c, 0 c, 2 c, 40 c, 8 c, 0 c, 1 c, 15 c, 6 c, 0 c, 1 c, 2a c, 1 c, 0 c, 1 c, 15 c, 9 c, 0 c, 3 c, 40 c, 0 c, 2 c, 40 c, 8 c, 0 c, 1 c, 15 c, 5 c, 0 c, 2 c, 2a c, 1 c, 0 c, 1 c, 15 c, 5 c, 0 c, 1 c, 2a c, 1 c, 0 c, 1 c, 2a c, 
			1 c, 0 c, 3 c, 40 c, 0 c, 2 c, 40 c, 8 c, 0 c, 2 c, 15 c, 1 c, 0 c, 4 c, 2a c, 1 c, 0 c, 2 c, 15 c, 6 c, 0 c, 1 c, 2a c, 2 c, 0 c, 3 c, 40 c, 0 c, 2 c, 40 c, 8 c, 0 c, 2 c, 15 c, 1 c, 0 c, 4 c, 2a c, 1 c, 0 c, 2 c, 15 c, 2 c, 0 c, 1 c, 2a c, 
			2 c, 0 c, 1 c, 2a c, 1 c, 0 c, 1 c, 2a c, 1 c, 0 c, 3 c, 40 c, 0 c, 2 c, 40 c, 8 c, 0 c, 3 c, 15 c, 1 c, 0 c, 2 c, 2a c, 1 c, 0 c, 3 c, 15 c, 3 c, 0 c, 1 c, 2a c, 5 c, 0 c, 3 c, 40 c, 0 c, 9 c, 40 c, 1 c, 0 c, 3 c, 15 c, 1 c, 0 c, 2 c, 2a c, 
			1 c, 0 c, 3 c, 15 c, 3 c, 0 c, 1 c, 2a c, 5 c, 0 c, 3 c, 40 c, 0 c, 9 c, 40 c, 1 c, 0 c, 3 c, 15 c, 1 c, 0 c, 2 c, 2a c, 1 c, 0 c, 3 c, 15 c, 3 c, 0 c, 1 c, 2a c, 5 c, 0 c, 3 c, 40 c, 0 c, 2 c, 40 c, 8 c, 0 c, 3 c, 15 c, 1 c, 0 c, 2 c, 2a c, 
			1 c, 0 c, 3 c, 15 c, 3 c, 0 c, 1 c, 2a c, 1 c, 0 c, 1 c, 2a c, 1 c, 0 c, 1 c, 2a c, 1 c, 0 c, 3 c, 40 c, 0 c, 2 c, 40 c, 8 c, 0 c, 2 c, 15 c, 1 c, 0 c, 4 c, 2a c, 1 c, 0 c, 2 c, 15 c, 2 c, 0 c, 1 c, 2a c, 3 c, 0 c, 1 c, 2a c, 2 c, 0 c, 3 c, 
			40 c, 0 c, 2 c, 40 c, 8 c, 0 c, 2 c, 15 c, 1 c, 0 c, 4 c, 2a c, 1 c, 0 c, 2 c, 15 c, 5 c, 0 c, 1 c, 2a c, 1 c, 0 c, 1 c, 2a c, 1 c, 0 c, 3 c, 40 c, 0 c, 2 c, 40 c, 8 c, 0 c, 1 c, 15 c, 5 c, 0 c, 2 c, 2a c, 1 c, 0 c, 1 c, 15 c, 9 c, 0 c, 3 c, 
			40 c, 0 c, 2 c, 40 c, 8 c, 0 c, 1 c, 15 c, 6 c, 0 c, 1 c, 2a c, 1 c, 0 c, 1 c, 15 c, 9 c, 0 c, 3 c, 40 c, 0 c, 2 c, 40 c, 9 c, 0 c, 1 c, 2a c, 6 c, 0 c, 1 c, 2a c, a c, 0 c, 3 c, 40 c, 0 c, 2 c, 40 c, 8 c, 0 c, 3 c, 2a c, 6 c, 0 c, 1 c, 2a c, 
			1 c, 0 c, b c, 40 c, 0 c, 9 c, 40 c, 1 c, 0 c, 2 c, 2a c, 1 c, 0 c, 1 c, 15 c, 7 c, 0 c, b c, 40 c, 0 c, 9 c, 40 c, c c, 0 c, b c, 40 c, 0 c, 
			)
			
		DictCharMenu
			create tile_Menu_item_slot 
			10 c, 10 c, 10 c, 0 c, 0 c, 1 c, 0 c, f c, 8 c, 0 c, 1 c, 0 c, 1 c, 8 c, d c, 0 c, 1 c, 8 c, 0 c, 1 c, 0 c, 1 c, 8 c, 1 c, 0 c, b c, 4 c, 1 c, 0 c, 1 c, 8 c, 0 c, 1 c, 0 c, 1 c, 8 c, 1 c, 0 c, b c, 4 c, 1 c, 0 c, 1 c, 
			8 c, 0 c, 1 c, 0 c, 1 c, 8 c, 1 c, 0 c, b c, 4 c, 1 c, 0 c, 1 c, 8 c, 0 c, 1 c, 0 c, 1 c, 8 c, 1 c, 0 c, b c, 4 c, 1 c, 0 c, 1 c, 8 c, 0 c, 1 c, 0 c, 1 c, 8 c, 1 c, 0 c, b c, 4 c, 1 c, 0 c, 1 c, 8 c, 0 c, 1 c, 0 c, 1 c, 8 c, 1 c, 0 c, b c, 
			4 c, 1 c, 0 c, 1 c, 8 c, 0 c, 1 c, 0 c, 1 c, 8 c, 1 c, 0 c, b c, 4 c, 1 c, 0 c, 1 c, 8 c, 0 c, 1 c, 0 c, 1 c, 8 c, 1 c, 0 c, b c, 4 c, 1 c, 0 c, 1 c, 8 c, 0 c, 1 c, 0 c, 1 c, 8 c, 1 c, 0 c, b c, 4 c, 1 c, 0 c, 1 c, 8 c, 0 c, 1 c, 0 c, 1 c, 
			8 c, 1 c, 0 c, b c, 4 c, 1 c, 0 c, 1 c, 8 c, 0 c, 1 c, 0 c, 1 c, 8 c, 1 c, 0 c, b c, 4 c, 1 c, 0 c, 1 c, 8 c, 0 c, 1 c, 0 c, 1 c, 8 c, d c, 0 c, 1 c, 8 c, 0 c, 1 c, 0 c, f c, 8 c, 0 c, 
				
		DictGame
			create tile_Crystal_base 
			20 c, 20 c, 20 c, 40 c, 0 c, 20 c, 40 c, 0 c, 20 c, 40 c, 0 c, 20 c, 40 c, 0 c, 20 c, 40 c, 0 c, 20 c, 40 c, 0 c, 20 c, 40 c, 0 c, 20 c, 40 c, 0 c, 20 c, 40 c, 0 c, 20 c, 40 c, 0 c, 20 c, 40 c, 0 c, 20 c, 40 c, 0 c, 20 c, 
			40 c, 0 c, 20 c, 40 c, 0 c, 20 c, 40 c, 0 c, 20 c, 40 c, 0 c, 20 c, 40 c, 0 c, 20 c, 40 c, 0 c, 20 c, 40 c, 0 c, 20 c, 40 c, 0 c, 20 c, 40 c, 0 c, 20 c, 40 c, 0 c, b c, 40 c, 4 c, 0 c, 11 c, 40 c, 0 c, b c, 40 c, 1 c, 0 c, 2 c, 21 c, 1 c, 0 c, 
			2 c, 40 c, 3 c, 0 c, 1 c, 40 c, 2 c, 0 c, 9 c, 40 c, 0 c, 7 c, 40 c, 4 c, 0 c, 3 c, 21 c, 4 c, 0 c, 1 c, 21 c, 5 c, 0 c, 8 c, 40 c, 0 c, 6 c, 40 c, 1 c, 0 c, 8 c, 21 c, 2 c, 0 c, 6 c, 21 c, 2 c, 0 c, 7 c, 40 c, 0 c, 5 c, 40 c, 1 c, 0 c, 6 c, 
			21 c, 1 c, 2 c, 8 c, 21 c, 1 c, 2 c, 2 c, 21 c, 2 c, 0 c, 6 c, 40 c, 0 c, 5 c, 40 c, 1 c, 0 c, 1 c, 21 c, 1 c, 20 c, 11 c, 21 c, 1 c, 0 c, 6 c, 40 c, 0 c, 5 c, 40 c, 1 c, 0 c, a c, 21 c, 1 c, 20 c, 8 c, 21 c, 1 c, 0 c, 6 c, 40 c, 0 c, 5 c, 
			40 c, 8 c, 0 c, 6 c, 21 c, 7 c, 0 c, 6 c, 40 c, 0 c, c c, 40 c, 7 c, 0 c, d c, 40 c, 0 c, 20 c, 40 c, 0 c, 
		
		DictMainRAM	
			create tiles
				tile_Ground_0 ,
				tile_Ground_90 ,
				tile_Ground_180 ,
				tile_Ground_270 ,
				tile_Rock ,
				tile_Lava ,
				tile_Crystal_red ,
				tile_Crystal_yellow ,
				tile_Crystal_blue ,
				tile_Robot_left ,
				tile_Robot_right ,
				\ tile_Menu_head_temp ,
				\ tile_Menu_body_temp ,
				\ tile_Menu_legs_temp ,
				\ tile_Menu_gun_temp ,
				\ tile_Menu_tool_temp ,
				tile_Menu_item_temp ,
				tile_Skill_temp ,
							
				\ Colorable tiles
				tile_Menu_head ,
				tile_Menu_body ,
				tile_Menu_legs ,
				tile_Menu_gun ,
				tile_Menu_tool ,
				tile_Robot_left_raw ,
				tile_Robot_right_raw ,
				tile_Crystal_raw ,
				tile_Ground_raw ,
				
				\ Non-colorable tiles in RAM
				tile_Monster ,
				tile_Monster ,
				\ tile_Monster_dead ,
				
				EnableCharMenuROM
					tile_Menu_item_slot ,
				EnableGameROM
				\ tile_Monster ,				\ dummy value. crashes without this. no clue why 0_0
				tile_Crystal_base ,
				
				\ 1bpp tiles
				tile_Hero_target ,
				EnableCharMenuROM
					tile_Menu_item_selector ,
				EnableGameROM
				tile_Menu_skill_selector ,
				tile_Exit ,
				tile_Res_HP_Heal ,
				tile_Res_HP_Upgrade ,	
				tile_Res_Batt_Heal ,
				tile_Res_Batt_Upgrade ,	
				tile_Res_Exp_Upgrade ,
				tile_Res_Dmg_Upgrade ,
				\ EnableSkillsMenuROM
					\ tile_Skill0 ,
					\ tile_Skill1 ,
					\ tile_Skill2 ,
					\ tile_Skill3 ,
					\ tile_Skill4 ,
					\ tile_Skill5 ,
					\ tile_Skill6 ,
					\ tile_Skill7 ,
					\ tile_Skill8 ,
					\ tile_Skill9 ,
					\ tile_Skill10 ,
					\ tile_Skill11 ,
					\ tile_Skill12 ,
					\ tile_Skill13 ,
					\ tile_Skill14 ,
				\ EnableGameROM
		DictMainRAM
		
	\ ITEM COLORS
		DictBankROM
			create color_Basic_Head head c, 5 c, 49 c, 15 c, 4a c, 2a c, 48 c, 2a c, 47 c, c c, 4b c, 3f c, 
			create color_Head_MKII head c, 5 c, 49 c, 15 c, 4a c, 3a c, 48 c, 3a c, 47 c, 30 c, 4b c, 3f c, 
			create color_Head_MKIII head c, 5 c, 49 c, 15 c, 4a c, 35 c, 48 c, 35 c, 47 c, f c, 4b c, 3f c, 
			create color_Head_MKIV head c, 5 c, 49 c, 15 c, 4a c, 20 c, 48 c, 20 c, 47 c, 32 c, 4b c, 3f c, 
			create color_Lightning head c, 5 c, 49 c, 30 c, 4a c, 3f c, 48 c, 3f c, 47 c, 30 c, 4b c, 3 c, 
			create color_Basic_Body body c, 2 c, 41 c, 15 c, 42 c, 2a c, 
			create color_Tin_Body body c, 2 c, 41 c, 15 c, 42 c, 2b c, 
			create color_Iron_Body body c, 2 c, 41 c, 15 c, 42 c, 17 c, 
			create color_Steel_Body body c, 2 c, 41 c, 15 c, 42 c, 2 c, 
			create color_Fortress body c, 2 c, 41 c, 3 c, 42 c, 3f c, 
			create color_Basic_Legs legs c, 2 c, 43 c, 15 c, 44 c, 2a c, 
			create color_Fast_Legs legs c, 2 c, 43 c, 15 c, 44 c, 2e c, 
			create color_Quick_Legs legs c, 2 c, 43 c, 15 c, 44 c, 1d c, 
			create color_Agile_Legs legs c, 2 c, 43 c, 15 c, 44 c, 8 c, 
			create color_Mustang legs c, 2 c, 43 c, c c, 44 c, 3f c, 
			create color_Basic_Gun gun c, 2 c, 45 c, 15 c, 46 c, 2a c, 
			create color_Blaster gun c, 2 c, 45 c, 15 c, 46 c, 3b c, 
			create color_Laser gun c, 2 c, 45 c, 15 c, 46 c, 37 c, 
			create color_Phaser gun c, 2 c, 45 c, 15 c, 46 c, 22 c, 
			create color_Death_Ray gun c, 2 c, 45 c, 32 c, 46 c, 3f c, 
			create color_Basic_Tool tool c, 1 c, 4c c, 2a c, 
			create color_Rock_Pick tool c, 1 c, 4c c, 2f c, 
			create color_Rock_Drill tool c, 1 c, 4c c, 1f c, 
			create color_Rock_Borer tool c, 1 c, 4c c, a c, 
			create color_Laser_Bit tool c, 1 c, 4c c, f c, 
			create color_Ground_0 ground c, 3 c, 53 c, 3b c, 54 c, 20 c, 55 c, 2 c, 
			create color_Ground_90 ground c, 3 c, 53 c, 3b c, 54 c, 2 c, 55 c, 8 c, 
			create color_Ground_180 ground c, 3 c, 53 c, 3b c, 54 c, 8 c, 55 c, a c, 
			create color_Ground_270 ground c, 3 c, 53 c, 3b c, 54 c, a c, 55 c, 20 c, 
			create color_Crystal_red crystal c, 5 c, 50 c, 21 c, 52 c, 20 c, 51 c, 2 c, 4e c, 17 c, 4f c, 2b c, 
			create color_Crystal_yellow crystal c, 5 c, 50 c, 21 c, 52 c, 20 c, 51 c, 2 c, 4e c, 1f c, 4f c, 2f c, 
			create color_Crystal_blue crystal c, 5 c, 50 c, 21 c, 52 c, 20 c, 51 c, 2 c, 4e c, 35 c, 4f c, 3a c, 
			create color_Rock_tile ground c, 3 c, 53 c, 21 c, 54 c, 32 c, 55 c, 20 c, 
			create color_Lava_tile ground c, 3 c, 53 c, b c, 54 c, 2 c, 55 c, f c, 
				
	\ COLOR TABLES
		create tile_colors
			color_Ground_0 ,
			color_Ground_90 ,
			color_Ground_180 ,
			color_Ground_270 ,
			color_Rock_tile ,
			color_Lava_tile ,
			color_Crystal_red ,
			color_Crystal_yellow ,
			color_Crystal_blue ,
			
		create item_colors
			color_Basic_Head ,
			color_Head_MKII ,
			color_Head_MKIII ,
			color_Head_MKIV ,
			color_Lightning ,
			color_Basic_Body ,
			color_Tin_Body ,
			color_Iron_Body ,
			color_Steel_Body ,
			color_Fortress ,
			color_Basic_Legs ,
			color_Fast_Legs ,
			color_Quick_Legs ,
			color_Agile_Legs ,
			color_Mustang ,
			color_Basic_Gun ,
			color_Blaster ,
			color_Laser ,
			color_Phaser ,
			color_Death_Ray ,
			color_Basic_Tool ,
			color_Rock_Pick ,
			color_Rock_Drill ,
			color_Rock_Borer ,
			color_Laser_Bit ,
			
		DictMainRAM
		
		(
		\ SKILL INFO
		create Skill0 Battery Saver c, 20% chance that$mining won't$consume energy c, 
		create Skill1 Bounty Hunter c, 10% chance of$mineral when$you kill an$enemy c, 
		create Skill2 Fast Digger c, -2 Mine and$Drill time c, 
		create Skill3 Lucky Driller c, 25% chance of$mineral when$mining rock c, 
		create Skill4 Master Miner c, Mine double$minerals c, 
		create Skill5 Lucky Crit c, +20% chance of$critical hit c, 
		create Skill6 Crit Lord c, Crit damage$raised from$150% to 200% c, 
		create Skill7 Experienced c, +10% bonus to$experience on$kill c, 
		create Skill8 Instakill c, 5% chance to$kill enemy in$one hit c, 
		create Skill9 Ghost c, Walk through$enemies c, 
		create Skill10 Free Lunch c, 20% chance that$crafting will$cost nothing c, 
		create Skill11 Wise Rewards c, +5 random$mineral when$leveling up c, 
		create Skill12 Big Discount c, -1 to cost of$items c, 
		create Skill13 Only the Best c, 10% chance$that crafted$items will be$yellow quality c, 
		create Skill14 Crystalsmith c, Pay with any$crystal c, 
		
		\ RES COLORS
		create 8 35 c, 32 c, a c, 2a c, 2a c, 
		)

	\ Variables	
		begin_var
			var display_X
			var display_Y
			
			var hero_X
			var hero_Y
			\ variable hero_HP
			\ variable hero_HP_Max
			var hero_HP_Max_temp
			var hero_HP_Upgrade
			var hero_Batt
			var hero_Batt_Max
			var hero_Batt_Upgrade
			var hero_Dmg
			var hero_Dmg_Upgrade
			var hero_Mine_Speed
			var hero_Drill_Speed
			var hero_Lava_Res
			var hero_Batt_Recharge
			var hero_Crit_Rate
			var hero_HP_Recharge
			\ variable hero_Lava_Dmg
			var hero_Dmg_Cost
			var hero_Mine_Cost
			var hero_Drill_Cost
			var hero_Exp
			var hero_Exp_Max
			var hero_Level
			var hero_Red
			var hero_Blue
			var hero_Yellow
			var hero_Points
			var hero_facing
			var hero_target_direction
			var hero_target_type
			var hero_target_index
			var hero_target_index2
			var hero_activity
			
			var draw_X
			
			var menu_char_x
			var menu_char_y
			var menu_skills_x
			var menu_skills_y
			var menu_res_x
			var menu_res_y
			var menu_res_target
			
			var output_mode	
			
			\ local temp variables used by various words
			var color1
			var color2
			var width
			var height
			var edge
			var bit_counter
			
			\ local variables for DrawText
			var fg_color
			var bg_color
			var stat1
			var stat1b
			var stat2
			var stat2b
			var text_buff
			var text_buff_1
			var text_buff_2
			var text_buff_len
			var num_yet
			
			\ temp storage for item data in bank 2
			var item_type
			var item_cost
			var item_cost_type
			var item_quality
			var item_stat_count
			var item_stat1
			var item_stat1_x
			var item_stat2
			var item_stat2_x
			var item_stat3
			var item_stat3_x
			
			\ local variables for CalcStats
			var Mine1s
			var Drill1s
			
		end_var
		
		variable hero_HP
		variable hero_HP_Max
		variable hero_Lava_Dmg			
		variable hero_activity_ticks
		variable hero_activity_ticks_max
		create hero_equipped 5 allot
		create hero_inventory INVENTORY_COUNT allot
		
		create skill_list SKILL_COUNT allot
				
		DictBankROM
			3 const MONSTER_STAT_COUNT
			create monsters MONSTER_COUNT MONSTER_STAT_COUNT * allot
			: monster_stat_base ( index -- addr )
				MONSTER_STAT_COUNT * monsters + ;
			: monster.x monster_stat_base ; ( index -- x addr )
			: monster.y monster_stat_base 1+ ; ( index -- y addr )
			: monster.alive monster_stat_base 2 + ; ( index -- alive addr )
			
			4 const CRYSTAL_STAT_COUNT
			create crystals CRYSTAL_COUNT CRYSTAL_STAT_COUNT * allot
			: crystal_stat_base ( index -- addr )
				CRYSTAL_STAT_COUNT * crystals + ;
			: crystal.x crystal_stat_base ; ( index -- x addr )
			: crystal.y crystal_stat_base 1+ ; ( index -- y addr )
			: crystal.active crystal_stat_base 2 + ; ( index -- active addr )
			: crystal.color crystal_stat_base 3 + ; ( index -- color addr )
			
			create map_data MAP_WIDTH MAP_HEIGHT * allot
			create crystal_map MAP_WIDTH MAP_HEIGHT * allot
			create monster_map MAP_WIDTH MAP_HEIGHT * allot
		DictMainRAM
		create map_data_temp SCREEN_WIDTH allot
		create crystal_map_temp SCREEN_WIDTH allot
		create monster_map_temp SCREEN_WIDTH allot
		create str_buffer 18 allot
		\ DictMainRAM

	\ General game words (below words rely on them)
		: rand ( -- rand_val )
		
			\ does not error here
			map_data \ xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
		
			rand_val @
			dup 7 lshift xor
			dup 9 rshift xor
			dup 8 lshift xor
			dup rand_val ! ;
			
		: rand8 ( rand_max -- rand_val )
			rand 0 rot um/mod drop ;					\ maintains compatibility with C version
			
		: rand5050 ( -- rand_val )
			rand 2 mod ;
	
	\ Primitive drawing words
	
		: DrawRect ( x y width height color -- )
			-rot >>>r							\ save color width height
			SCREEN_WIDTH * + 					\ x,y offset into screen
			SCREEN_ADDRESS +
			r>> swap r>							\ screenaddr width color height
			0 do
				3dup fill						\ draw horizontal line
				rot SCREEN_WIDTH + -rot			\ next row
			loop 3drop ;
		
		: clrscr ( color -- )
			\ 6,290,402 cycles so 2x slower than C
			(
			SCREEN_ADDRESS
			SCREEN_HEIGHT 0 do
				SCREEN_WIDTH 0 do
					2dup c! 1+
				loop
			loop
			2drop ;
			)
			\ 1,347,946 - faster than C!
			\ faster than memset though?
			SCREEN_ADDRESS
			SCREEN_HEIGHT SCREEN_WIDTH * 
			rot fill ;
	
	\ Tile words
			
		: TileID> ( ID -- addr)					\ look up tile address from ID
			cells tiles + @ ;
		
		: TileHW ( addr -- addr+2 w h)			\ generate  pointer to pixel data, width, height
			\ dup c@ >r 1+						\ get width
			\ dup c@ >r 1+						\ get height
			\ r>> swap ;
			dup c@ swap 1+
			dup c@ swap 1+
			-rot ;
		
		\ : ColorID>	( ID -- addr )				\ look up color address from ID
		\ 	cells tile_colors + @ ;
		
		: CopyByte	( source dest -- source+1 dest+1 byte )
			over c@ dup >r over c!				\ get byte from source and write to dest
			1+ swap 1+ swap						\ advance pointers
			r> ;								\ retain copy of byte 
		
		: CopyTile ( sourceID destID -- )
			TileID> >r							\ save dest address
			TileID>	TileHW						\ get pointer to source pixel data, width, height
			swap r@ c!							\ copy width to dest
			dup r@ 1+ c!						\ copy height to dest
			r> 2 + swap							\ stack: source dest height
			0 do
				begin
					CopyByte					\ copy length byte and leave copy of byte on stack
				while
					CopyByte					\ copy color byte
					drop						\ don't need copy of copied byte
				repeat
			loop 2drop ;
		
		: ColorTile ( tileID colorID -- )
			\ ColorID>							\ get address of color table from ID
			over
			case
				Robot_left of item_colors endof
				Robot_right of item_colors endof
				\ Menu_head_temp of item_colors endof
				\ Menu_body_temp of item_colors endof
				\ Menu_legs_temp of item_colors endof
				\ Menu_gun_temp of item_colors endof
				\ Menu_tool_temp of item_colors endof
				Menu_item_temp of item_colors endof
				\ default
				tile_colors swap
			endcase
			swap cells + @						\ get address of color data from color list
			1+ dup c@							\ fetch length of color table
			swap 1+								\ point to color pairs
			rot
			TileID> TileHW nip					\ stack: colorsize colorpairs tileaddr height
			0 do
				begin
					dup c@						\ get first byte of length,color pair
					swap 1+	swap				\ increment tile pointer
				while
					rot dup >r -rot				\ get size of color table
					r> 0 do						\ stack: colorsize colorpairs tileaddr
						2dup c@					\ get color from tile
						swap i 2* + dup >r c@	\ look up match color in color pair and save address
						= if 					\ if pair matches pixel from tile
							r> 1+ c@			\ get color to change pixel to from pair
							over c!				\ store in tile
							leave
						then
						r> drop					\ get rid of unused address
					loop
					1+							\ move past color to next length,color pair
				repeat							\ stack: colorsize colorpairs tileaddr
			loop 
			3drop ;
		
		\ Saves 64 bytes
		: DrawTile_pre ( x y tileID -- screen_addr tile_addr width height )
			TileID>								\ look up tile address from ID
			-rot SCREEN_WIDTH * +				\ calculate screen address
			SCREEN_ADDRESS + 
			swap TileHW ;						\ get pointer to pixel data, width, height
		
		: DrawTile ( x y tileID -- )
			DrawTile_pre
			
			0 do								\ stack: screen tile width
				begin
					over c@						\ get length of length,color pair
				while							\ 0 length means line is finished, so draw pairs until then
					-rot 						\ stack: width screen tile
					dup c@ >r 1+				\ save length of length,color pair, advance tile pointer
					dup c@ >r 1+				\ save color of length,color pair, advance tile pointer
					-rot r>> swap				\ stack: tile width screen length color
					dup COLOR_TRANSPARENT = if	\ don't draw if color is transparent
						drop					\ don't need color
						+						\ add width to screen pointer
						-rot					\ stack: screen tile width
					else
						swap
						-rot swap rot
						0 do					\ stack: tile width color screen
							2dup c!				\ draw pixel
							1+ 					\ advance screen pointer
						loop	
						nip						\ color
						-rot					\ stack: screen tile width
					then 
				repeat
				\ 0 length pixel hit which indicates line done
				rot 							\ stack: tile width screen
				over - SCREEN_WIDTH + 			\ go to next screen line
				rot 1+							\ advance tile pointer
				rot								\ stack: screen tile width
			loop 
			3drop ;
		
		: DrawColor ( screen_addr tile_addr color_addr -- screen_addr tile_addr )
			c@ dup COLOR_TRANSPARENT <> if		\ screen_addr tile_addr color
				rot swap over 					\ tile_addr screen_addr color screen_addr
				c!								\ screen_addr tile_addr
			else
				drop swap
			then 
			1+ swap ;							\ increment screen_ptr
			
			
		: DrawTile1bpp ( x y color1 color2 tileID -- )
			-rot color2 c! color1 c!
			DrawTile_pre 						\ screen_addr tile_addr width height
			height c!							\ save height
			width c!							\ save width
			dup c@ edge c! 1+					\ screen_addr tile_addr
			width c@ dup 8 / 
			swap 8 mod 0<> if 1+ then			\ screen_addr tile_addr byte_count
			height c@ 0 do						\ loop through rows
				dup >r 							\ save byte_count
				width c@ bit_counter c!			\ count of bits
				0 do							\ loop through bytes
					dup 1+ swap c@				\ screen_addr tile_addr pixel_data
					8 0 do						\ loop through bits in byte
						dup >r 80 and if		\ screen_addr tile_addr pixel_data
							color1
						else
							color2
						then					\ screen_addr tile_addr color
						DrawColor				\ screen_addr tile_addr
						r> 1 lshift				\ screen_addr tile_addr pixel_data
						bit_counter c@ 1- dup	\ stop when bit count hit
						0= if
							drop leave
						else
							bit_counter c!
						then
					loop						\ loop through bits in byte
					drop 						\ screen_addr tile_addr
				loop							\ loop through bytes
				r>								\ screen_addr tile_addr byte_count
				rot SCREEN_WIDTH + 				\ advance row
				width c@ - -rot
			loop
			3drop
			;
		
		DictBankROM
			: ScreenColor ( screen_ptr i -- color )
			
				\ what the heck???? below works if this uncommented
				\ map_data \ xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
			
				SCREEN_WIDTH * + c@ ;
			
			\ MUST BE IN BANK 2 NOT BANK 3!!!
			: RotateTile90 ( sourceID destID -- )
				\ switch in lower half of graphics RAM long enough to use for tile
				bank_gfx_ram2 bank3
				
				over 0 40 rot DrawTile						\ draw source tile temporarily
				TileID> swap TileID> TileHW					\ dest_addr source_addr w h
				rot drop >r swap 							\ w dest_addr (h on rstack)
				2dup c!	1+ r@ over c! 1+					\ store width and height
				[ SCREEN_WIDTH 40 * ]						\ calculate pointer into screen
				[ SCREEN_ADDRESS + ] LITERAL				\ width dest_addr screen_ptr
				r> 0 do										\ loop through rows
					rot dup >r over r@ 1- 					\ get color pixel_color and init pixel_count
					ScreenColor 0 r>						\ dest_addr screen_ptr width pixel_color pixel_count width
					0 swap 1- do
						>>r -rot r>> swap rot				\ width dest_addr pixel_count pixel_color screen_ptr
						2dup i ScreenColor = if				\ if colors equal
							rot 1+ -rot 					\ increase pixel count
							-rot swap >>r rot r>>			\ dest_addr screen_ptr width pixel_color pixel_count
							\ ."    +1" CR
						else								\ width dest_addr pixel_count pixel_color screen_ptr
							>>r over 
							\ over ."    count:" .
							c! 1+							\ store count at dest (width dest_addr (r:pixel_color screen_ptr))
							r> over 
							\ over ."    color:" . CR
							c! 1+							\ store color at dest (width dest_addr (r: screen_ptr)
							r> dup i ScreenColor			\ get color from next pixel 
							>r rot r> 1						\ dest_addr screen_ptr width pixel_color pixel_count
						then
					-1 +loop
					dup 0= if
						2drop rot							\ screen_ptr width dest_addr
					else
						swap >>r rot r> over c!				\ screen_ptr width dest_addr (r:pixel_color)
						1+ r> over c! 1+ 					\ screen_ptr width dest_addr
					then 	
					0 over c! 1+							\ row terminating 0 to dest_addr
					rot	1+									\ width dest_addr screen_ptr
				loop 3drop
				
				\ restore bank ROM
				bank_gen_ram3 bank3
				
				;
		
			\ : RotateTile90_var ;
				\ does using local vars save time/space?
		
			: LoadTiles ( -- )
				Ground_raw Ground_0 CopyTile
				Ground_0 Ground_90 RotateTile90
				Ground_90 Ground_180 RotateTile90
				Ground_180 Ground_270 RotateTile90
				Ground_raw Rock CopyTile
				Ground_raw Lava CopyTile
				
				Ground_0 dup ColorTile
				Ground_90 dup ColorTile 
				Ground_180 dup ColorTile 
				Ground_270 dup ColorTile 
				Rock dup ColorTile
				Lava dup ColorTile
				;
		DictMainRAM
		
	\ Map words
		DictBankROM		
			: MapHorizStripe ( tile_type -- )
				MAP_WIDTH rand8					\ random starting X
				MAP_HEIGHT rand8				\ random starting Y
				MAP_LAVA_SIZE 1- rand8 1+		\ random stripe width
				MAP_LAVA_SIZE 1- rand8 1+		\ random stripe height
				rand5050 if -1 else 1 then		\ random change in X
				rand5050 if -1 else 1 then		\ random change in Y				
				
				2swap							\ above calls need to be in same order as original for same map
				0 do
					dup 
					0 do						\ stack: tile X Y dx dy width
						>>>r					\ save dx dy width
						2dup 
						0 MAP_HEIGHT within		\ Y offset into map
						swap 0 MAP_WIDTH within	\ X offset into map
						and if					\ bounds check
							over map_data +
							over MAP_WIDTH * +	
							>r rot dup r> c! 	\ store tile
							-rot				\ tile X Y (r: dx dy width)
						then
						swap r@ + swap			\ add dx to X
						r>>>
					loop						\ stack: tile X Y dx dy width
					>r swap >>r r@ +			\ add dy to Y
					r>> swap r>					\ stack: tile X Y dx dy width
				loop							\ stack: tile X Y dx dy width
				3drop 3drop
			;
			
			: MakeMap ( -- )
				map_data						\ address for fill
				MAP_HEIGHT MAP_WIDTH *			\ n for fill
				MAP_BLANK fill 					\ char for fill
				
				MAP_LAVA_COUNT 0 do
					MAP_LAVA MapHorizStripe
				loop
				
				MAP_WALL_COUNT 0 do
					MAP_ROCK MapHorizStripe
				loop
				
				\ change blank to other blank tiles
				map_data
				MAP_HEIGHT 0 do
					MAP_WIDTH 0 do
						dup c@ MAP_BLANK = if
							\ 4 rand8 case
								\ 0 of MAP_BLANK endof
								\ 1 of MAP_BLANK_90 endof
								\ 2 of MAP_BLANK_180 endof
								\ 3 of MAP_BLANK_270 endof
							\ endcase
							4 rand8
							over c!
						then
						1+										\ advance map_data pointer
					loop
				loop
				drop
				
				\ make sure player starting square is blank
				MAP_BLANK
				map_data HERO_START_X + 
				HERO_START_Y MAP_WIDTH * + c! ;
			
			: CheckForMonster ( x y -- monster? )
				MAP_WIDTH * monster_map + + c@
				NO_MONSTER <>  ;
			
			: CheckForCrystal ( x y -- crystal? )
				MAP_WIDTH * crystal_map + + c@
				NO_CRYSTAL <>  ;
			
			: LoadCommon ( x y -- x y free? )
				2dup HERO_START_Y c@ =					\ if x,y not hero start x,y
				swap HERO_START_X c@ =
				and invert >r
				
				2dup CheckForMonster invert >r		 	\ and if no monster at x,y
				2dup MAP_WIDTH * map_data + + c@		\ stack: x y tile
				
				dup MAP_BLANK = swap					\ and if tile is blank, not rock
				dup MAP_BLANK_90 = swap
				dup MAP_BLANK_180 = swap
					MAP_BLANK_270 = swap
					
				or or or r>> and and ;
				
			: LoadMonsters ( -- )
				\ mark map as no monsters
				monster_map
				[ MAP_WIDTH MAP_HEIGHT * ] literal		\ entire map
				NO_MONSTER fill
				
				MONSTER_COUNT 0 do
					MAP_WIDTH rand8
					MAP_HEIGHT rand8
					
					LoadCommon
					if
						2dup
						i monster.y c!					\ store y coordinate
						i monster.x c!					\ store x coordinate
						true i monster.alive c!			\ set to alive
						MAP_WIDTH * + monster_map +
						i swap c!
						1								\ loop increment
					else
						2drop 0							\ loop increment
					then
				+loop 
				;
				
			: LoadCrystals ( -- )
				\ mark map as no crystals
				crystal_map
				[ MAP_WIDTH MAP_HEIGHT * ] literal 		\ entire map
				NO_CRYSTAL fill
				
				CRYSTAL_COUNT 0 do
					MAP_WIDTH rand8
					MAP_HEIGHT rand8
					LoadCommon >r
					2dup CheckForCrystal invert r> and
					if
						2dup
						i crystal.y c!					\ store y coordinate
						i crystal.x c!					\ store x coordinate
						true i crystal.active c!		\ set to alive
						3 rand8 i crystal.color c!		\ random color
						
						MAP_WIDTH * + crystal_map +
						i swap c!
						1								\ loop increment
					else
						2drop 0							\ loop increment
					then
				+loop
				;
				
		DictMainRAM ( num -- msg_len )
		: num>text
			1 text_buff_len c!
			0 num_yet c!
			[char] 0 text_buff c!
			text_buff swap 64						\ text_buff num 100
			begin
				2dup 2dup > -rot = or if			\ text_buff num 100
					tuck - rot						\ 100 num text_buff
					dup c@+1 1 num_yet c!			\ 100 num text_buff
					-rot swap 						\ text_buff num 100
					false 							\ don't exit loop yet
				else								\ text_buff num 100
					A /
					dup 0= if
						true						\ exit word *sigh*
					else 							\ text_buff num 100
						num_yet c@ 0<> if
							rot 1+ [char] 0 		\ num 100 text_buff char0
							over c! -rot			\ text_buff num 100
							text_buff_len c@+1		\ advance length
						then
						false						\ keep looping
					then
				then 
			until
			3drop
			text_buff_len c@
			;
			
		: DrawChar ( screen_ptr char -- screen_ptr )
			20 - 3 lshift chartable @ +				\ screen_ptr char_ptr
			8 0 do									\ 8 rows tall
				dup c@ 3 rshift						\ screen_ptr char_ptr char_data
				rot swap							\ char_ptr screen_ptr char_data
				6 0 do								\ 6 pixels wide
					dup 1 and if
						fg_color
					else
						bg_color
					then
					c@								\ char_ptr screen_ptr char_data color
					rot 2dup c! 1+					\ char_ptr char_data color screen_ptr
					-rot drop 1 rshift				\ char_ptr screen_ptr char_data
				loop
				drop [ SCREEN_WIDTH 6 - ]
				literal + swap 	1+					\ screen_ptr char_ptr  
			loop
			drop
			[ SCREEN_WIDTH 8 * 6 - ] literal -		\ advance screen pointer
			;
			
		: DrawText ( msg msg_len y stat1 stat2 fg_color bg_color )
			bg_color c! fg_color c!
			stat2 ! stat1 !
			SCREEN_WIDTH * 
			SCREEN_ADDRESS + draw_X c@ +					\ msg msg_len screen_ptr
			swap 										\ msg screen_ptr msg_len
			0 do										\ loop through string
				6 draw_X c@ + draw_X c!					\ advance text X coordinate
				swap dup 1+ swap c@ rot swap			\ msg screen_ptr char
				dup [char] $ = if 
					drop stat1 @ num>text				\ msg screen_ptr num_len
					text_buff swap 0 do					\ msg screen_ptr text_buff
						dup c@ rot swap DrawChar 		\ msg text_buff screen_ptr 
						swap 1+							\ msg screen_ptr text_buff
					loop drop							\ msg screen_ptr
					stat2 @ stat1 !							
				else
					DrawChar
				then
				
			loop
			2drop ;
	
		DictGame
			: DrawBar ( left top val val_max fg_color bg_color -- )
				bg_color c! fg_color c! 			\ left top val val_max
				swap BAR_WIDTH rot 					\ left top val BAR_WIDTH val_max
				*/mod swap drop >r 2dup r@			\ left top left top fg_width
				BAR_HEIGHT fg_color c@ DrawRect		\ left top
				r@ rot + swap BAR_WIDTH r> -		\ left top bg_width
				BAR_HEIGHT bg_color c@ DrawRect
				;
			
			: TargetWithin ( x_offset y_offset -- x y flag )
				hero_Y c@ +
				swap hero_X c@ +			
				2dup
				0 FRAME_WIDTH within
				swap
				0 FRAME_HEIGHT within
				and if								\ x_offset y_offset
					20 * swap 20 * true				\ within bounds
				else								\ not within bounds
					false
				then
				;
			
			: DrawFrame ( -- )
				\ copy map data from banked memory
				EnableBankROM
					display_Y c@ MAP_WIDTH *  		\ calculate display offset Y
					display_X c@ +					\ calculate display offset X
					0								\ stack: map_offset temp_offset				
					FRAME_HEIGHT 0 do
						over map_data +
						over map_data_temp +
						FRAME_WIDTH move
						over monster_map +
						over monster_map_temp +
						FRAME_WIDTH move
						over crystal_map +
						over crystal_map_temp +
						FRAME_WIDTH move
						FRAME_WIDTH +				\ increase temp pointer
						swap MAP_WIDTH +			\ increase map_data pointer
						swap
					loop
				EnableGfxRAM
				2drop								\ pointers no longer needed
				
				\ draw background tiles
				crystal_map_temp
				monster_map_temp
				map_data_temp
				
				FRAME_HEIGHT 0 do
					FRAME_WIDTH 0 do
						dup c@
						case
							MAP_BLANK of Ground_0 endof
							MAP_BLANK_90 of Ground_90 endof
							MAP_BLANK_180 of Ground_180 endof
							MAP_BLANK_270 of Ground_270 endof
							MAP_ROCK of Rock endof
							MAP_LAVA of Lava endof
							MAP_EXIT of ExitID endof
						endcase
						i 20 * j 20 * rot DrawTile
						1+ -rot						\ advance map_data_temp ptr, switch to monster ptr
						dup c@ NO_MONSTER <> if
							i 20 * j 20 * monster DrawTile
						then
						1+ -rot						\ advance monster ptr, rotate in crystal ptr
						1+ -rot						\ advance crystal ptr, rotate back to map_data_temp ptr
					loop
				loop
				3drop 
				
				\ draw robot
				hero_X c@ 20 * hero_Y c@ 20 *
				hero_facing c@ DIRECTION_RIGHT = if
					Robot_right
				else
					Robot_left
				then DrawTile
				
				\ draw selector
				hero_target_direction c@
				case
					DIRECTION_UP of 0 -1 endof
					DIRECTION_DOWN of 0 1 endof
					DIRECTION_LEFT of -1 0 endof
					DIRECTION_RIGHT of 1 0 endof
				endcase
				
				TargetWithin if
					COLOR_GREEN COLOR_TRANSPARENT hero_target DrawTile1bpp
				else
					2drop
				then
				
				;
			
		\ Legend words
			create MapColors COLOR_DIRT c, COLOR_DIRT c, COLOR_DIRT c, COLOR_DIRT c, COLOR_ROCK c, COLOR_LAVA c, COLOR_EXIT c,
			: DrawLegend ( -- )
				\ Draw bg
				LEGEND_LEFT LEGEND_TOP LEGEND_WIDTH LEGEND_HEIGHT COLOR_LEGEND_BG DrawRect
							
				\ Draw minimap
				[ SCREEN_ADDRESS LEGEND_MAZE_TOP SCREEN_WIDTH * + ]	\ y offset into screen
				[ LEGEND_LEFT LEGEND_MAZE_LEFT + + ] literal		\ x offset into screen			
				
				MAP_HEIGHT 0 do
					i MAP_WIDTH *
					EnableBankROM
						map_data over + map_data_temp MAP_WIDTH move
						monster_map over + monster_map_temp MAP_WIDTH move
						crystal_map over + crystal_map_temp MAP_WIDTH move
					EnableGfxRAM
					drop
					
					\ crystal_map_temp 8 dump8
					
					crystal_map_temp
					monster_map_temp
					map_data_temp
						
					MAP_WIDTH 0 do									\ screen_ptr crystal_map_temp monster_map_temp map_data_temp
						swap >>r									\ screen_ptr crystal_map_temp (r: map_data_temp monster_map_temp)
						over r@ c@									\ screen_ptr crystal_map_temp screen_ptr tileID (r: map_data_temp monster_map_temp)
						\ saves 162 bytes
						MapColors + c@ swap							\ screen_ptr crystal_map_temp color screen_ptr (r: map_data_temp monster_map_temp)
						r>> dup c@ swap 1+ swap -rot >>r
						NO_MONSTER <> if
							nip COLOR_RED swap
						then
						
						rot dup c@ >r 1+ -rot r>						\ screen_ptr crystal_map_temp color screen_ptr (r: map_data_temp monster_map_temp)
						NO_CRYSTAL <> if
							nip COLOR_YELLOW swap
						then
						2dup c! 2dup 1+ c!							\ draw pixels
						2dup SCREEN_WIDTH + c!
						2dup [ SCREEN_WIDTH 1+ ] literal + c!
						2drop swap 2 + swap
						r>> swap 1+									\ screen_ptr crystal_map_temp monster_map_temp map_data_temp
					loop
					
					3drop											\ screen_ptr
					[ SCREEN_WIDTH 2* MAP_WIDTH 2* - ]			\ advance 2 lines - mini map width
					literal +
				loop drop
				
				\ Green rectangle on minimap
				[ SCREEN_ADDRESS LEGEND_MAZE_TOP SCREEN_WIDTH * + ]	\ y offset into screen
				[ LEGEND_LEFT LEGEND_MAZE_LEFT + + ] literal		\ x offset into screen
				display_X c@ 2* + display_Y c@ 2* SCREEN_WIDTH * + 	\ box upper left
				dup [ FRAME_WIDTH 2* ] literal COLOR_GREEN fill	    \ top line
				dup [ FRAME_HEIGHT 2* 1- ] literal SCREEN_WIDTH * + 
				[ FRAME_WIDTH 2* ] literal COLOR_GREEN fill			\ bottom line
				SCREEN_WIDTH +										\ advance screen pointer one pixel down so no overlap
				[ FRAME_HEIGHT 1- 2* ] literal 0 do					\ 1 less so doesnt overwrite already drawn line
					COLOR_GREEN over c!								\ left line
					COLOR_GREEN over 
					[ FRAME_WIDTH 2* 1- ] literal + c!				\ right line
					SCREEN_WIDTH +									\ advance screen pointer
				loop
				drop
				
				s" HP:$/$" [ LEGEND_LEFT LEGEND_STATS_LEFT + ]
				literal draw_X c! LEGEND_HP_TOP 
				hero_HP @ hero_HP_Max @
				COLOR_WHITE COLOR_LEGEND_BG
				DrawText
				
				[ LEGEND_LEFT LEGEND_STATS_LEFT + ] literal
				LEGEND_HP_BAR_TOP hero_HP @ hero_HP_Max @
				COLOR_RED COLOR_DARK_RED DrawBar
				
				s" Batt:$/$" [ LEGEND_LEFT LEGEND_STATS_LEFT + ]
				literal draw_X c! LEGEND_BATT_TOP
				hero_Batt c@ hero_Batt_Max c@
				COLOR_WHITE COLOR_LEGEND_BG 
				DrawText

				[ LEGEND_LEFT LEGEND_STATS_LEFT + ] literal 
				LEGEND_BATT_BAR_TOP hero_Batt c@ hero_Batt_Max c@
				COLOR_BLUE COLOR_DARK_BLUE DrawBar
				
				s" Exp:$/$" [ LEGEND_LEFT LEGEND_STATS_LEFT + ]
				literal draw_X c! LEGEND_EXP_TOP 
				hero_Exp c@ hero_Exp_Max c@
				COLOR_WHITE COLOR_LEGEND_BG 
				DrawText
				
				[ LEGEND_LEFT LEGEND_STATS_LEFT + ] literal
				LEGEND_EXP_BAR_TOP hero_Exp c@ hero_Exp_Max c@
				COLOR_GREEN COLOR_DARK_GREEN DrawBar
				;
				
		DictMainRAM
		
	\ Menus
		DictBankROM
			begin_enum
				enum stat_Basic
				enum stat_Green
				enum stat_Blue
				enum stat_Purple
				enum stat_Yellow
				enum stat_Red
				enum stat_None
			
			begin_enum
				enum stat_Batt
				enum stat_HP
				enum stat_Dmg
				enum stat_Mine
				enum stat_Mine1s
				enum stat_Crit
				enum stat_Lava
				enum stat_Drill
				enum stat_Drill1s
				enum stat_Batt_Recharge
				enum stat_HP_Recharge
				enum stat_Lava_Heals
				enum stat_Dmg_Cost_50
				enum stat_Mine_Cost_50
				enum stat_Res_Only
				enum stat_none
			
			\								slot		cost	cost_type				quality			stat_count	stat1					stat2					stat3
			create stat_Basic_Head 			head c, 	0 c,	stat_None c,			stat_Basic c,	1 c, 		stat_Batt c, 	2 c, 
			create stat_Head_MKII 			head c, 	2 c,	CRYSTAL_BLUE_TYPE c,	stat_Green c,	1 c, 		stat_Batt c, 	4 c, 
			create stat_Head_MKIII 			head c, 	5 c,	CRYSTAL_BLUE_TYPE c,	stat_Blue c,	2 c, 		stat_Batt c, 	5 c,	stat_Crit c, 5 c, 
			create stat_Head_MKIV 			head c, 	8 c,	CRYSTAL_YELLOW_TYPE c,	stat_Purple c,	3 c, 		stat_Batt c, 	8 c,	stat_Crit c, a c,		stat_Drill c, 2 c, 
			create stat_Lightning 			head c, 	f c,	CRYSTAL_RED_TYPE c,		stat_Yellow c,	3 c, 		stat_Batt c, 	c c,	stat_Crit c, 14 c, 		stat_Batt_Recharge c, 1 c, 
			create stat_Basic_Body 			body c, 	0 c,	stat_None c,			stat_Basic c,	1 c, 		stat_HP c, 		5 c, 	
			create stat_Tin_Body 			body c, 	2 c,	CRYSTAL_RED_TYPE c,		stat_Green c,	1 c, 		stat_HP c, 		8 c, 	
			create stat_Iron_Body 			body c, 	5 c,	CRYSTAL_BLUE_TYPE c,	stat_Blue c,	2 c, 		stat_HP c, 		a c,	stat_Batt c, 3 c, 	
			create stat_Steel_Body			body c, 	8 c,	CRYSTAL_YELLOW_TYPE c,	stat_Purple c,	3 c, 		stat_HP c, 		c c,	stat_Batt c, 5 c, 		stat_Dmg c, 2 c, 
			create stat_Fortress 			body c, 	f c,	CRYSTAL_BLUE_TYPE c,	stat_Yellow c,	3 c, 		stat_HP c, 		14 c,	stat_Batt c, a c, 		stat_HP_Recharge c, 1 c, 
			create stat_Basic_Legs 			legs c, 	0 c,	stat_None c,			stat_Basic c,	1 c, 		stat_HP c, 		3 c, 	
			create stat_Fast_Legs 			legs c, 	2 c,	CRYSTAL_RED_TYPE c,		stat_Green c,	1 c, 		stat_HP c, 		5 c, 	
			create stat_Quick_Legs 			legs c, 	5 c,	CRYSTAL_RED_TYPE c,		stat_Blue c,	2 c, 		stat_HP c, 		6 c,	stat_Lava c, 19 c, 	
			create stat_Agile_Legs 			legs c, 	8 c,	CRYSTAL_BLUE_TYPE c,	stat_Purple c,	3 c, 		stat_HP c, 		7 c,	stat_Lava c, 32 c, 		stat_Mine c, 2 c, 
			create stat_Mustang 			legs c, 	f c,	CRYSTAL_RED_TYPE c,		stat_Yellow c,	3 c, 		stat_HP c, 		c c,	stat_Dmg c, 4 c, 		stat_Lava_Heals c, 0 c, 
			create stat_Basic_Gun 			gun c, 		0 c,	stat_None c,			stat_Basic c,	1 c, 		stat_Dmg c, 	4 c, 	
			create stat_Blaster 			gun c, 		2 c,	CRYSTAL_YELLOW_TYPE c,	stat_Green c,	1 c, 		stat_Dmg c, 	6 c, 	
			create stat_Laser 				gun c, 		5 c,	CRYSTAL_RED_TYPE c,		stat_Blue c,	2 c, 		stat_Dmg c, 	8 c,	stat_Crit c, a c, 	
			create stat_Phaser 				gun c, 		8 c,	CRYSTAL_BLUE_TYPE c,	stat_Purple c,	3 c, 		stat_Dmg c, 	a c,	stat_Crit c, f c, 		stat_Batt c, 2 c, 
			create stat_Death_Ray 			gun c, 		f c,	CRYSTAL_YELLOW_TYPE c,	stat_Yellow c,	3 c, 		stat_Dmg c, 	c c,	stat_Crit c, 1e c, 		stat_Dmg_Cost_50 c, 0 c, 
			create stat_Basic_Tool 			tool c, 	0 c,	stat_None c,			stat_Basic c,	1 c, 		stat_Mine c, 	1 c, 	
			create stat_Rock_Pick 			tool c, 	2 c,	CRYSTAL_YELLOW_TYPE c,	stat_Green c,	1 c, 		stat_Mine c, 	2 c, 	
			create stat_Rock_Drill 			tool c, 	5 c,	CRYSTAL_YELLOW_TYPE c,	stat_Blue c,	2 c, 		stat_Mine c, 	3 c,	stat_Drill c, 2 c, 	
			create stat_Rock_Borer 			tool c, 	8 c,	CRYSTAL_RED_TYPE c,		stat_Purple c,	3 c, 		stat_Mine c, 	5 c,	stat_Drill c, 3 c, 		stat_Batt c, 3 c, 
			create stat_Laser_Bit 			tool c, 	f c,	CRYSTAL_YELLOW_TYPE c,	stat_Yellow c,	3 c, 		stat_Mine1s c,	0 c,	stat_Drill1s c, 0 c,	stat_Mine_Cost_50 c, 3 c, 
			\								types				cost	cost_type				message
			create stat_Res_HP_Heal 		stat_Res_Only c,	1 c,	CRYSTAL_RED_TYPE c,		s" Heals HP to$full" swap c, ,
			create stat_Res_Batt_Heal 		stat_Res_Only c,	1 c,	CRYSTAL_BLUE_TYPE c,	s" Recharges$battery to$full" swap c, ,
			create stat_Res_HP_Upgrade 		stat_Res_Only c,	a c,	CRYSTAL_RED_TYPE c,		s" +1 HP" swap c, ,
			create stat_Res_Batt_Upgrade 	stat_Res_Only c,	a c,	CRYSTAL_BLUE_TYPE c,	s" +1 Batt" swap c, ,
			create stat_Res_Exp_Upgrade 	stat_Res_Only c,	1 c,	CRYSTAL_YELLOW_TYPE c,	s" +1 Exp point" swap c, ,
			create stat_Res_Dmg_Upgrade 	stat_Res_Only c,	a c,	CRYSTAL_YELLOW_TYPE c,	s" +1 Dmg" swap c, ,
			
			create item_stats
				stat_Basic_Head ,		
				stat_Head_MKII ,	
				stat_Head_MKIII ,		
				stat_Head_MKIV ,
				stat_Lightning ,
				stat_Basic_Body ,
				stat_Tin_Body ,
				stat_Iron_Body ,
				stat_Steel_Body ,
				stat_Fortress ,
				stat_Basic_Legs ,
				stat_Fast_Legs ,
				stat_Quick_Legs ,
				stat_Agile_Legs ,
				stat_Mustang ,
				stat_Basic_Gun ,
				stat_Blaster ,
				stat_Laser ,
				stat_Phaser ,
				stat_Death_Ray ,
				stat_Basic_Tool ,
				stat_Rock_Pick ,
				stat_Rock_Drill ,
				stat_Rock_Borer ,
				stat_Laser_Bit ,
				
				stat_Res_HP_Heal ,
				stat_Res_Batt_Heal ,
				stat_Res_HP_Upgrade ,
				stat_Res_Batt_Upgrade ,
				stat_Res_Exp_Upgrade ,
				stat_Res_Dmg_Upgrade ,
				
			: ID>stat ( itemID -- item_addr )
				2* item_stats + @ ;
			
			: LoadItem ( itemID -- )
				dup ID>stat c@					\ itemID item_type
				Menu_head +						\ Menu_head is first of 5 item types
				Menu_item_temp CopyTile			\ itemID
				Menu_item_temp swap ColorTile
				;
			
			: LoadItemStats ( itemID -- )
				\ shortcut since we know the 11 variables we need are stored contiguously
				ID>stat item_type B move ;
				
		DictCharMenu
		
			create hero_stat_pointers
				0 ,								\ hero_HP_Max but not byte wide like rest
				lit hero_Batt_Max ,
				lit hero_Dmg ,
				lit hero_Crit_Rate ,
				lit hero_Mine_Speed ,
				lit hero_Drill_Speed ,
				lit hero_Lava_Res ,
			
			begin_enum
				enum stat_special
			
			create stat_pointers
				lit hero_Batt_Max ,			\ Batt
				lit hero_HP_Max_temp ,		\ HP,
				lit hero_Dmg ,				\ Dmg,
				stat_special ,				\ Mine,
				stat_special ,				\ Mine1s,
				lit hero_Crit_Rate ,		\ Crit,
				lit hero_Lava_Res ,			\ Lava,
				stat_special ,				\ Drill, 
				stat_special ,				\ Drill1s,
				lit hero_Batt_Recharge ,	\ Batt_Recharge
				lit hero_HP_Recharge ,		\ HP_Recharge,
				stat_special ,				\ LavaHeals,
				stat_special ,				\ AttackCost50,
				stat_special ,				\ MineCost50
				
			\ just make strings same length to save on pointer space
			create hero_stat_texts
s"
HP:   $  
Batt: $  
Dmg:  $  
Crit: $% 
Mine: $s 
Drill:$s 
Lava: -$%
" 2drop
			
			create hero_stat_colors
				COLOR_HP c,
				COLOR_BATT c,
				COLOR_DMG c,
				COLOR_CRIT c,
				COLOR_MINE c,
				COLOR_DRILL c,
				COLOR_LAVA c,
			
			create item_titles
s"
Basic Head
Head MKII 
Head MKIII
Head MKIV 
Lightning 
Basic Body
Tin Body  
Iron Body 
Steel Body
Fortress  
Basic Legs
Fast Legs 
Quick Legs
Agile Legs
Mustang   
Basic Gun 
Blaster   
Laser     
Phaser    
Death Ray 
Basic Tool
Rock Pick 
Rock Drill
Rock Borer
Laser Bit 
" 2drop

			create item_title_lens
				a c,	\ Basic Head
				9 c,	\ Head MKII 
				a c,	\ Head MKIII
				9 c,	\ Head MKIV 
				9 c,	\ Lightning 
				a c,	\ Basic Body
				8 c,	\ Tin Body  
				9 c, 	\ Iron Body 
				a c,	\ Steel Body
				8 c,	\ Fortress  
				a c,	\ Basic Legs
				9 c,	\ Fast Legs 
				a c,	\ Quick Legs
				a c,	\ Agile Legs
				7 c,	\ Mustang   
				9 c,	\ Basic Gun 
				7 c,	\ Blaster   
				5 c,	\ Laser     
				6 c,	\ Phaser    
				9 c,	\ Death Ray 
				a c,	\ Basic Tool
				9 c,	\ Rock Pick 
				a c,	\ Rock Drill
				a c,	\ Rock Borer
				9 c,	\ Laser Bit 
			
			create title_colors
				COLOR_GRAY_2 c,
				COLOR_GREEN c,
				COLOR_BLUE c,
				COLOR_PURPLE c,
				COLOR_YELLOW c,
				
			create item_stat_descriptions
s"
+$ Batt   
+$ HP     
+$ Dmg    
-$s Mine  
1s Mine   
+$% Crit  
-$% Lava  
-$s Drill 
1s Drill  
+$/s Batt 
+$/s HP   
Lava Heals
-50% Cost 
-50% Cost 
" 2drop
			
			create item_stat_description_lens
				7 c,
				5 c,
				6 c,
				8 c,
				7 c,
				8 c,
				8 c,
				9 c,
				8 c,
				9 c,
				7 c,
				a c,
				9 c,
				9 c,
			
			create item_stat_description_colors
				COLOR_BATT c,
				COLOR_HP c,
				COLOR_DMG c,
				COLOR_MINE c,
				COLOR_MINE c,
				COLOR_CRIT c,
				COLOR_LAVA c,
				COLOR_DRILL c, 
				COLOR_DRILL c,
				COLOR_BATT c,
				COLOR_HP c,
				COLOR_HP c,
				COLOR_DMG c,
				COLOR_MINE c,
			
			: DrawItem ( x y itemID -- )
				EnableBankROM
					LoadItem
				EnableGfxRAM
				Menu_item_temp DrawTile	
				;
				
			: DrawItemStats ( x y itemID bg_color -- )
				color1 c!
				3dup DrawItem
				dup 
				EnableBankROM
					LoadItemStats
				EnableGfxRAM						\ x y itemID
				rot dup 
				MENU_CHAR_BOX_TITLE_OFFSET_X + 
				draw_X c! -rot						\ x y itemID
				
				\ item title
				over swap dup A *					\ x y y itemID title_addr_off
				[ item_titles 3 + ] literal + swap	\ x y y title_addr itemID
				item_title_lens + c@ rot			\ x y title_addr title_len y
				MENU_CHAR_BOX_TITLE_OFFSET_Y +
				0 0 COLOR_BLACK
				title_colors item_quality c@ + c@
				DrawText							\ x y
				
				\ item stats
				MENU_CHAR_BOX_STAT_OFFSET_Y + 		\ x y
				item_stat_count c@ 0 do
					\ ( msg msg_len y stat1 stat2 fg_color bg_color )
					over MENU_CHAR_BOX_STAT_OFFSET_X + 
					draw_X c! dup 					\ x y y
					[ item_stat_descriptions 3 + ]
					literal item_stat1 c@ a * +		\ x y y text
					item_stat_description_lens
					item_stat1 c@ + c@ rot			\ x y text len y
					item_stat1_x c@ 0				\ x y text len y stat_x 0
					item_stat_description_colors
					item_stat1 c@ + c@ color1 c@	\ x y text len y stat_x 0 fg_color bg_color
					DrawText
					a +								\ x y
					item_stat2 item_stat1 4 move	\ x y
				loop
				2drop				
				;
			
			: DrawMenuInventoryChar ( -- )
				\ stat boxes
				MENU_CHAR_BOX_LEFT MENU_CHAR_BOX1_TOP MENU_CHAR_BOX_WIDTH MENU_CHAR_BOX_HEIGHT MENU_CHAR_BOX_COLOR DrawRect
				MENU_CHAR_BOX_LEFT MENU_CHAR_BOX2_TOP MENU_CHAR_BOX_WIDTH MENU_CHAR_BOX_HEIGHT MENU_CHAR_BOX_COLOR DrawRect
				\ item grid
				0 \ index
				MENU_CHAR_BOX_Y_COUNT 0 do
					MENU_CHAR_BOX_X_COUNT 0 do
						MENU_CHAR_GRID_LEFT i 10 * +				\ slot coordinates 
						MENU_CHAR_GRID_TOP j 10 * +		
						2dup Menu_item_slot DrawTile				\ index slot_X slot_Y
						rot dup hero_inventory + c@ dup				\ slot_X slot_Y index itemID itemID
						item_none <> if		
							j i										\ slot_X slot_Y index itemID j i
							menu_char_x c@ = swap		
							menu_char_y c@ = and if					\ slot_X slot_Y index itemID
								\ draw item in inventory
								dup MENU_CHAR_BOX_LEFT
								MENU_CHAR_BOX2_TOP rot
								MENU_CHAR_BOX_COLOR
								DrawItemStats						\ slot_X slot_Y index itemID
								\ selector on item in inventory
								MENU_CHAR_BOX_LEFT
								MENU_CHAR_BOX2_TOP
								COLOR_TRANSPARENT COLOR_GREEN 
								Menu_item_selector DrawTile1bpp
								\ item equipped in that slot (type still in item_type)
								item_type c@ hero_equipped + c@
								MENU_CHAR_BOX_LEFT
								MENU_CHAR_BOX1_TOP rot
								MENU_CHAR_BOX_COLOR
								DrawItemStats						\ slot_X slot_Y index itemID
							then									\ slot_X slot_Y index itemID
							swap >r DrawItem 						\ draw item in inventory grid
							r>										\ index
						else		
							drop -rot 2drop							\ index
						then		
						1+											\ advance index
					loop
				loop drop
				\ bottom grid border
				[ SCREEN_ADDRESS MENU_CHAR_GRID_LEFT + MENU_CHAR_GRID_LINE_TOP SCREEN_WIDTH * + ]
				literal MENU_CHAR_GRID_LINE_WIDTH COLOR_BLACK fill
				\ right grid border
				MENU_CHAR_GRID_LINE_LEFT MENU_CHAR_GRID_TOP 1 MENU_CHAR_GRID_LINE_HEIGHT COLOR_BLACK DrawRect
				\ item selector
				MENU_CHAR_GRID_LEFT menu_char_x c@ 10 * + 
				MENU_CHAR_GRID_TOP menu_char_y c@ 10 * +
				COLOR_TRANSPARENT COLOR_GREEN 
				Menu_item_selector DrawTile1bpp
				;
				
			: DrawCharMenu ( -- )
				COLOR_MENU_CHAR DrawRect
				\ Robot
				MENU_CHAR_ROBOT_LEFT MENU_CHAR_ROBOT_TOP Robot_right DrawTile
				
				9 const STAT_TEXT_LENGTH
				MENU_CHAR_HP_TOP		\ start Y for text				
				HERO_STAT_COUNT 0 do
					[ hero_stat_texts 3 + ] literal i STAT_TEXT_LENGTH * +
					over STAT_TEXT_LENGTH swap 
					MENU_CHAR_STAT_LEFT draw_X c!
					hero_stat_pointers i 2* + @
					dup 0= if
						drop hero_HP_Max @
					else c@ then 0
					hero_stat_colors i + c@ COLOR_MENU_CHAR 
					DrawText
					9 +					\ advance y counter for text
				loop drop
				
				DrawMenuInventoryChar
				;
			
			: DrawBorder ( x y width height color -- )
				color1 c! 1- height c! 2 - width c!		\ x y 
				SCREEN_WIDTH * + SCREEN_ADDRESS +		\ screen_addr screen_addr
				dup 1+ dup width c@ color1 c@ fill		\ top border
				height c@ SCREEN_WIDTH * +
				width c@ color1 c@ fill					\ bottom border
				width c@ 1+ width c!
				color1 c@ swap
				height c@ 1+ 0 do
					2dup c!								\ left border
					2dup width c@ + c!					\ right border
					SCREEN_WIDTH +
				loop 2drop
				;
			
			: DrawMenuBorderChar ( -- )
				\ Gray border
				1 1 [ SCREEN_WIDTH 2 - ] literal
				[ MENU_BORDER_SIZE TEXT_LINE_HEIGHT + ] literal
				COLOR_MENU_BORDER DrawRect
				1 [ SCREEN_HEIGHT MENU_BORDER_SIZE - ] literal
				[ SCREEN_WIDTH 2 - ] literal 
				[ MENU_BORDER_SIZE 1 - ] literal
				COLOR_MENU_BORDER DrawRect
				1 [ MENU_BORDER_SIZE TEXT_LINE_HEIGHT 1 + + ] literal
				[ MENU_BORDER_SIZE 1 - ] literal
				[ SCREEN_HEIGHT MENU_BORDER_SIZE 2 * - TEXT_LINE_HEIGHT - 1 - ]
				literal COLOR_MENU_BORDER DrawRect
				[ SCREEN_WIDTH MENU_BORDER_SIZE - ] literal
				[ MENU_BORDER_SIZE TEXT_LINE_HEIGHT 1 + + ] literal
				[ MENU_BORDER_SIZE 1 - ] literal
				[ SCREEN_HEIGHT MENU_BORDER_SIZE 2 * - TEXT_LINE_HEIGHT - 1 - ]
				literal COLOR_MENU_BORDER DrawRect
				\ Black single line border
				0 0 SCREEN_WIDTH SCREEN_HEIGHT COLOR_BLACK DrawBorder
				MENU_BORDER_SIZE MENU_BORDER_SIZE
				[ SCREEN_WIDTH MENU_BORDER_SIZE 2 * - ] literal
				[ SCREEN_HEIGHT MENU_BORDER_SIZE 2 * - ] literal
				COLOR_BLACK DrawBorder
				\ diagonal lines
				COLOR_BLACK SCREEN_ADDRESS
				MENU_BORDER_SIZE 1 do
					\ top left
					2dup i + i SCREEN_WIDTH * + c!
					\ top right
					2dup [ SCREEN_WIDTH 1 - ] literal i - +
					i SCREEN_WIDTH * + c!
					\ bottom left
					2dup i + [ SCREEN_HEIGHT 1- ] literal
					i - SCREEN_WIDTH * + c!
					\ bottom right
					2dup [ SCREEN_WIDTH 1 - ] literal i - +
					[ SCREEN_HEIGHT 1- ] literal
					i - SCREEN_WIDTH * + c!
				loop 2drop
				
				MENU_CHAR_LEFT draw_X c!
				s" [C]haracter"  MENU_TITLE_TOP 0 0 COLOR_WHITE COLOR_MENU_CHAR DrawText
				[ MENU_SKILL_LEFT 1 - ] literal MENU_TITLE_TOP 1 TEXT_LINE_HEIGHT COLOR_MENU_SKILLS DrawRect
				draw_X c@+1
				s" S[k]ills" MENU_TITLE_TOP 0 0 COLOR_WHITE COLOR_MENU_SKILLS DrawText
				s" [R]esources" MENU_TITLE_TOP 0 0 COLOR_WHITE COLOR_MENU_RESOURCES DrawText
				;
		
		DictSkillsMenu
		
			(
			create tile_Skill0 18 c, 18 c, 2 c, 3f c, ff c, fc c, 60 c, 0 c, 6 c, c0 c, 0 c, 3 c, 80 c, 0 c, 1 c, 87 c, e7 c, e1 c, 84 c, 24 c, 21 c, 84 c, 24 c, 21 c, 9f c, ff c, f9 c, 90 c, 0 c, 9 c, 
			90 c, 0 c, 89 c, 90 c, 0 c, 89 c, 97 c, c3 c, e9 c, 90 c, 0 c, 89 c, 90 c, 0 c, 89 c, 90 c, 0 c, 9 c, 90 c, 0 c, 9 c, 90 c, 0 c, 9 c, 90 c, 0 c, 9 c, 9f c, ff c, f9 c, 80 c, 0 c, 1 c, 80 c, 
			0 c, 1 c, c0 c, 0 c, 3 c, 60 c, 0 c, 6 c, 3f c, ff c, fc c, 
				
			create tile_Skill1 18 c, 18 c, 2 c, 3f c, ff c, fc c, 60 c, 0 c, 6 c, c7 c, c0 c, 3 c, 88 c, 20 c, 1 c, 90 c, 10 c, 1 c, aa c, a8 c, 1 c, a4 c, 48 c, 1 c, aa c, a8 c, 1 c, a0 c, 8 c, 1 c, 
			9f c, f0 c, 81 c, 95 c, 51 c, c1 c, 9f c, f3 c, 41 c, 95 c, 52 c, 61 c, 8f c, e2 c, 3d c, 80 c, 6 c, 65 c, 80 c, 3c c, cd c, 80 c, 27 c, 89 c, 80 c, 13 c, 19 c, 80 c, 9 c, 91 c, 80 c, f c, 
			f1 c, 80 c, 8 c, 11 c, c0 c, f c, f3 c, 60 c, 0 c, 6 c, 3f c, ff c, fc c, 
			
			create tile_Skill2 18 c, 18 c, 2 c, 3f c, ff c, fc c, 60 c, 0 c, 6 c, c0 c, 0 c, 3 c, 80 c, 7e c, 1 c, 80 c, 42 c, 1 c, 80 c, 42 c, 1 c, 80 c, 42 c, 1 c, 80 c, 42 c, 1 c, 87 c, ff c, e1 c, 
			84 c, c6 c, 21 c, 84 c, 31 c, a1 c, 83 c, 8c c, 41 c, 82 c, 63 c, 41 c, 81 c, 18 c, 81 c, 81 c, c6 c, 81 c, 80 c, b1 c, 1 c, 80 c, 8d c, 1 c, 80 c, 62 c, 1 c, 80 c, 5a c, 1 c, 80 c, 24 c, 
			1 c, 80 c, 18 c, 1 c, c0 c, 0 c, 3 c, 60 c, 0 c, 6 c, 3f c, ff c, fc c, 
			
			create tile_Skill3 18 c, 18 c, 2 c, 3f c, ff c, fc c, 60 c, 0 c, 6 c, c1 c, e0 c, 3 c, 8f c, f0 c, 1 c, 9f c, f0 c, 1 c, 9e c, d8 c, 1 c, bf c, f8 c, 1 c, bf c, f8 c, 1 c, b7 c, f0 c, 1 c, 
			bf c, e0 c, 81 c, 9e c, c1 c, c1 c, 87 c, 83 c, 41 c, 80 c, 2 c, 61 c, 80 c, 2 c, 3d c, 80 c, 6 c, 65 c, 80 c, 3c c, cd c, 80 c, 27 c, 89 c, 80 c, 13 c, 19 c, 80 c, 9 c, 91 c, 80 c, f c, 
			f1 c, 80 c, 8 c, 11 c, c0 c, f c, f3 c, 60 c, 0 c, 6 c, 3f c, ff c, fc c, 
			
			create tile_Skill4 18 c, 18 c, 2 c, 3f c, ff c, fc c, 60 c, 80 c, 6 c, c1 c, c0 c, 3 c, 83 c, 40 c, 1 c, 82 c, 60 c, 1 c, 82 c, 3c c, 1 c, 86 c, 64 c, 1 c, bc c, cc c, 1 c, a7 c, 88 c, 1 c, 
			93 c, 18 c, 81 c, 89 c, 91 c, c1 c, 8f c, f3 c, 41 c, 88 c, 12 c, 61 c, 8f c, f2 c, 3d c, 80 c, 6 c, 65 c, 80 c, 3c c, cd c, 80 c, 27 c, 89 c, 80 c, 13 c, 19 c, 80 c, 9 c, 91 c, 80 c, f c, 
			f1 c, 80 c, 8 c, 11 c, c0 c, f c, f3 c, 60 c, 0 c, 6 c, 3f c, ff c, fc c, 
			
			create tile_Skill5 18 c, 18 c, 2 c, 3f c, ff c, fc c, 60 c, 0 c, 6 c, c0 c, 7c c, 3 c, 80 c, 82 c, 1 c, 81 c, 1 c, 1 c, 82 c, aa c, 81 c, 82 c, 44 c, 81 c, 82 c, aa c, 81 c, 82 c, 0 c, 81 c, 
			81 c, ff c, 1 c, 81 c, 55 c, 1 c, 81 c, ff c, 1 c, 81 c, 55 c, 1 c, 80 c, fe c, 1 c, 80 c, 0 c, 1 c, 9e c, f7 c, 11 c, 82 c, 95 c, 21 c, 9e c, 97 c, 41 c, 90 c, 90 c, b9 c, 90 c, 91 c, 29 c, 
			9e c, f2 c, 39 c, c0 c, 0 c, 3 c, 60 c, 0 c, 6 c, 3f c, ff c, fc c, 
			
			create tile_Skill6 18 c, 18 c, 2 c, 3f c, ff c, fc c, 60 c, 0 c, 6 c, c0 c, 0 c, 3 c, 80 c, 0 c, 1 c, 80 c, 3f c, e1 c, 80 c, 10 c, 21 c, 80 c, 8 c, 21 c, 80 c, 14 c, 21 c, 80 c, 3e c, 21 c, 
			80 c, 41 c, 21 c, 80 c, f0 c, a1 c, 81 c, f c, 61 c, 83 c, 82 c, 21 c, 84 c, 64 c, 1 c, 8c c, 18 c, 1 c, 92 c, 10 c, 1 c, a1 c, 20 c, 1 c, 98 c, c0 c, 1 c, 86 c, 80 c, 1 c, 81 c, 0 c, 1 c, 
			80 c, 0 c, 1 c, c0 c, 0 c, 3 c, 60 c, 0 c, 6 c, 3f c, ff c, fc c, 
			
			create tile_Skill7 18 c, 18 c, 2 c, 3f c, ff c, fc c, 60 c, 0 c, 6 c, c1 c, 0 c, 83 c, 82 c, 81 c, 41 c, 84 c, 42 c, 21 c, 88 c, 3c c, 11 c, 93 c, 81 c, c9 c, a4 c, 42 c, 25 c, a8 c, 24 c, 
			15 c, a9 c, 24 c, 95 c, a4 c, 42 c, 25 c, a3 c, 81 c, c5 c, a0 c, 10 c, 5 c, a0 c, 24 c, 5 c, a0 c, 48 c, 5 c, 90 c, 52 c, 9 c, 88 c, 64 c, 11 c, 84 c, 18 c, 21 c, 82 c, 0 c, 41 c, 81 c, 
			ff c, 81 c, 80 c, 0 c, 1 c, c0 c, 0 c, 3 c, 60 c, 0 c, 6 c, 3f c, ff c, fc c, 
			
			create tile_Skill8 18 c, 18 c, 2 c, 3f c, ff c, fc c, 60 c, 0 c, 6 c, c0 c, 0 c, 3 c, 80 c, 0 c, 1 c, 80 c, 0 c, 1 c, 80 c, 3 c, e1 c, b3 c, 4 c, 11 c, 88 c, 88 c, 9 c, 80 c, 15 c, 55 c, 
			be c, d2 c, 25 c, 80 c, 15 c, 55 c, 88 c, 10 c, 5 c, b1 c, f c, f9 c, 86 c, a c, a9 c, 80 c, f c, f9 c, 80 c, a c, a9 c, 80 c, 7 c, f1 c, 80 c, 0 c, 1 c, 80 c, 0 c, 1 c, 80 c, 0 c, 1 c, 
			80 c, 0 c, 1 c, c0 c, 0 c, 3 c, 60 c, 0 c, 6 c, 3f c, ff c, fc c, 
			
			create tile_Skill9 18 c, 18 c, 2 c, 3f c, ff c, fc c, 60 c, 0 c, 6 c, c0 c, 70 c, 3 c, bc c, 88 c, 1 c, 81 c, 4 c, 1 c, 81 c, 4 c, 1 c, bd c, 4 c, 1 c, 80 c, 88 c, 21 c, 8e c, 70 c, 11 c, 
			89 c, e0 c, 9 c, 88 c, 63 c, fd c, 88 c, 50 c, 9 c, 88 c, 91 c, 11 c, 80 c, 89 c, 21 c, bd c, a c, 1 c, 81 c, 84 c, 1 c, 81 c, 60 c, 1 c, a2 c, 18 c, 1 c, 92 c, 10 c, 1 c, 8c c, 20 c, 1 c, 
			80 c, 40 c, 1 c, c0 c, 80 c, 3 c, 60 c, 0 c, 6 c, 3f c, ff c, fc c, 
			
			create tile_Skill10 18 c, 18 c, 2 c, 3f c, ff c, fc c, 60 c, 0 c, 6 c, c0 c, 7e c, 3 c, 81 c, 81 c, 81 c, 82 c, 0 c, 41 c, 84 c, 8 c, 21 c, 8c c, 1c c, 11 c, 92 c, 34 c, 9 c, 91 c, 26 c, 
			9 c, a0 c, e3 c, c5 c, a0 c, 66 c, 45 c, a3 c, dc c, c5 c, a2 c, 78 c, 85 c, a1 c, 35 c, 85 c, a0 c, 9b c, 5 c, 90 c, ff c, 89 c, 90 c, 81 c, 49 c, 88 c, ff c, 31 c, 84 c, 0 c, 21 c, 82 c, 
			0 c, 41 c, 81 c, 81 c, 81 c, c0 c, 7e c, 3 c, 60 c, 0 c, 6 c, 3f c, ff c, fc c, 
			
			create tile_Skill11 18 c, 18 c, 2 c, 3f c, ff c, fc c, 60 c, 0 c, 6 c, c2 c, 0 c, 3 c, 85 c, 0 c, 1 c, 88 c, 80 c, 1 c, 90 c, 40 c, 1 c, bf c, e0 c, 1 c, 88 c, 80 c, 1 c, 88 c, 80 c, 1 c, 
			88 c, 80 c, 81 c, 88 c, 81 c, c1 c, 88 c, 83 c, 41 c, 8f c, 82 c, 61 c, 80 c, 2 c, 3d c, 80 c, 6 c, 65 c, 80 c, 3c c, cd c, 80 c, 27 c, 89 c, 80 c, 13 c, 19 c, 80 c, 9 c, 91 c, 80 c, f c, 
			f1 c, 80 c, 8 c, 11 c, c0 c, f c, f3 c, 60 c, 0 c, 6 c, 3f c, ff c, fc c, 
			
			create tile_Skill12 18 c, 18 c, 2 c, 3f c, ff c, fc c, 60 c, 0 c, 6 c, c0 c, 0 c, 3 c, 80 c, 40 c, 1 c, 80 c, c0 c, 1 c, 81 c, 40 c, 1 c, 9c c, 40 c, 1 c, 80 c, 40 c, 1 c, 80 c, 40 c, 1 c, 
			81 c, f0 c, 81 c, 80 c, 1 c, c1 c, 80 c, 3 c, 41 c, 80 c, 2 c, 61 c, 80 c, 2 c, 3d c, 80 c, 6 c, 65 c, 80 c, 3c c, cd c, 80 c, 27 c, 89 c, 80 c, 13 c, 19 c, 80 c, 9 c, 91 c, 80 c, f c, f1 c, 
			80 c, 8 c, 11 c, c0 c, f c, f3 c, 60 c, 0 c, 6 c, 3f c, ff c, fc c, 
			
			create tile_Skill13 18 c, 18 c, 2 c, 3f c, ff c, fc c, 60 c, 0 c, 6 c, c0 c, 8 c, 3 c, 80 c, 14 c, 1 c, 80 c, 22 c, 1 c, 80 c, 41 c, 1 c, 80 c, ff c, 81 c, 80 c, 22 c, 1 c, 80 c, 22 c, 1 c, 
			80 c, 22 c, 1 c, 80 c, 3e c, 1 c, 80 c, 0 c, 1 c, 80 c, 7e c, 1 c, 81 c, c3 c, 81 c, 82 c, 81 c, 41 c, 84 c, 81 c, 21 c, 88 c, 81 c, 11 c, 89 c, 81 c, 91 c, 86 c, 81 c, 61 c, 80 c, c3 c, 1 c, 
			80 c, 7e c, 1 c, c0 c, 0 c, 3 c, 60 c, 0 c, 6 c, 3f c, ff c, fc c, 
			
			create tile_Skill14 18 c, 18 c, 2 c, 3f c, ff c, fc c, 60 c, 0 c, 6 c, c0 c, 2 c, 3 c, 84 c, 2 c, 9 c, 82 c, 2 c, 11 c, 81 c, 8 c, 21 c, 80 c, 9c c, 41 c, 80 c, 34 c, 1 c, b0 c, 26 c, 1 c, 
			8c c, 23 c, c5 c, 80 c, 66 c, 59 c, 83 c, cc c, c1 c, 82 c, 78 c, 81 c, 81 c, 31 c, 81 c, 80 c, 99 c, 1 c, 82 c, ff c, 21 c, 84 c, 81 c, 11 c, 88 c, ff c, 9 c, 90 c, 0 c, 5 c, 80 c, 82 c, 
			1 c, 80 c, 82 c, 1 c, c1 c, 1 c, 3 c, 60 c, 0 c, 6 c, 3f c, ff c, fc c, 
			)
			
			create skill_color1
				4 c, 10 c, 1 c,
				
			create skill_color2
				8 c, 35 c, 17 c,
				
			create skill_tops
				MENU_SKILL_BOX1_TOP c,
				MENU_SKILL_BOX2_TOP c,
				MENU_SKILL_BOX3_TOP c,
			
			create skill_colors
				MENU_SKILL_BOX1_COLOR c,
				MENU_SKILL_BOX2_COLOR c,
				MENU_SKILL_BOX3_COLOR c,
			
			: DrawSkills
				MENU_SKILL_DBOX_LEFT MENU_SKILL_DBOX_TOP
				MENU_SKILL_DBOX_WIDTH MENU_SKILL_DBOX_HEIGHT
				MENU_SKILL_DBOX_COLOR DrawRect
					
				3 0 do
					MENU_SKILL_BOX_LEFT
					skill_tops i + c@
					MENU_SKILL_BOX_WIDTH MENU_SKILL_BOX_HEIGHT
					skill_colors i + c@
					DrawRect
					5 0 do
						
					loop
				loop
				;
				
			: DrawSkillsMenu
				COLOR_MENU_SKILLS DrawRect
				MENU_SKILL_POINTS_LEFT draw_X c!
				s" Points: $" MENU_SKILL_POINTS_TOP 
				hero_Points c@ 0
				COLOR_WHITE COLOR_MENU_SKILLS
				DrawText

				DrawSkills
				;
				
		DictResMenu
			: DrawResMenu
				COLOR_MENU_RESOURCES DrawRect
				
				
				
				;
		
		DictGame
		
		DictMainRAM
			: DrawMenu
				MENU_BG_LEFT MENU_BG_TOP MENU_BG_WIDTH MENU_BG_HEIGHT	\ used by all variants below
				output_mode c@ case
					OUTPUT_CHARACTER of
						[ EnableCharMenuROM ]
						EnableCharMenuROM
						DrawCharMenu
						endof
					OUTPUT_SKILLS of
						[ EnableSkillsMenuROM ]
						EnableSkillsMenuROM
						DrawSkillsMenu
						endof
					OUTPUT_RESOURCES of
						[ EnableResMenuROM ]
						EnableResMenuROM
						DrawResMenu
						endof
				endcase
				
				[ EnableGameROM ]
				EnableGameROM
				;
				
			: DrawMenuBorder
				[ EnableCharMenuROM ]
				EnableCharMenuROM
				DrawMenuBorderChar
				[ EnableGameROM ]
				EnableGameROM
				;
				
			: DrawMenuInventory
				[ EnableCharMenuROM ]
				EnableCharMenuROM
				DrawMenuInventoryChar
				[ EnableGameROM ]
				EnableGameROM
				;
				
			: DrawMenuSkills
				[ EnableSkillsMenuROM ]
				EnableSkillsMenuROM
				DrawSkills
				[ EnableGameROM ]
				EnableGameROM
				;
				
	\ General game words
		DictBankROM
			\ Run only once when game starts
			: InitGame
				0 menu_char_x c!
				0 menu_char_y c!
				0 menu_skills_x c!
				0 menu_skills_y c!
				0 menu_res_x c!
				0 menu_res_y c!
				OUTPUT_GAME output_mode c!
				;
			
			\ When game is initialized and when new level begins
			: ResetGame ( -- )
				0 display_X c!
				0 display_Y c!
				HERO_START_X hero_X c!
				HERO_START_Y hero_Y c!
				false hero_activity !
				hero_HP_Max @ hero_HP !
				hero_Batt_Max c@ hero_Batt c!
				DIRECTION_RIGHT hero_facing c!
				DIRECTION_RIGHT hero_target_direction c!
				\ UpdateTarget
				;
			
			: CalcStats ( -- )
				\ should only be called in KeyHandler, so ROM banked and game ROM enabled
				EnableCharMenuROM
				
				2 hero_HP_Max_temp c!
				3 hero_Batt_Max c!
				0 hero_Dmg c!
				8 hero_Mine_Speed c!
				B hero_Drill_Speed c!
				1 hero_Batt_Recharge c!
				5 hero_Crit_Rate c!
				0 hero_HP_Recharge c!
				0 hero_Lava_Res c!
				4 hero_Lava_Dmg !		\ word
				4 hero_Dmg_Cost c!
				2 hero_Mine_Cost c!
				2 hero_Drill_Cost c!
				
				0 Mine1s c!
				0 Drill1s c!
				
				5 0											\ 5 equipped slots 
				do
					hero_equipped i + c@					\ itemID
					LoadItemStats		
					item_stat_count c@ 
					0 do		
						item_stat1 i 2* + dup c@			\ stat1_ptr stat1ID
						swap 1+ c@ swap	dup 2*				\ stat1_x stat1ID stat1ID*2
						[ EnableCharMenuROM ]
							stat_pointers
						[ EnableGameROM ]
						+ @ dup								\ stat1_x stat1ID stat_ptr stat_ptr						
						stat_special <> if					\ stat1_X stat1ID stat_ptr
							nip dup c@ rot + swap c!		\ (empty)
						else								\ stat1_X stat1ID stat_ptr
							drop							\ stat1_X stat1ID
							case							\ stat1_X
								stat_Mine of
									hero_Mine_Speed c@ swap	\ stat1_X mine_speed
									- hero_Mine_Speed c!	\ (empty)
									endof
								stat_Mine1s of
									1 Mine1s c!
									drop
									endof
								stat_Drill of
									hero_Drill_Speed c@ swap	\ stat1_X mine_speed
									- hero_Drill_Speed c!		\ (empty)
									endof
								stat_Drill1s of
									1 Drill1s c!
									drop
									endof
								stat_Lava_Heals of
									-1 hero_Lava_Dmg !
									drop
									endof
								stat_Dmg_Cost_50 of
									2 hero_Dmg_Cost c!
									drop
									endof
								stat_Mine_Cost_50 of
									1 hero_Mine_Cost c!
									drop
									endof
								\ default
							endcase
						then
					loop
				loop
				
				Mine1s @ if
					1 hero_Mine_Speed c!
					1 hero_Drill_Speed c!
				then
				
				hero_Lava_Dmg @ -1 <> if		\ case of lava heals
					hero_Lava_Res 19 = if		\ 0x19 = 25
						3 hero_Lava_Dmg c!
					else
						hero_Lava_Res 32 = if	\ 0x32 = 50
							2 hero_Lava_Dmg c!
						then
					then
				then
				
				hero_HP_Max_temp c@ hero_HP_Max !
				
				hero_HP c@ hero_HP_Max c@ > if
					hero_HP_Max c@ hero_HP c!
				then
				hero_Batt c@ hero_Batt_Max c@ > if
					hero_Batt_Max c@ hero_Batt c!
				then
				
				\ restore banking
				EnableGameROM
				;
			
			: InitHero
				0 hero_Exp c!
				28 hero_Exp_Max c!
				0 hero_HP_Upgrade c!
				0 hero_Batt_Upgrade c!
				0 hero_Dmg_Upgrade c!
				1 hero_Level c!
				0 hero_Red c!
				0 hero_Blue c!	
				0 hero_Yellow c!
				0 hero_Points c!
				false hero_activity c!			\ note false is 16 bit -1!!!
				
				Basic_Head hero_equipped head + c!
				Basic_Body hero_equipped body + c!
				Basic_Legs hero_equipped legs + c!
				Basic_Gun hero_equipped gun + c!
				Basic_Tool hero_equipped tool + c!
				
				hero_inventory INVENTORY_COUNT item_none fill
				
				\ Head_MKII hero_inventory c!
				\ Mustang hero_inventory 1+ c!
				
				19 0 do
					i hero_inventory i + c!
				loop
				
				;
			
			\ saves 167 bytes
			: ColorItems ( -- )
				dup hero_equipped head + c@ ColorTile
				dup hero_equipped body + c@ ColorTile
				dup hero_equipped legs + c@ ColorTile
				dup hero_equipped gun + c@ ColorTile
				    hero_equipped tool + c@ ColorTile ;
			
			: ColorHero ( -- )
				Robot_left_raw Robot_left CopyTile
				Robot_left ColorItems
				
				Robot_right_raw Robot_right CopyTile
				Robot_right ColorItems ;
			
		DictMainRAM
		
	\ Input handling
		DictBankROM
			: CheckMap ( x_offset y_offset -- crystalID monsterID free? )
				hero_Y c@ + swap hero_X c@ +					\ calculate offset
				2dup 0 FRAME_WIDTH within
				swap 0 FRAME_HEIGHT within
				and if 											\ tile to check within bounds?
					display_X c@ +
					swap display_Y c@ + MAP_WIDTH * +			\ calculate offset into maps

					dup crystal_map + c@						\ get map value
					dup NO_CRYSTAL <> if						\ if there's a crystal there
						dup crystal.active if					\ and the crystal is active
							nip NO_MONSTER true exit			\ return crystalID NO_MONSTER true
						then
					then
					drop NO_CRYSTAL								\ drop crystalID since not needed
					
					swap										\ crystalID map_offset
					
					\ confirmed that these point to correct address!
						\ so what's the deal???
					\ [ monster_map halt drop ]
					\ [ ' monster.alive halt drop ]
					\ [ map_data halt drop ]
					\ [ here halt drop ]
					
					dup monster_map + c@
					dup NO_MONSTER <> 
					if
					\ [ halt ]	\ confirmed that the above 4 words written to 01:3A59
						dup monster.alive 
						if
							nip false exit						\ return crystalID monsterID false
						then
					then										\ otherwise keep monsterID
					drop NO_MONSTER
					swap										\ crystalID monsterID map_offset
					
					\ this line makes forth crash at 8505
					\ map_data + c@ MAP_ROCK <>					\ return true or false
					
					\ hmm doesnt crash here
					\ map_data + c@ MAP_ROCK <>
					
					\ doesnt crash
					\ map_data + c@ MAP_ROCK <>					\ return true or
					
					\ doesnt crash
					\ map_data + c@ MAP_ROCK <>					\ return true or fals
					
					\ crashes
					\ map_data + c@ MAP_ROCK <>					\ return true or fals0
					
					\ doesnt crash
					\ map_data + c@ MAP_ROCK <>					\ return true or false0
					
					\ crashes
					\ map_data + c@ MAP_ROCK <>				\ return true or false
					
					\ crashes
					\ map_data + c@ MAP_ROCK <> \ return true or false
					
					\ crashes
					\ map_data + c@ MAP_ROCK <> \ xxxxxx xxxx xx xxxxx
					
					\ crashes
					\ map_data + c@ MAP_ROCK <> \ xxxxxxxxxxxxxxxxxxxx
					
					\ crashes
					\ map_data 1 c@ MAP_ROCK <> \ xxxxxxxxxxxxxxxxxxxx
					
					\ does not crash
					\ map_data c@ MAP_ROCK <> \ xxxxxxxxxxxxxxxxxxxx
					
					\ crashes
					\ map_data + c! MAP_ROCK <> \ xxxxxxxxxxxxxxxxxxxx
					
					\ crashes
					\ map_data + 12 MAP_ROCK <> \ xxxxxxxxxxxxxxxxxxxx
					
					\ crashes
					\ map_data 2 34 MAP_ROCK <> \ xxxxxxxxxxxxxxxxxxxx
					
					\ crashes
					\ map_data 2534 MAP_ROCK <> \ xxxxxxxxxxxxxxxxxxxx
					
					\ crashes
					\ map_data 2534 6 <> \ xxxxxxxxxxxxxxxxxxxx
					
					\ crashes
					\ map_data 2345 6 78 \ xxxxxxxxxxxxxxxxxxxx
					
					\ does not crash
					\ 12345678 2345 6 78 \ xxxxxxxxxxxxxxxxxxxx
					
					\ crashes but at 4102 not 8505
					\ map_data \ xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
					
					\ doesnt crash
					\ map_data \ xxxxxxxxxxxxxxxxxxxxxxxxxxxxx
					
					\ doesnt crash
					\ map_data \ xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
					
					\ [ halt ] \ banks 0 1 2 3
					
					\ hmm crashes at 8505 not 4102 with above halt in place
					\ map_data \ xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
					
					\ copied memory dump
					\ [ halt ]
					\ map_data \ xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
					\ [ halt ]
					
						\ looked at memory dumps and they are very different. definite corruption
						
					\ still crashes if change pad size to FF
						\ change back to save room if still works
					
					\ does not crash if type all in then delete one x and press enter
					
					\ map_data \ xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
					
					\ ok, getting somewhere
						\ could check out how accept works but seems legit
						\ TRAP BUFFER FULL FOR ONE!
						\ 24 fetched as NT for crash and 23 for not
							\ THESE ARE THE LENGTHS OF THE STRINGS
						\ see what those thousands of cycles at beginning looping through	
							\ starts C8F8
							\ loops C92A-C993 (ln 268 to difference 15606)
							\ CAUSED BY SWITCHING DICTIONARIES MIDSTREAM? ie [ Enable... ]
							\ ln 268 (xt_find_name)
								\ C92A - load len of 3 from CA:3C03
								\ C92C - compare len 3 to CA:006E
								\ C92E - bne not taken
									\ hmm, ln 230 writes 3 to 006E
								\ C930 - load 78 from CA:0200 (first char of x3s)
								\ C932 - see if 78 (x) is uppercase
								\ C934 - not uppercase, skip
								\ C93D - LDY #8, offset to name
								\ C93F - compare first char
								\ C941 - bne next_entry (not taken)
								\ C943-C946 - check if 1 long
								\ C948 - not one long. 
								\ 8 byte down calculation
								\ C95A - _string_loop, last char of mystery string
									\ s as expected
								\ C95C - uppercase check (not uppercase)
								\ C967 - _check_char, not equal
								\ C969 - bne 13 (not equal, so branch)
								\ C97E - _next_entry_tmp1
									\ PLA to return tmp1 from stack
								\ C97F - restore tmp1
								\ C984 - LDY #2, _next_entry
								\ ***IMPORTANT***
								\ C986 - get next address
								\ C991 - CHECK FOR ZERO (done with list)
								\ C993 - restart loop
								\ ...
								\ C9A0 - RTS after found name and done
							\ this pattern is 268 to 8772
							\ RTS back to E75B (interpret)
								\ ln 8827 = interpret._got_name_token
								\ ln 8839 - jsr to xt_name_to_int (CDAE)
								\ ln 8840 - jsr from xt_name_to_int to underflow_1 (E7E4)
								\ ln 8841 - jsr back into xt_name_to_int (CDB1)
								\ ln 8857 - rts from xt_name_to_int to interpret._got_name_token (E7A0)
								\ E7A0 - check state. jump to compile mode
								\ ln 8860 _compile (E7B7)
								\ E7BF - jsr xt_compile_comma (C390)
								\ C390 - jsr underflow_1 (E7E4)
								\ C393 back in xt_compile_comma
								\ ln 8873 (C399) jsr xt_int_to_name (CB05)
								\ CB05 
								\ 8892 (CB1E) ; Check for an empty wordlist (DP will be 0)
								\ 8894 - does not take jump for empty word list
								\ 8899 (CB2C) start of loop
									\ (copied loop into spreadsheet)
									\ this loop all the way till difference point
							\ xt_int_to_name
								\ _loop
									\ CB2C see if xt matches one searching for
									\ CB32 bne _no_match of xt
									\ CB3B _no_match, get next word
									\ CB48 check if zero
									\ CB50 beq if zero
									\ CB52 not zero so continue
									\ CB54 load next
									\ CB59 bra to _loop

							\ checked in spreadsheet and found all words down to bye
								\ ie chain of words not messed up
								\ : d8 dup 8 + swap c@ 0 do dup c@ emit 1+ loop drop ;
								\ ln 15467 starts iteration after bye
								\ CB50 checks if zero, which it is since bye is first word and points to 0
								\ CB5B _zero
									\ PLA to balance stack
								\ CB5C _next_wordlist
								\ bne to _wordlist_loop (CB0E)
									\ ; Get the DP for that wordlist - E4B4 
								\ CB22 check for empty wordlist (not empty)
								\ CB24 (ln 15503) get target xt - 4FB1
							\ back into loop!
								\ CB2C
								\ CB52 
								\ CB56 - E4D2	(ln 15524)
									\ this is middle of text strings!
									\ 6D6F is text string
								\ CB56 - 6D6F!!! this must be wrong!!!
									\ ln 15546
								\ E4D2 is ROM in all banks!
								\ how did this get here then?
								\ ln 15485 wordlist 0 then wordlist 1
									\ loads E4B4 as dp from wordlist 1
					
					\ so how do wordlists work???
							
					\ spreadsheet shows that words make sense
					\ suspect messed up nt list

					