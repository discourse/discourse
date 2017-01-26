class Emoji
  # update this to clear the cache
  EMOJI_VERSION = "v2"

  include ActiveModel::SerializerSupport

  attr_reader :path
  attr_accessor :name, :url

  # whitelist emojis so that new user can post emojis
  Post::white_listed_image_classes << "emoji"

  def initialize(path = nil)
    @path = path
  end

  def remove
    return if path.blank?
    if File.exists?(path)
      File.delete(path) rescue nil
      Emoji.clear_cache
    end
  end

  def self.all
    Discourse.cache.fetch(cache_key("all_emojis")) { standard | custom }
  end

  def self.standard
    Discourse.cache.fetch(cache_key("standard_emojis")) { load_standard }
  end

  def self.aliases
    Discourse.cache.fetch(cache_key("aliases_emojis")) { load_aliases }
  end

  def self.custom
    Discourse.cache.fetch(cache_key("custom_emojis")) { load_custom }
  end

  def self.exists?(name)
    Emoji[name].present?
  end

  def self.[](name)
    Emoji.custom.detect { |e| e.name == name }
  end

  def self.create_from_path(path)
    extension = File.extname(path)
    Emoji.new(path).tap do |e|
      e.name = File.basename(path, ".*")
      e.url = "#{base_url}/#{e.name}#{extension}"
    end
  end

  def self.create_from_db_item(emoji)
    name = emoji["name"]
    filename = "#{emoji['filename'] || name}.png"
    Emoji.new.tap do |e|
      e.name = name
      e.url = "/images/emoji/#{SiteSetting.emoji_set}/#{filename}"
    end
  end

  def self.create_for(file, name)
    extension = File.extname(file.original_filename)
    path = "#{Emoji.base_directory}/#{name}#{extension}"
    full_path = "#{Rails.root}/#{path}"

    # store the emoji
    FileUtils.mkdir_p(Pathname.new(path).dirname)
    File.open(path, "wb") { |f| f << file.tempfile.read }
    # clear the cache
    Emoji.clear_cache
    # launch resize job
    Jobs.enqueue(:resize_emoji, path: full_path)
    # return created emoji
    Emoji[name]
  end

  def self.cache_key(name)
    "#{name}:#{EMOJI_VERSION}:#{Plugin::CustomEmoji.cache_key}"
  end

  def self.clear_cache
    Discourse.cache.delete(cache_key("custom_emojis"))
    Discourse.cache.delete(cache_key("standard_emojis"))
    Discourse.cache.delete(cache_key("aliases_emojis"))
    Discourse.cache.delete(cache_key("all_emojis"))
  end

  def self.db_file
    "#{Rails.root}/lib/emoji/db.json"
  end

  def self.db
    return @db if @db
    @db = File.open(db_file, "r:UTF-8") { |f| JSON.parse(f.read) }

    # Small tweak to `emoji.json` from Emoji one
    @db['emojis'] << {"code" => "1f44d", "name" => "+1", "filename" => "thumbsup"}
    @db['emojis'] << {"code" => "1f44e", "name" => "-1", "filename" => "thumbsdown"}

    @db
  end

  def self.load_standard
    db['emojis'].map {|e| Emoji.create_from_db_item(e) }
  end

  def self.load_aliases
    return @aliases if @aliases

    @aliases ||= db['aliases']

    # Fix how `slightly_smiling` was mislabeled
    @aliases['slight_smile'] ||= []
    @aliases['slight_smile'] << 'slightly_smiling'

    @aliases
  end

  def self.load_custom
    result = []

    Dir.glob(File.join(Emoji.base_directory, "*.{png,gif}"))
       .sort
       .each { |emoji| result << Emoji.create_from_path(emoji) }

    Plugin::CustomEmoji.emojis.each do |name, url|
      result << Emoji.new.tap do |e|
        e.name = name
        e.url = url
      end
    end

    result
  end

  def self.base_directory
    "public#{base_url}"
  end

  def self.base_url
    db = RailsMultisite::ConnectionManagement.current_db
    "#{Discourse.base_uri}/uploads/#{db}/_emoji"
  end

  def self.replacement_code(code)
    hexes = code.split('-').map(&:hex)

    # Don't replace digits, letters and some symbols
    return hexes.pack("U" * hexes.size) if hexes[0] > 255
  end

  def self.unicode_replacements
    return @unicode_replacements if @unicode_replacements


    @unicode_replacements = {}
    db['emojis'].each do |e|
      next if e['name'] == 'tm'
      code = replacement_code(e['code'])
      @unicode_replacements[code] = e['name'] if code
    end

    @unicode_replacements["\u{2639}"] = 'frowning'
    @unicode_replacements["\u{263A}"] = 'slight_smile'
    @unicode_replacements["\u{263B}"] = 'slight_smile'
    @unicode_replacements["\u{2661}"] = 'heart'
    @unicode_replacements["\u{2665}"] = 'heart'

    @unicode_replacements
  end

  def self.lookup_unicode(name)
    @reverse_map ||= begin
      map = {}
      db['emojis'].each do |e|
        next if e['name'] == 'tm'
        code = replacement_code(e['code'])
        map[e['name']] = code if code
      end
      map
    end
    @reverse_map[name]
  end

  def self.unicode_replacements_json
    @unicode_replacements_json ||= unicode_replacements.to_json
  end

end
