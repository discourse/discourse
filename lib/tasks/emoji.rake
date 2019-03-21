require 'active_support/test_case'
require 'fileutils'
require 'json'
require 'nokogiri'
require 'open-uri'
require_dependency 'file_helper'

EMOJI_GROUPS_PATH ||= 'lib/emoji/groups.json'

EMOJI_DB_PATH ||= 'lib/emoji/db.json'

EMOJI_IMAGES_PATH ||= 'public/images/emoji'

EMOJI_ORDERING_URL ||= 'http://www.unicode.org/emoji/charts/emoji-ordering.html'

# Format is search pattern => associated emojis
# eg: "cry" => [ "sob" ]
# for a "cry" query should return: cry and sob
SEARCH_ALIASES ||=
  {
    'sad' => %w[frowning_face slightly_frowning_face sob crying_cat_face cry],
    'cry' => %w[sob]
  }

# emoji aliases are actually created as images
# eg: "right_anger_bubble" => [ "anger_right" ]
# your app will physically have right_anger_bubble.png and anger_right.png
EMOJI_ALIASES ||=
  {
    'right_anger_bubble' => %w[anger_right],
    'ballot_box' => %w[ballot_box_with_ballot],
    'basketball_man' => %w[basketball_player person_with_ball],
    'beach_umbrella' => %w[umbrella_on_ground beach beach_with_umbrella],
    'parasol_on_ground' => %w[umbrella_on_ground],
    'bellhop_bell' => %w[bellhop],
    'biohazard' => %w[biohazard_sign],
    'bow_and_arrow' => %w[archery],
    'spiral_calendar' => %w[calendar_spiral spiral_calendar_pad],
    'card_file_box' => %w[card_box],
    'champagne' => %w[bottle_with_popping_cork],
    'cheese' => %w[cheese_wedge],
    'city_sunset' => %w[city_dusk],
    'couch_and_lamp' => %w[couch],
    'crayon' => %w[lower_left_crayon],
    'cricket_bat_and_ball' => %w[cricket_bat_ball],
    'latin_cross' => %w[cross],
    'dagger' => %w[dagger_knife],
    'desktop_computer' => %w[desktop],
    'card_index_dividers' => %w[dividers],
    'dove' => %w[dove_of_peace],
    'footprints' => %w[feet],
    'fire' => %w[flame],
    'black_flag' => %w[flag_black waving_black_flag],
    'cn' => %w[flag_cn],
    'de' => %w[flag_de],
    'es' => %w[flag_es],
    'fr' => %w[flag_fr],
    'uk' => %w[gb flag_gb],
    'it' => %w[flag_it],
    'jp' => %w[flag_jp],
    'kr' => %w[flag_kr],
    'ru' => %w[flag_ru],
    'us' => %w[flag_us],
    'white_flag' => %w[flag_white waving_white_flag],
    'plate_with_cutlery' => %w[fork_knife_plate fork_and_knife_with_plate],
    'framed_picture' => %w[frame_photo frame_with_picture],
    'hammer_and_pick' => %w[hammer_pick],
    'heavy_heart_exclamation' => %w[
      heart_exclamation
      heavy_heart_exclamation_mark_ornament
    ],
    'houses' => %w[homes house_buildings],
    'hotdog' => %w[hot_dog],
    'derelict_house' => %w[house_abandoned derelict_house_building],
    'desert_island' => %w[island],
    'old_key' => %w[key2],
    'laughing' => %w[satisfied],
    'business_suit_levitating' => %w[levitate man_in_business_suit_levitating],
    'weight_lifting_man' => %w[lifter weight_lifter],
    'medal_sports' => %w[medal sports_medal],
    'metal' => %w[sign_of_the_horns],
    'fu' => %w[middle_finger reversed_hand_with_middle_finger_extended],
    'motorcycle' => %w[racing_motorcycle],
    'mountain_snow' => %w[snow_capped_mountain],
    'newspaper_roll' => %w[newspaper2 rolled_up_newspaper],
    'spiral_notepad' => %w[notepad_spiral spiral_note_pad],
    'oil_drum' => %w[oil],
    'older_woman' => %w[grandma],
    'paintbrush' => %w[lower_left_paintbrush],
    'paperclips' => %w[linked_paperclips],
    'pause_button' => %w[double_vertical_bar],
    'peace_symbol' => %w[peace],
    'fountain_pen' => %w[pen_fountain lower_left_fountain_pen],
    'ping_pong' => %w[table_tennis],
    'place_of_worship' => %w[worship_symbol],
    'poop' => %w[shit hankey poo],
    'radioactive' => %w[radioactive_sign],
    'railway_track' => %w[railroad_track],
    'robot' => %w[robot_face],
    'skull' => %w[skeleton],
    'skull_and_crossbones' => %w[skull_crossbones],
    'speaking_head' => %w[speaking_head_in_silhouette],
    'male_detective' => %w[spy sleuth_or_spy],
    'thinking' => %w[thinking_face],
    '-1' => %w[thumbsdown],
    '+1' => %w[thumbsup],
    'cloud_with_lightning_and_rain' => %w[
      thunder_cloud_rain
      thunder_cloud_and_rain
    ],
    'tickets' => %w[admission_tickets],
    'next_track_button' => %w[track_next next_track],
    'previous_track_button' => %w[track_previous previous_track],
    'unicorn' => %w[unicorn_face],
    'funeral_urn' => %w[urn],
    'sun_behind_large_cloud' => %w[white_sun_cloud white_sun_behind_cloud],
    'sun_behind_rain_cloud' => %w[
      white_sun_rain_cloud
      white_sun_behind_cloud_with_rain
    ],
    'partly_sunny' => %w[white_sun_small_cloud white_sun_with_small_cloud],
    'open_umbrella' => %w[umbrella2],
    'hammer_and_wrench' => %w[tools],
    'face_with_thermometer' => %w[thermometer_face],
    'timer_clock' => %w[timer],
    'keycap_ten' => %w[ten],
    'memo' => %w[pencil],
    'rescue_worker_helmet' => %w[helmet_with_cross helmet_with_white_cross],
    'slightly_smiling_face' => %w[slightly_smiling slight_smile],
    'construction_worker_man' => %w[construction_worker],
    'upside_down_face' => %w[upside_down],
    'money_mouth_face' => %w[money_mouth],
    'nerd_face' => %w[nerd],
    'hugs' => %w[hugging hugging_face],
    'roll_eyes' => %w[rolling_eyes face_with_rolling_eyes],
    'slightly_frowning_face' => %w[slight_frown],
    'frowning_face' => %w[frowning2 white_frowning_face],
    'zipper_mouth_face' => %w[zipper_mouth],
    'face_with_head_bandage' => %w[head_bandage],
    'raised_hand_with_fingers_splayed' => %w[hand_splayed],
    'raised_hand' => %w[hand],
    'vulcan_salute' => %w[
      vulcan
      raised_hand_with_part_between_middle_and_ring_fingers
    ],
    'policeman' => %w[cop],
    'running_man' => %w[runner],
    'walking_man' => %w[walking],
    'bowing_man' => %w[bow],
    'no_good_woman' => %w[no_good],
    'raising_hand_woman' => %w[raising_hand],
    'pouting_woman' => %w[person_with_pouting_face],
    'frowning_woman' => %w[person_frowning],
    'haircut_woman' => %w[haircut],
    'massage_woman' => %w[massage],
    'tshirt' => %w[shirt],
    'biking_man' => %w[bicyclist],
    'mountain_biking_man' => %w[mountain_bicyclist],
    'passenger_ship' => %w[cruise_ship],
    'motor_boat' => %w[motorboat boat],
    'flight_arrival' => %w[airplane_arriving],
    'flight_departure' => %w[airplane_departure],
    'small_airplane' => %w[airplane_small],
    'racing_car' => %w[race_car],
    'family_man_woman_boy_boy' => %w[family_man_woman_boys],
    'family_man_woman_girl_girl' => %w[family_man_woman_girls],
    'family_woman_woman_boy' => %w[family_women_boy],
    'family_woman_woman_girl' => %w[family_women_girl],
    'family_woman_woman_girl_boy' => %w[family_women_girl_boy],
    'family_woman_woman_boy_boy' => %w[family_women_boys],
    'family_woman_woman_girl_girl' => %w[family_women_girls],
    'family_man_man_boy' => %w[family_men_boy],
    'family_man_man_girl' => %w[family_men_girl],
    'family_man_man_girl_boy' => %w[family_men_girl_boy],
    'family_man_man_boy_boy' => %w[family_men_boys],
    'family_man_man_girl_girl' => %w[family_men_girls],
    'cloud_with_lightning' => %w[cloud_lightning],
    'tornado' => %w[cloud_tornado cloud_with_tornado],
    'cloud_with_rain' => %w[cloud_rain],
    'cloud_with_snow' => %w[cloud_snow],
    'asterisk' => %w[keycap_star],
    'studio_microphone' => %w[microphone2],
    'medal_military' => %w[military_medal],
    'couple_with_heart_woman_woman' => %w[female_couple_with_heart],
    'couple_with_heart_man_man' => %w[male_couple_with_heart],
    'couplekiss_woman_woman' => %w[female_couplekiss],
    'couplekiss_man_man' => %w[male_couplekiss],
    'honeybee' => %w[bee],
    'lion' => %w[lion_face],
    'artificial_satellite' => %w[satellite_orbital],
    'computer_mouse' => %w[mouse_three_button three_button_mouse],
    'hocho' => %w[knife],
    'swimming_man' => %w[swimmer],
    'wind_face' => %w[wind_blowing_face],
    'golfing_man' => %w[golfer],
    'facepunch' => %w[punch],
    'building_construction' => %w[construction_site],
    'family_man_woman_girl_boy' => %w[family],
    'ice_hockey' => %w[hockey],
    'snowman_with_snow' => %w[snowman2],
    'play_or_pause_button' => %w[play_pause],
    'film_projector' => %w[projector],
    'shopping' => %w[shopping_bags],
    'open_book' => %w[book],
    'national_park' => %w[park],
    'world_map' => %w[map],
    'pen' => %w[pen_ballpoint lower_left_ballpoint_pen],
    'email' => %w[envelope e-mail],
    'phone' => %w[telephone],
    'atom_symbol' => %w[atom],
    'mantelpiece_clock' => %w[clock],
    'camera_flash' => %w[camera_with_flash],
    'film_strip' => %w[film_frames],
    'balance_scale' => %w[scales],
    'surfing_man' => %w[surfer],
    'couplekiss_man_woman' => %w[couplekiss],
    'couple_with_heart_woman_man' => %w[couple_with_heart],
    'clamp' => %w[compression],
    'dancing_women' => %w[dancers],
    'blonde_man' => %w[person_with_blond_hair],
    'sleeping_bed' => %w[sleeping_accommodation],
    'om' => %w[om_symbol],
    'tipping_hand_woman' => %w[information_desk_person],
    'rowing_man' => %w[rowboat],
    'new_moon' => %w[moon],
    'oncoming_automobile' => %w[car automobile],
    'fleur_de_lis' => %w[fleur-de-lis],
    'face_vomiting' => %w[puke]
  }

EMOJI_GROUPS ||=
  [
    { 'name' => 'smileys_&_emotion', 'tabicon' => 'grinning' },
    { 'name' => 'people_&_body', 'tabicon' => 'wave' },
    { 'name' => 'animals_&_nature', 'tabicon' => 'evergreen_tree' },
    { 'name' => 'food_&_drink', 'tabicon' => 'hamburger' },
    { 'name' => 'travel_&_places', 'tabicon' => 'airplane' },
    { 'name' => 'activities', 'tabicon' => 'soccer' },
    { 'name' => 'objects', 'tabicon' => 'eyeglasses' },
    { 'name' => 'symbols', 'tabicon' => 'white_check_mark' },
    { 'name' => 'flags', 'tabicon' => 'checkered_flag' }
  ]

FITZPATRICK_SCALE ||= %w[1f3fb 1f3fc 1f3fd 1f3fe 1f3ff]

DEFAULT_SET ||= 'twitter'

# Replace the platform by another when downloading the image (accepts names or categories)
EMOJI_IMAGES_PATCH ||=
  {
    'apple' => { 'snowboarder' => 'twitter' },
    'emoji_one' => { 'country-flag' => 'twitter' },
    'windows' => { 'country-flag' => 'twitter' }
  }

EMOJI_SETS ||=
  {
    'apple' => 'apple',
    'google' => 'google',
    'google_blob' => 'google_classic',
    'facebook' => 'facebook_messenger',
    'twitter' => 'twitter',
    'emoji_one' => 'emoji_one',
    'windows' => 'win10'
  }

EMOJI_DB_REPO ||= 'git@github.com:jjaffeux/emoji-db.git'

EMOJI_DB_REPO_PATH ||= File.join('tmp', 'emoji-db')

GENERATED_PATH ||= File.join(EMOJI_DB_REPO_PATH, 'generated')

desc 'update emoji images'
task 'emoji:update' do
  copy_emoji_db

  json_db = open(File.join(GENERATED_PATH, 'db.json')).read
  db = JSON.parse(json_db)

  write_db_json(db['emojis'], db['translations'])
  fix_incomplete_sets(db['emojis'])
  write_aliases
  groups = generate_emoji_groups(db['emojis'], db['sections'])
  write_js_groups(db['emojis'], groups)
  optimize_images(
    Dir.glob(File.join(Rails.root, EMOJI_IMAGES_PATH, '/**/*.png'))
  )

  TestEmojiUpdate.run_and_summarize

  FileUtils.rm_rf(EMOJI_DB_REPO_PATH)
end

desc 'test the emoji generation script'
task 'emoji:test' do
  ENV['EMOJI_TEST'] = '1'
  Rake::Task['emoji:update'].invoke
end

def optimize_images(images)
  images.each do |filename|
    FileHelper.image_optim(allow_pngquant: true, strip_image_metadata: true)
      .optimize_image!(filename)
  end
end

def copy_emoji_db
  `rm -rf tmp/emoji-db && git clone #{EMOJI_DB_REPO} tmp/emoji-db`

  path = "#{EMOJI_IMAGES_PATH}/**/*"
  confirm_overwrite(path)
  puts 'Cleaning emoji folder...'
  FileUtils.rm_rf(Dir.glob(path))

  EMOJI_SETS.each do |set_name, set_destination|
    origin = File.join(GENERATED_PATH, set_name)
    destination = File.join(EMOJI_IMAGES_PATH, set_destination)
    FileUtils.mv(origin, destination)
  end
end

def fix_incomplete_sets(emojis)
  emojis.each do |code, config|
    EMOJI_SETS.each do |set_name, set_destination|
      patch_set =
        EMOJI_SETS[EMOJI_IMAGES_PATCH.dig(set_name, config['name'])] ||
          EMOJI_SETS[EMOJI_IMAGES_PATCH.dig(set_name, config['category'])]

      if patch_set ||
         !File.exist?(
           File.join(
             EMOJI_IMAGES_PATH,
             set_destination,
             "#{config['name']}.png"
           )
         )
        origin =
          File.join(
            EMOJI_IMAGES_PATH,
            patch_set || EMOJI_SETS[DEFAULT_SET],
            config['name']
          )

        FileUtils.cp(
          "#{origin}.png",
          File.join(EMOJI_IMAGES_PATH, set_destination, "#{config['name']}.png")
        )
        if File.directory?(origin)
          FileUtils.cp_r(
            origin,
            File.join(EMOJI_IMAGES_PATH, set_destination, config['name'])
          )
        end
      end
    end
  end
end

def generate_emoji_groups(keywords, sections)
  puts 'Generating groups...'

  list = open(EMOJI_ORDERING_URL).read
  doc = Nokogiri.HTML(list)
  table = doc.css('table')[0]

  EMOJI_GROUPS.map do |group|
    group['icons'] ||= []

    sub_sections = sections[group['name']]['sub_sections']
    sub_sections.each do |section|
      title_section = table.css("tr th a[@name='#{section}']")
      emoji_list_section = title_section.first.parent.parent.next_element
      emoji_list_section.css('a.plain img').each do |link|
        emoji_code =
          link.attr('title').scan(/U\+(.{4,5})\b/).flatten.map do |code|
            code.downcase.strip
          end
            .join('_')

        emoji_char = code_to_emoji(emoji_code)

        if emoji = keywords[emoji_char]
          group['icons'] <<
            { name: emoji['name'], diversity: emoji['fitzpatrick_scale'] }
        end
      end
    end
    group.delete('sections')
    group
  end
end

def write_aliases
  EMOJI_ALIASES.each do |original, aliases|
    aliases.each do |emoji_alias|
      EMOJI_SETS.each do |set_name, set_destination|
        origin_file =
          File.join(EMOJI_IMAGES_PATH, set_destination, "#{original}.png")
        origin_dir = File.join(EMOJI_IMAGES_PATH, set_destination, original)
        FileUtils.cp(
          origin_file,
          File.join(EMOJI_IMAGES_PATH, set_destination, "#{emoji_alias}.png")
        )

        if File.directory?(origin_dir)
          FileUtils.cp_r(
            origin_dir,
            File.join(EMOJI_IMAGES_PATH, set_destination, emoji_alias)
          )
        end
      end
    end
  end
end

def write_db_json(emojis, translations)
  puts "Writing #{EMOJI_DB_PATH}..."

  confirm_overwrite(EMOJI_DB_PATH)

  FileUtils.mkdir_p(File.expand_path('..', EMOJI_DB_PATH))

  # skin tones variations of emojis shouldn’t appear in autocomplete
  emojis_without_tones =
    emojis.select do |char, config|
      !FITZPATRICK_SCALE.any? do |scale|
        codepoints_to_code(char.codepoints, config['fitzpatrick_scale'])[scale]
      end
    end
      .map do |char, config|
      {
        'code' =>
          codepoints_to_code(char.codepoints, config['fitzpatrick_scale']).tr(
            '_',
            '-'
          ),
        'name' => config['name']
      }
    end

  emoji_with_tones =
    emojis.select { |code, config| config['fitzpatrick_scale'] }
      .map { |code, config| config['name'] }

  db = {
    'emojis' => emojis_without_tones,
    'tonableEmojis' => emoji_with_tones,
    'aliases' => EMOJI_ALIASES,
    'searchAliases' => SEARCH_ALIASES,
    'translations' => translations
  }

  File.write(EMOJI_DB_PATH, JSON.pretty_generate(db))
end

def write_js_groups(emojis, groups)
  puts "Writing #{EMOJI_GROUPS_PATH}..."

  confirm_overwrite(EMOJI_GROUPS_PATH)

  template = JSON.pretty_generate(groups)
  FileUtils.mkdir_p(File.expand_path('..', EMOJI_GROUPS_PATH))
  File.write(EMOJI_GROUPS_PATH, template)
end

def code_to_emoji(code)
  code.split('_').map { |e| e.to_i(16) }.pack 'U*'
end

def codepoints_to_code(codepoints, fitzpatrick_scale)
  codepoints =
    codepoints.map { |c| c.to_s(16).rjust(4, '0') }.join('_').downcase

  codepoints.gsub!(/_fe0f$/, '') if !fitzpatrick_scale

  codepoints
end

def confirm_overwrite(path)
  return if ENV['EMOJI_TEST']

  STDOUT.puts(
    "[!] You are about to overwrite #{path}, are you sure? [CTRL+c] to cancel, [ENTER] to continue"
  )
  STDIN.gets.chomp
end

class TestEmojiUpdate < MiniTest::Test
  def self.run_and_summarize
    puts 'Runnings tests...'
    reporter = Minitest::SummaryReporter.new
    TestEmojiUpdate.run(reporter)
    puts reporter.to_s
  end

  def image_path(style, name)
    File.join('public', 'images', 'emoji', style, "#{name}.png")
  end

  def test_code_to_emoji
    assert_equal '😎', code_to_emoji('1f60e')
  end

  def test_codepoints_to_code
    assert_equal '1f6b5_200d_2640',
                 codepoints_to_code([128693, 8205, 9792, 65039], false)
  end

  def test_codepoints_to_code_with_scale
    assert_equal '1f6b5_200d_2640_fe0f',
                 codepoints_to_code([128693, 8205, 9792, 65039], true)
  end

  def test_groups_js_es6_creation
    assert File.exists?(EMOJI_GROUPS_PATH)
    assert File.size?(EMOJI_GROUPS_PATH)
  end

  def test_db_json_creation
    assert File.exists?(EMOJI_DB_PATH)
    assert File.size?(EMOJI_DB_PATH)
  end

  def test_alias_creation
    original_image = image_path('apple', 'right_anger_bubble')
    alias_image = image_path('apple', 'anger_right')

    assert_equal File.size(original_image), File.size(alias_image)
  end

  def test_cell_index_patch
    original_image = image_path('apple', 'snowboarder')
    alias_image = image_path('twitter', 'snowboarder')

    assert_equal File.size(original_image), File.size(alias_image)
  end

  def test_scales
    original_image = image_path('apple', 'blonde_woman')
    assert File.exists?(original_image)
    assert File.size?(original_image)

    (2..6).each do |scale|
      image = image_path('apple', "blonde_woman/#{scale}")
      assert File.exists?(image)
      assert File.size?(image)
    end
  end

  def test_default_set
    original_image = image_path('twitter', 'snowboarder')
    alias_image = image_path('apple', 'snowboarder')
    assert_equal File.size(original_image), File.size(alias_image)

    original_image = image_path('twitter', 'macau')
    alias_image = image_path('emoji_one', 'macau')
    assert_equal File.size(original_image), File.size(alias_image)
  end
end
