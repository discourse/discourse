# frozen_string_literal: true

require 'csv'
require 'reverse_markdown'
require_relative 'base'
require_relative 'base/generic_database'

# Call it like this:
#   RAILS_ENV=production bundle exec ruby script/import_scripts/answerbase.rb DIRNAME
class ImportScripts::Answerbase < ImportScripts::Base
  OLD_DOMAIN = "http://answerbase.example.com" # without trailing slash
  NEW_DOMAIN = "https://discourse.example.com"
  AVATAR_DIRECTORY = "User Images"
  ANSWER_ATTACHMENT_DIRECTORY = "Answer Attachments"
  ANSWER_IMAGE_DIRECTORY = "Answer Images"
  QUESTION_ATTACHMENT_DIRECTORY = "Question Attachments"
  QUESTION_IMAGE_DIRECTORY = "Question Images"
  EMBEDDED_IMAGE_REGEX = /<a[^>]*href="[^"]*relativeUrl=(?<path>[^"\&]*)[^"]*"[^>]*>\s*<img[^>]*>\s*<\/a>/i
  QUESTION_LINK_REGEX = /<a[^>]*?href="#{Regexp.escape(OLD_DOMAIN)}\/[^"]*?(?:q|questionid=)(?<id>\d+)[^"]*?"[^>]*>(?<text>.*?)<\/a>/i
  TOPIC_LINK_NORMALIZATION = '/.*?-(q\d+).*/\1'
  BATCH_SIZE = 1000

  def initialize(path)
    super()

    @path = path
    @db = ImportScripts::GenericDatabase.new(
      @path,
      batch_size: BATCH_SIZE,
      recreate: true,
      numeric_keys: true
    )
  end

  def execute
    read_csv_files

    add_permalink_normalizations
    import_categories
    import_users
    import_topics
    import_posts
  end

  def read_csv_files
    puts "", "reading CSV files..."

    category_position = 0
    csv_parse("categories") do |row|
      @db.insert_category(
        id: row[:id],
        name: row[:name],
        position: category_position += 1
      )
    end

    csv_parse("users") do |row|
      @db.insert_user(
        id: row[:id],
        email: row[:email],
        username: row[:username],
        bio: row[:description],
        avatar_path: row[:profile_image],
        created_at: parse_date(row[:createtime]),
        active: true
      )
    end

    last_topic_id = nil
    csv_parse("questions-answers-comments") do |row|
      next if row[:published] == "No"
      user_id = @db.get_user_id(row[:username])
      created_at = parse_datetime(row[:createtime])

      begin
        if row[:type] == "Question"
          attachments = parse_filenames(row[:attachments], QUESTION_ATTACHMENT_DIRECTORY) +
            parse_filenames(row[:images], QUESTION_IMAGE_DIRECTORY)

          @db.insert_topic(
            id: row[:id],
            title: row[:title],
            raw: row[:text],
            category_id: row[:categorylist],
            user_id: user_id,
            created_at: created_at,
            attachments: attachments
          )
          last_topic_id = row[:id]
        else
          attachments = parse_filenames(row[:attachments], ANSWER_ATTACHMENT_DIRECTORY) +
            parse_filenames(row[:images], ANSWER_IMAGE_DIRECTORY)

          @db.insert_post(
            id: row[:id],
            raw: row[:text],
            topic_id: last_topic_id,
            user_id: user_id,
            created_at: created_at,
            attachments: attachments
          )
        end
      rescue
        p row
        raise
      end
    end
  end

  def parse_filenames(text, directory)
    return [] if text.blank?

    text
      .split(';')
      .map { |filename| File.join(@path, directory, filename.strip) }
  end

  def parse_date(text)
    return nil if text.blank?
    DateTime.strptime(text, "%m/%d/%y")
  end

  def parse_datetime(text)
    return nil if text.blank?
    # DateTime.strptime(text, "%m/%d/%Y %H:%M")
    DateTime.parse(text).utc.to_datetime
  end

  def import_categories
    puts "", "creating categories"
    rows = @db.fetch_categories

    create_categories(rows) do |row|
      {
        id: row['id'],
        name: row['name'],
        description: row['description'],
        position: row['position']
      }
    end
  end

  def batches
    super(BATCH_SIZE)
  end

  def import_users
    puts "", "creating users"
    total_count = @db.count_users
    last_id = 0

    batches do |offset|
      rows, last_id = @db.fetch_users(last_id)
      break if rows.empty?

      next if all_records_exist?(:users, rows.map { |row| row['id'] })

      create_users(rows, total: total_count, offset: offset) do |row|
        {
          id: row['id'],
          email: row['email'],
          username: row['username'],
          bio_raw: row['bio'],
          created_at: row['created_at'],
          active: row['active'] == 1,
          post_create_action: proc do |user|
            create_avatar(user, row['avatar_path'])
          end
        }
      end
    end
  end

  def create_avatar(user, avatar_path)
    return if avatar_path.blank?
    avatar_path = File.join(@path, AVATAR_DIRECTORY, avatar_path)

    if File.exist?(avatar_path)
      @uploader.create_avatar(user, avatar_path)
    else
      STDERR.puts "Could not find avatar: #{avatar_path}"
    end
  end

  def import_topics
    puts "", "creating topics"
    total_count = @db.count_topics
    last_id = 0

    batches do |offset|
      rows, last_id = @db.fetch_topics(last_id)
      break if rows.empty?

      next if all_records_exist?(:posts, rows.map { |row| row['id'] })

      create_posts(rows, total: total_count, offset: offset) do |row|
        attachments = @db.fetch_topic_attachments(row['id']) if row['upload_count'] > 0
        user_id = user_id_from_imported_user_id(row['user_id']) || Discourse.system_user.id

        {
          id: row['id'],
          title: row['title'],
          raw: raw_with_attachments(row['raw'].presence || row['title'], attachments, user_id),
          category: category_id_from_imported_category_id(row['category_id']),
          user_id: user_id,
          created_at: row['created_at'],
          closed: row['closed'] == 1,
          post_create_action: proc do |post|
            url = "q#{row['id']}"
            Permalink.create(url: url, topic_id: post.topic.id) unless permalink_exists?(url)
          end
        }
      end
    end
  end

  def import_posts
    puts "", "creating posts"
    total_count = @db.count_posts
    last_row_id = 0

    batches do |offset|
      rows, last_row_id = @db.fetch_posts(last_row_id)
      break if rows.empty?

      next if all_records_exist?(:posts, rows.map { |row| row['id'] })

      create_posts(rows, total: total_count, offset: offset) do |row|
        topic = topic_lookup_from_imported_post_id(row['topic_id'])
        attachments = @db.fetch_post_attachments(row['id']) if row['upload_count'] > 0
        user_id = user_id_from_imported_user_id(row['user_id']) || Discourse.system_user.id

        {
          id: row['id'],
          raw: raw_with_attachments(row['raw'], attachments, user_id),
          user_id: user_id,
          topic_id: topic[:topic_id],
          created_at: row['created_at']
        }
      end
    end
  end

  def raw_with_attachments(raw, attachments, user_id)
    raw, embedded_paths, upload_ids = replace_embedded_attachments(raw, user_id)
    raw = replace_question_links(raw)
    raw = ReverseMarkdown.convert(raw) || ""

    attachments&.each do |attachment|
      path = attachment['path']
      next if embedded_paths.include?(path)

      if File.exist?(path)
        filename = File.basename(path)
        upload = @uploader.create_upload(user_id, path, filename)

        if upload.present? && upload.persisted? && !upload_ids.include?(upload.id)
          raw = "#{raw}\n#{@uploader.html_for_upload(upload, filename)}"
        end
      else
        STDERR.puts "Could not find file: #{path}"
      end
    end

    raw
  end

  def replace_embedded_attachments(raw, user_id)
    paths = []
    upload_ids = []

    raw = raw.gsub(EMBEDDED_IMAGE_REGEX) do
      path = File.join(@path, Regexp.last_match['path'])
      filename = File.basename(path)
      path = find_image_path(filename)

      if path
        upload = @uploader.create_upload(user_id, path, filename)

        if upload.present? && upload.persisted?
          paths << path
          upload_ids << upload.id
          @uploader.html_for_upload(upload, filename)
        end
      else
        STDERR.puts "Could not find file: #{path}"
      end
    end

    [raw, paths, upload_ids]
  end

  def find_image_path(filename)
    [QUESTION_IMAGE_DIRECTORY, ANSWER_IMAGE_DIRECTORY].each do |directory|
      path = File.join(@path, directory, filename)
      return path if File.exist?(path)
    end
  end

  def replace_question_links(raw)
    raw.gsub(QUESTION_LINK_REGEX) do
      topic_id = Regexp.last_match("id")
      topic = topic_lookup_from_imported_post_id(topic_id)
      return Regexp.last_match.to_s unless topic

      url = File.join(NEW_DOMAIN, topic[:url])
      text = Regexp.last_match("text")
      text.include?(OLD_DOMAIN) ? url : "<a href='#{url}'>#{text}</a>"
    end
  end

  def add_permalink_normalizations
    normalizations = SiteSetting.permalink_normalizations
    normalizations = normalizations.blank? ? [] : normalizations.split('|')

    add_normalization(normalizations, TOPIC_LINK_NORMALIZATION)

    SiteSetting.permalink_normalizations = normalizations.join('|')
  end

  def add_normalization(normalizations, normalization)
    normalizations << normalization unless normalizations.include?(normalization)
  end

  def permalink_exists?(url)
    Permalink.find_by(url: url)
  end

  def csv_parse(table_name)
    CSV.foreach(File.join(@path, "#{table_name}.csv"),
                headers: true,
                header_converters: :symbol,
                skip_blanks: true,
                encoding: 'bom|utf-8') { |row| yield row }
  end
end

unless ARGV[0] && Dir.exist?(ARGV[0])
  puts "", "Usage:", "", "bundle exec ruby script/import_scripts/answerbase.rb DIRNAME", ""
  exit 1
end

ImportScripts::Answerbase.new(ARGV[0]).perform
