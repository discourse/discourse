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
    Discourse.cache.fetch("all_emojis:#{EMOJI_VERSION}") { standard | custom }
  end

  def self.standard
    Discourse.cache.fetch("standard_emojis:#{EMOJI_VERSION}") { load_standard }
  end

  def self.aliases
    Discourse.cache.fetch("aliases_emojis:#{EMOJI_VERSION}") { load_aliases }
  end

  def self.custom
    Discourse.cache.fetch("custom_emojis:#{EMOJI_VERSION}") { load_custom }
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

    # store the emoji
    FileUtils.mkdir_p(Pathname.new(path).dirname)
    File.open(path, "wb") { |f| f << file.tempfile.read }
    # clear the cache
    Emoji.clear_cache
    # launch resize job
    Jobs.enqueue(:resize_emoji, path: path)
    # return created emoji
    Emoji[name]
  end

  def self.clear_cache
    Discourse.cache.delete("custom_emojis:#{EMOJI_VERSION}")
    Discourse.cache.delete("standard_emojis:#{EMOJI_VERSION}")
    Discourse.cache.delete("aliases_emojis:#{EMOJI_VERSION}")
    Discourse.cache.delete("all_emojis:#{EMOJI_VERSION}")
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
    Dir.glob(File.join(Emoji.base_directory, "*.{png,gif}"))
       .sort
       .map { |emoji| Emoji.create_from_path(emoji) }
  end

  def self.base_directory
    "public#{base_url}"
  end

  def self.base_url
    db = RailsMultisite::ConnectionManagement.current_db
    "#{Discourse.base_uri}/uploads/#{db}/_emoji"
  end

  def self.unicode_replacements
    return @unicode_replacements if @unicode_replacements


    @unicode_replacements = {}
    db['emojis'].each do |e|
      hex = e['code'].hex
      # Don't replace digits, letters and some symbols
      if hex > 255 && e['name'] != 'tm'
        @unicode_replacements[[hex].pack('U')] = e['name']
      end
    end

    @unicode_replacements["\u{2639}"] = 'frowning'
    @unicode_replacements["\u{263A}"] = 'slight_smile'
    @unicode_replacements["\u{263B}"] = 'slight_smile'
    @unicode_replacements["\u{2661}"] = 'heart'
    @unicode_replacements["\u{2665}"] = 'heart'

    @unicode_replacements
  end

  def self.unicode_replacements_json
    @unicode_replacements_json ||= unicode_replacements.to_json
  end

end
