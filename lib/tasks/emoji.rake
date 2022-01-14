# frozen_string_literal: true

require "active_support/test_case"
require "fileutils"
require "json"
require "nokogiri"
require "open-uri"
require_dependency "file_helper"

EMOJI_GROUPS_PATH ||= "lib/emoji/groups.json"

EMOJI_DB_PATH ||= "lib/emoji/db.json"

EMOJI_IMAGES_PATH ||= "public/images/emoji"

EMOJI_ORDERING_URL ||= "http://www.unicode.org/emoji/charts/emoji-ordering.html"

# emoji aliases are actually created as images
# eg: "right_anger_bubble" => [ "anger_right" ]
# your app will physically have right_anger_bubble.png and anger_right.png
EMOJI_ALIASES ||= {
  "right_anger_bubble" => [ "anger_right" ],
  "ballot_box" => [ "ballot_box_with_ballot" ],
  "basketball_man" => [ "basketball_player", "person_with_ball" ],
  "beach_umbrella" => [ "umbrella_on_ground", "beach", "beach_with_umbrella" ],
  "parasol_on_ground" => [ "umbrella_on_ground" ],
  "bellhop_bell" => [ "bellhop" ],
  "biohazard" => [ "biohazard_sign" ],
  "bow_and_arrow" => [ "archery" ],
  "spiral_calendar" => [ "calendar_spiral", "spiral_calendar_pad" ],
  "card_file_box" => [ "card_box" ],
  "champagne" => [ "bottle_with_popping_cork" ],
  "cheese" => [ "cheese_wedge" ],
  "city_sunset" => [ "city_dusk" ],
  "couch_and_lamp" => [ "couch" ],
  "crayon" => [ "lower_left_crayon" ],
  "cricket_bat_and_ball" => [ "cricket_bat_ball" ],
  "latin_cross" => [ "cross" ],
  "dagger" => [ "dagger_knife" ],
  "desktop_computer" => [ "desktop" ],
  "card_index_dividers" => [ "dividers" ],
  "dove" => [ "dove_of_peace" ],
  "footprints" => [ "feet" ],
  "fire" => [ "flame" ],
  "black_flag" => [ "flag_black", "waving_black_flag" ],
  "cn" => [ "flag_cn" ],
  "de" => [ "flag_de" ],
  "es" => [ "flag_es" ],
  "fr" => [ "flag_fr" ],
  "uk" => [ "gb", "flag_gb" ],
  "it" => [ "flag_it" ],
  "jp" => [ "flag_jp" ],
  "kr" => [ "flag_kr" ],
  "ru" => [ "flag_ru" ],
  "us" => [ "flag_us" ],
  "white_flag" => [ "flag_white", "waving_white_flag" ],
  "plate_with_cutlery" => [ "fork_knife_plate", "fork_and_knife_with_plate" ],
  "framed_picture" => [ "frame_photo", "frame_with_picture" ],
  "hammer_and_pick" => [ "hammer_pick" ],
  "heavy_heart_exclamation" => [ "heart_exclamation", "heavy_heart_exclamation_mark_ornament" ],
  "houses" => [ "homes", "house_buildings" ],
  "hotdog" => [ "hot_dog" ],
  "derelict_house" => [ "house_abandoned", "derelict_house_building" ],
  "desert_island" => [ "island" ],
  "old_key" => [ "key2" ],
  "laughing" => [ "satisfied" ],
  "business_suit_levitating" => [ "levitate", "man_in_business_suit_levitating" ],
  "weight_lifting_man" => [ "lifter", "weight_lifter" ],
  "medal_sports" => [ "medal", "sports_medal" ],
  "metal" => [ "sign_of_the_horns" ],
  "fu" => [ "middle_finger", "reversed_hand_with_middle_finger_extended" ],
  "motorcycle" => [ "racing_motorcycle" ],
  "mountain_snow" => [ "snow_capped_mountain" ],
  "newspaper_roll" => [ "newspaper2", "rolled_up_newspaper" ],
  "spiral_notepad" => [ "notepad_spiral", "spiral_note_pad" ],
  "oil_drum" => [ "oil" ],
  "older_woman" => [ "grandma" ],
  "paintbrush" => [ "lower_left_paintbrush" ],
  "paperclips" => [ "linked_paperclips" ],
  "pause_button" => [ "double_vertical_bar" ],
  "peace_symbol" => [ "peace" ],
  "fountain_pen" => [ "pen_fountain", "lower_left_fountain_pen" ],
  "ping_pong" => [ "table_tennis" ],
  "place_of_worship" => [ "worship_symbol" ],
  "poop" => [ "shit", "hankey", "poo" ],
  "radioactive" => [ "radioactive_sign" ],
  "railway_track" => [ "railroad_track" ],
  "robot" => [ "robot_face" ],
  "skull" => [ "skeleton" ],
  "skull_and_crossbones" => [ "skull_crossbones" ],
  "speaking_head" => [ "speaking_head_in_silhouette" ],
  "male_detective" => [ "spy", "sleuth_or_spy" ],
  "thinking" => [ "thinking_face" ],
  "-1" => [ "thumbsdown" ],
  "+1" => [ "thumbsup" ],
  "cloud_with_lightning_and_rain" => [ "thunder_cloud_rain", "thunder_cloud_and_rain" ],
  "tickets" => [ "admission_tickets" ],
  "next_track_button" => [ "track_next", "next_track" ],
  "previous_track_button" => [ "track_previous", "previous_track" ],
  "unicorn" => [ "unicorn_face" ],
  "funeral_urn" => [ "urn" ],
  "sun_behind_large_cloud" => [ "white_sun_cloud", "white_sun_behind_cloud" ],
  "sun_behind_rain_cloud" => [ "white_sun_rain_cloud", "white_sun_behind_cloud_with_rain" ],
  "partly_sunny" => [ "white_sun_small_cloud", "white_sun_with_small_cloud" ],
  "open_umbrella" => [ "umbrella2" ],
  "hammer_and_wrench" => [ "tools" ],
  "face_with_thermometer" => [ "thermometer_face" ],
  "timer_clock" => [ "timer" ],
  "keycap_ten" => [ "ten" ],
  "memo" => [ "pencil" ],
  "rescue_worker_helmet" => [ "helmet_with_cross", "helmet_with_white_cross" ],
  "slightly_smiling_face" => [ "slightly_smiling", "slight_smile"],
  "construction_worker_man" => [ "construction_worker" ],
  "upside_down_face" => [ "upside_down" ],
  "money_mouth_face" => [ "money_mouth" ],
  "nerd_face" => [ "nerd" ],
  "hugs" => [ "hugging", "hugging_face" ],
  "roll_eyes" => [ "rolling_eyes", "face_with_rolling_eyes" ],
  "slightly_frowning_face" => [ "frowning", "slight_frown" ],
  "frowning_face" => [ "frowning2", "white_frowning_face" ],
  "zipper_mouth_face" => [ "zipper_mouth" ],
  "face_with_head_bandage" => [ "head_bandage" ],
  "raised_hand_with_fingers_splayed" => [ "hand_splayed" ],
  "raised_hand" => [ "hand" ],
  "vulcan_salute" => [ "vulcan", "raised_hand_with_part_between_middle_and_ring_fingers" ],
  "policeman" => [ "cop" ],
  "running_man" => [ "runner" ],
  "walking_man" => [ "walking" ],
  "bowing_man" => [ "bow" ],
  "no_good_woman" => [ "no_good" ],
  "raising_hand_woman" => [ "raising_hand" ],
  "pouting_woman" => [ "person_with_pouting_face" ],
  "frowning_woman" => [ "person_frowning" ],
  "haircut_woman" => [ "haircut" ],
  "massage_woman" => [ "massage" ],
  "tshirt" => [ "shirt" ],
  "biking_man" => [ "bicyclist" ],
  "mountain_biking_man" => [ "mountain_bicyclist" ],
  "passenger_ship" => [ "cruise_ship" ],
  "motor_boat" => [ "motorboat", "boat" ],
  "flight_arrival" => [ "airplane_arriving" ],
  "flight_departure" => [ "airplane_departure" ],
  "small_airplane" => [ "airplane_small" ],
  "racing_car" => [ "race_car" ],
  "family_man_woman_boy_boy" => [ "family_man_woman_boys" ],
  "family_man_woman_girl_girl" => [ "family_man_woman_girls" ],
  "family_woman_woman_boy" => [ "family_women_boy" ],
  "family_woman_woman_girl" => [ "family_women_girl" ],
  "family_woman_woman_girl_boy" => [ "family_women_girl_boy" ],
  "family_woman_woman_boy_boy" => [ "family_women_boys" ],
  "family_woman_woman_girl_girl" => [ "family_women_girls" ],
  "family_man_man_boy" => [ "family_men_boy" ],
  "family_man_man_girl" => [ "family_men_girl" ],
  "family_man_man_girl_boy" => [ "family_men_girl_boy" ],
  "family_man_man_boy_boy" => [ "family_men_boys" ],
  "family_man_man_girl_girl" => [ "family_men_girls" ],
  "cloud_with_lightning" => [ "cloud_lightning" ],
  "tornado" => [ "cloud_tornado", "cloud_with_tornado" ],
  "cloud_with_rain" => [ "cloud_rain" ],
  "cloud_with_snow" => [ "cloud_snow" ],
  "asterisk" => [ "keycap_star" ],
  "studio_microphone" => [ "microphone2" ],
  "medal_military" => [ "military_medal" ],
  "couple_with_heart_woman_woman" => [ "female_couple_with_heart" ],
  "couple_with_heart_man_man" => [ "male_couple_with_heart" ],
  "couplekiss_woman_woman" => [ "female_couplekiss" ],
  "couplekiss_man_man" => [ "male_couplekiss" ],
  "honeybee" => [ "bee" ],
  "lion" => [ "lion_face" ],
  "artificial_satellite" => [ "satellite_orbital" ],
  "computer_mouse" => [ "mouse_three_button", "three_button_mouse" ],
  "hocho" => [ "knife" ],
  "swimming_man" => [ "swimmer" ],
  "wind_face" => [ "wind_blowing_face" ],
  "golfing_man" => [ "golfer" ],
  "facepunch" => [ "punch" ],
  "building_construction" => [ "construction_site" ],
  "family_man_woman_girl_boy" => [ "family" ],
  "ice_hockey" => [ "hockey" ],
  "snowman_with_snow" => [ "snowman2" ],
  "play_or_pause_button" => [ "play_pause" ],
  "film_projector" => [ "projector" ],
  "shopping" => [ "shopping_bags" ],
  "open_book" => [ "book" ],
  "national_park" => [ "park" ],
  "world_map" => [ "map" ],
  "pen" => [ "pen_ballpoint", "lower_left_ballpoint_pen" ],
  "email" => [ "envelope", "e-mail" ],
  "phone" => [ "telephone" ],
  "atom_symbol" => [ "atom" ],
  "mantelpiece_clock" => [ "clock" ],
  "camera_flash" => [ "camera_with_flash" ],
  "film_strip" => [ "film_frames" ],
  "balance_scale" => [ "scales" ],
  "surfing_man" => [ "surfer" ],
  "couplekiss_man_woman" => [ "couplekiss" ],
  "couple_with_heart_woman_man" => [ "couple_with_heart" ],
  "clamp" => [ "compression" ],
  "dancing_women" => [ "dancers" ],
  "blonde_man" => [ "person_with_blond_hair" ],
  "sleeping_bed" => [ "sleeping_accommodation" ],
  "om" => [ "om_symbol" ],
  "tipping_hand_woman" => [ "information_desk_person" ],
  "rowing_man" => [ "rowboat" ],
  "new_moon" => [ "moon" ],
  "oncoming_automobile" => [ "car", "automobile" ],
  "fleur_de_lis" => [ "fleur-de-lis" ],
  "face_vomiting" => [ "puke" ],
  "smile" => [ "grinning_face_with_smiling_eyes" ],
  "frowning_with_open_mouth" => ["frowning_face_with_open_mouth"],
}

EMOJI_GROUPS ||= [
  {
    "name" => "smileys_&_emotion",
    "tabicon" => "grinning"
  },
  {
    "name" => "people_&_body",
    "tabicon" => "wave"
  },
  {
    "name" => "animals_&_nature",
    "tabicon" => "evergreen_tree"
  },
  {
    "name" => "food_&_drink",
    "tabicon" => "hamburger"
  },
  {
    "name" => "travel_&_places",
    "tabicon" => "airplane"
  },
  {
    "name" => "activities",
    "tabicon" => "soccer"
  },
  {
    "name" => "objects",
    "tabicon" => "eyeglasses"
  },
  {
    "name" => "symbols",
    "tabicon" => "white_check_mark"
  },
  {
    "name" => "flags",
    "tabicon" => "checkered_flag"
  }
]

FITZPATRICK_SCALE ||= [ "1f3fb", "1f3fc", "1f3fd", "1f3fe", "1f3ff" ]

DEFAULT_SET ||= "twitter"

# Replace the platform by another when downloading the image (accepts names or categories)
EMOJI_IMAGES_PATCH ||= {
  "apple" => { "snowboarder" => "twitter" },
  "windows" => { "country-flag" => "twitter" }
}

EMOJI_SETS ||= {
  "apple" => "apple",
  "google" => "google",
  "google_blob" => "google_classic",
  "facebook" => "facebook_messenger",
  "twitter" => "twitter",
  "windows" => "win10",
}

EMOJI_DB_REPO ||= "git@github.com:xfalcox/emoji-db.git"

EMOJI_DB_REPO_PATH ||= File.join("tmp", "emoji-db")

GENERATED_PATH ||= File.join(EMOJI_DB_REPO_PATH, "generated")

def search_aliases(emojis)
  # Format is search pattern => associated emojis
  # eg: "cry" => [ "sob" ]
  # for a "cry" query should return: cry and sob
  @aliases ||= begin
    aliases = {
      "sad" => [ "frowning_face", "slightly_frowning_face", "sob", "crying_cat_face", "cry" ],
      "cry" => [ "sob" ]
    }

    emojis.each do |_, config|
      next if config["search_aliases"].blank?
      config["search_aliases"].each do |name|
        aliases[name] ||= []
        aliases[name] << config["name"]
      end
    end

    aliases.map { |_, names| names.uniq! }
    aliases
  end
end

desc "update emoji images"
task "emoji:update" do
  copy_emoji_db

  json_db = File.read(File.join(GENERATED_PATH, "db.json"))
  db = JSON.parse(json_db)

  write_db_json(db["emojis"], db["translations"], search_aliases(db["emojis"]))
  fix_incomplete_sets(db["emojis"])
  write_aliases
  groups = generate_emoji_groups(db["emojis"], db["sections"])
  write_js_groups(db["emojis"], groups)
  optimize_images(Dir.glob(File.join(Rails.root, EMOJI_IMAGES_PATH, "/**/*.png")))

  TestEmojiUpdate.run_and_summarize

  FileUtils.rm_rf(EMOJI_DB_REPO_PATH)
end

desc "test the emoji generation script"
task "emoji:test" do
  ENV['EMOJI_TEST'] = "1"
  Rake::Task["emoji:update"].invoke
end

def optimize_images(images)
  images.each do |filename|
    FileHelper.image_optim(
      allow_pngquant: true,
      strip_image_metadata: true
    ).optimize_image!(filename)
  end
end

def copy_emoji_db
  `rm -rf tmp/emoji-db && git clone -b unicodeorg-as-source-of-truth --depth 1 #{EMOJI_DB_REPO} tmp/emoji-db`

  path = "#{EMOJI_IMAGES_PATH}/**/*"
  confirm_overwrite(path)
  puts "Cleaning emoji folder..."
  emoji_assets = Dir.glob(path)
  emoji_assets.delete_if { |x| x == "#{EMOJI_IMAGES_PATH}/emoji_one" }
  FileUtils.rm_rf(emoji_assets)

  EMOJI_SETS.each do |set_name, set_destination|
    origin = File.join(GENERATED_PATH, set_name)
    destination = File.join(EMOJI_IMAGES_PATH, set_destination)
    FileUtils.mv(origin, destination)
  end
end

def fix_incomplete_sets(emojis)
  emojis.each do |code, config|
    EMOJI_SETS.each do |set_name, set_destination|
      patch_set = EMOJI_SETS[EMOJI_IMAGES_PATCH.dig(set_name, config["name"])] ||
        EMOJI_SETS[EMOJI_IMAGES_PATCH.dig(set_name, config["category"])]

      if patch_set || !File.exist?(File.join(EMOJI_IMAGES_PATH, set_destination, "#{config['name']}.png"))
        origin = File.join(EMOJI_IMAGES_PATH, patch_set || EMOJI_SETS[DEFAULT_SET], config['name'])

        FileUtils.cp("#{origin}.png", File.join(EMOJI_IMAGES_PATH, set_destination, "#{config['name']}.png"))
        if File.directory?(origin)
          FileUtils.cp_r(origin, File.join(EMOJI_IMAGES_PATH, set_destination, config['name']))
        end
      end
    end
  end
end

def generate_emoji_groups(keywords, sections)
  puts "Generating groups..."

  list = URI.parse(EMOJI_ORDERING_URL).read
  doc = Nokogiri::HTML5(list)
  table = doc.css("table")[0]

  EMOJI_GROUPS.map do |group|
    group["icons"] ||= []

    sub_sections = sections[group["name"]]["sub_sections"]
    sub_sections.each do |section|
      title_section = table.css("tr th a[@name='#{section}']")
      emoji_list_section = title_section.first.parent.parent.next_element
      emoji_list_section.css("a.plain img").each do |link|
        emoji_code = link.attr("title")
          .scan(/U\+(.{4,5})\b/)
          .flatten
          .map { |code| code.downcase.strip }
          .join("_")

        emoji_char = code_to_emoji(emoji_code)

        if emoji = keywords[emoji_char]
          group["icons"] << { name: emoji["name"], diversity: emoji["fitzpatrick_scale"] }
        end
      end
    end
    group.delete("sections")
    group
  end
end

def write_aliases
  EMOJI_ALIASES.each do |original, aliases|
    aliases.each do |emoji_alias|
      EMOJI_SETS.each do |set_name, set_destination|
        origin_file = File.join(EMOJI_IMAGES_PATH, set_destination, "#{original}.png")
        origin_dir = File.join(EMOJI_IMAGES_PATH, set_destination, original)
        FileUtils.cp(origin_file, File.join(EMOJI_IMAGES_PATH, set_destination, "#{emoji_alias}.png"))

        if File.directory?(origin_dir)
          FileUtils.cp_r(origin_dir, File.join(EMOJI_IMAGES_PATH, set_destination, emoji_alias))
        end
      end
    end
  end
end

def write_db_json(emojis, translations, search_aliases)
  puts "Writing #{EMOJI_DB_PATH}..."

  confirm_overwrite(EMOJI_DB_PATH)

  FileUtils.mkdir_p(File.expand_path("..", EMOJI_DB_PATH))

  # skin tones variations of emojis shouldn’t appear in autocomplete
  emojis_without_tones = emojis
    .select { |char, config|
                           !FITZPATRICK_SCALE.any? { |scale|
                             codepoints_to_code(char.codepoints, config["fitzpatrick_scale"])[scale]
                           }
                         }
    .map { |char, config|
    {
      "code" => codepoints_to_code(char.codepoints, config["fitzpatrick_scale"]).tr("_", "-"),
      "name" => config["name"]
    }
  }

  emoji_with_tones = emojis
    .select { |code, config| config["fitzpatrick_scale"] }
    .map { |code, config| config["name"] }

  db = {
    "emojis" => emojis_without_tones,
    "tonableEmojis" => emoji_with_tones,
    "aliases" => EMOJI_ALIASES,
    "searchAliases" => search_aliases,
    "translations" => translations
  }

  File.write(EMOJI_DB_PATH, JSON.pretty_generate(db))
end

def write_js_groups(emojis, groups)
  puts "Writing #{EMOJI_GROUPS_PATH}..."

  confirm_overwrite(EMOJI_GROUPS_PATH)

  template = JSON.pretty_generate(groups)
  FileUtils.mkdir_p(File.expand_path("..", EMOJI_GROUPS_PATH))
  File.write(EMOJI_GROUPS_PATH, template)
end

def code_to_emoji(code)
  code
    .split("_")
    .map { |e| e.to_i(16) }
    .pack "U*"
end

def codepoints_to_code(codepoints, fitzpatrick_scale)
  codepoints = codepoints
    .map { |c| c.to_s(16).rjust(4, "0") }
    .join("_")
    .downcase

  if !fitzpatrick_scale
    codepoints.gsub!(/_fe0f$/, "")
  end

  codepoints
end

def confirm_overwrite(path)
  return if ENV['EMOJI_TEST']

  STDOUT.puts("[!] You are about to overwrite #{path}, are you sure? [CTRL+c] to cancel, [ENTER] to continue")
  STDIN.gets.chomp
end

class TestEmojiUpdate < MiniTest::Test
  def self.run_and_summarize
    puts "Runnings tests..."
    reporter = Minitest::SummaryReporter.new
    TestEmojiUpdate.run(reporter)
    puts reporter.to_s
  end

  def image_path(style, name)
    File.join("public", "images", "emoji", style, "#{name}.png")
  end

  def test_code_to_emoji
    assert_equal "😎", code_to_emoji("1f60e")
  end

  def test_codepoints_to_code
    assert_equal "1f6b5_200d_2640", codepoints_to_code([128693, 8205, 9792, 65039], false)
  end

  def test_codepoints_to_code_with_scale
    assert_equal "1f6b5_200d_2640_fe0f", codepoints_to_code([128693, 8205, 9792, 65039], true)
  end

  def test_groups_js_es6_creation
    assert File.exist?(EMOJI_GROUPS_PATH)
    assert File.size?(EMOJI_GROUPS_PATH)
  end

  def test_db_json_creation
    assert File.exist?(EMOJI_DB_PATH)
    assert File.size?(EMOJI_DB_PATH)
  end

  def test_alias_creation
    original_image = image_path("apple", "right_anger_bubble")
    alias_image = image_path("apple", "anger_right")

    assert_equal File.size(original_image), File.size(alias_image)
  end

  def test_cell_index_patch
    original_image = image_path("apple", "snowboarder")
    alias_image = image_path("twitter", "snowboarder")

    assert_equal File.size(original_image), File.size(alias_image)
  end

  def test_scales
    original_image = image_path("apple", "blonde_woman")
    assert File.exist?(original_image)
    assert File.size?(original_image)

    (2..6).each do |scale|
      image = image_path("apple", "blonde_woman/#{scale}")
      assert File.exist?(image)
      assert File.size?(image)
    end
  end

  def test_default_set
    original_image = image_path("twitter", "snowboarder")
    alias_image = image_path("apple", "snowboarder")
    assert_equal File.size(original_image), File.size(alias_image)

    original_image = image_path("twitter", "macau")
    alias_image = image_path("win10", "macau")
    assert_equal File.size(original_image), File.size(alias_image)
  end
end
