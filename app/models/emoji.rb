class Emoji
  # update this to clear the cache
  EMOJI_VERSION = "6"

  FITZPATRICK_SCALE ||= [ "1f3fb", "1f3fc", "1f3fd", "1f3fe", "1f3ff" ]

  include ActiveModel::SerializerSupport

  attr_reader :path
  attr_accessor :name, :url

  def initialize(path = nil)
    @path = path
  end

  def self.all
    Discourse.cache.fetch(cache_key("all_emojis")) { standard | custom }
  end

  def self.standard
    Discourse.cache.fetch(cache_key("standard_emojis")) { load_standard }
  end

  def self.aliases
    Discourse.cache.fetch(cache_key("aliases_emojis")) { db['aliases'] }
  end

  def self.search_aliases
    Discourse.cache.fetch(cache_key("search_aliases_emojis")) { db['searchAliases'] }
  end

  def self.translations
    Discourse.cache.fetch(cache_key("translations_emojis")) { load_translations }
  end

  def self.custom
    Discourse.cache.fetch(cache_key("custom_emojis")) { load_custom }
  end

  def self.tonable_emojis
    Discourse.cache.fetch(cache_key("tonable_emojis")) { db['tonableEmojis'] }
  end

  def self.exists?(name)
    Emoji[name].present?
  end

  def self.[](name)
    Emoji.custom.detect { |e| e.name == name }
  end

  def self.create_from_db_item(emoji)
    name = emoji["name"]
    filename = emoji['filename'] || name
    Emoji.new.tap do |e|
      e.name = name
      e.url = Emoji.url_for(filename)
    end
  end

  def self.url_for(name)
    "#{Discourse.base_uri}/images/emoji/#{SiteSetting.emoji_set}/#{name}.png?v=#{EMOJI_VERSION}"
  end

  def self.cache_key(name)
    "#{name}:v#{EMOJI_VERSION}:#{Plugin::CustomEmoji.cache_key}"
  end

  def self.clear_cache
    %w{custom standard aliases search_aliases translations all tonable}.each do |key|
      Discourse.cache.delete(cache_key("#{key}_emojis"))
    end
  end

  def self.db_file
    @db_file ||= "#{Rails.root}/lib/emoji/db.json"
  end

  def self.db
    @db ||= File.open(db_file, "r:UTF-8") { |f| JSON.parse(f.read) }
  end

  def self.load_standard
    db['emojis'].map { |e| Emoji.create_from_db_item(e) }
  end

  def self.load_custom
    result = []

    CustomEmoji.includes(:upload).order(:name).each do |emoji|
      result << Emoji.new.tap do |e|
        e.name = emoji.name
        e.url = emoji.upload&.url
      end
    end

    Plugin::CustomEmoji.emojis.each do |name, url|
      result << Emoji.new.tap do |e|
        e.name = name
        url = (Discourse.base_uri + url) if url[/^\/[^\/]/]
        e.url = url
      end
    end

    result
  end

  def self.load_translations
    db["translations"].merge(Plugin::CustomEmoji.translations)
  end

  def self.base_directory
    "public#{base_url}"
  end

  def self.base_url
    db = RailsMultisite::ConnectionManagement.current_db
    "#{Discourse.base_uri}/uploads/#{db}/_emoji"
  end

  def self.replacement_code(code)
    hexes = code.split('-'.freeze).map!(&:hex)
    # Don't replace digits, letters and some symbols
    hexes.pack("U*".freeze) if hexes[0] > 255
  end

  def self.unicode_replacements
    @unicode_replacements ||= begin
      replacements = {}
      is_tonable_emojis = Emoji.tonable_emojis
      fitzpatrick_scales = FITZPATRICK_SCALE.map { |scale| scale.to_i(16) }

      db['emojis'].each do |e|
        name = e['name']
        next if name == 'tm'.freeze

        code = replacement_code(e['code'])
        next unless code

        replacements[code] = name
        if is_tonable_emojis.include?(name)
          fitzpatrick_scales.each_with_index do |scale, index|
            toned_code = code.codepoints.insert(1, scale).pack("U*".freeze)
            replacements[toned_code] = "#{name}:t#{index + 2}"
          end
        end
      end

      replacements["\u{2639}"] = 'frowning'
      replacements["\u{263A}"] = 'slight_smile'
      replacements["\u{263B}"] = 'slight_smile'
      replacements["\u{2661}"] = 'heart'
      replacements["\u{2665}"] = 'heart'

      replacements
    end
  end

  def self.unicode_unescape(string)
    string.each_char.map do |c|
      if str = unicode_replacements[c]
        ":#{str}:"
      else
        c
      end
    end.join
  end

  def self.gsub_emoji_to_unicode(str)
    if str
      str.gsub(/:([\w\-+]*(?::t\d)?):/) { |name| Emoji.lookup_unicode($1) || name }
    end
  end

  def self.lookup_unicode(name)
    @reverse_map ||= begin
      map = {}
      is_tonable_emojis = Emoji.tonable_emojis

      db['emojis'].each do |e|
        next if e['name'] == 'tm'

        code = replacement_code(e['code'])
        next unless code

        map[e['name']] = code
        if is_tonable_emojis.include?(e['name'])
          FITZPATRICK_SCALE.each_with_index do |scale, index|
            toned_code = (code.codepoints.insert(1, scale.to_i(16))).pack("U*")
            map["#{e['name']}:t#{index + 2}"] = toned_code
          end
        end
      end

      Emoji.aliases.each do |key, alias_names|
        next unless alias_code = map[key]
        alias_names.each do |alias_name|
          map[alias_name] = alias_code
        end
      end

      map
    end
    @reverse_map[name]
  end

  def self.unicode_replacements_json
    @unicode_replacements_json ||= unicode_replacements.to_json
  end

end
