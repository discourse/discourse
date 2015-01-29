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
    Discourse.cache.fetch("all", family: "emoji") { standard | custom }
  end

  def self.standard
    Discourse.cache.fetch("standard", family: "emoji") { load_standard }
  end

  def self.custom
    Discourse.cache.fetch("custom", family: "emoji") { load_custom }
  end

  def self.create_from_path(path)
    extension = File.extname(path)
    Emoji.new(path).tap do |e|
      e.name = File.basename(path, ".*")
      e.url = "/#{base_url}/#{e.name}#{extension}"
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
    Emoji.custom.detect { |e| e.name == name }
  end

  def self.clear_cache
    Discourse.cache.delete_by_family("emoji")
  end

  def self.db_file
    "#{Rails.root}/lib/emoji/db.json"
  end

  def self.load_standard
    File.open(db_file, "r:UTF-8") { |f| JSON.parse(f.read) }
        .map { |emoji| Emoji.create_from_db_item(emoji) }
  end

  def self.load_custom
    Dir.glob(File.join(Emoji.base_directory, "*.{png,gif}"))
       .sort
       .map { |emoji| Emoji.create_from_path(emoji) }
  end

  def self.base_directory
    "public/#{base_url}"
  end

  def self.base_url
    db = RailsMultisite::ConnectionManagement.current_db
    "uploads/#{db}/_emoji"
  end

end
