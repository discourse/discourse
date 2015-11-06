class Emoji
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
    Discourse.cache.fetch("all_emojis") { standard | custom }
  end

  def self.standard
    Discourse.cache.fetch("standard_emojis") { load_standard }
  end

  def self.aliases
    Discourse.cache.fetch("aliases_emojis") { load_aliases }
  end

  def self.custom
    Discourse.cache.fetch("custom_emojis") { load_custom }
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
    name = emoji["aliases"].first
    filename = "#{name}.png"
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
    Discourse.cache.delete("custom_emojis")
    Discourse.cache.delete("standard_emojis")
    Discourse.cache.delete("aliases_emojis")
    Discourse.cache.delete("all_emojis")
  end

  def self.db_file
    "#{Rails.root}/lib/emoji/db.json"
  end

  def self.db
    @db ||= File.open(db_file, "r:UTF-8") { |f| JSON.parse(f.read) }
  end

  def self.load_standard
    db.map { |emoji| Emoji.create_from_db_item(emoji) }
  end

  def self.load_aliases
    aliases = {}

    db.select { |emoji| emoji["aliases"].count > 1 }
      .each { |emoji| aliases[emoji["aliases"][0]] = emoji["aliases"][1..-1] }

    aliases
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

end
