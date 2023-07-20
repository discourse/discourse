# frozen_string_literal: true

require "colored2"
require_relative "base"
require_relative "base/generic_database"

# Minimal Slack importer
# It imports users and messages into Discourse topics/posts

# Call it like this:
# IMPORT=1 bundle install
# IMPORT=1 bundle exec ruby script/import_scripts/slack.rb "PATH_TO_SLACK_EXPORT"
#
# You will need to create a channels-mapping.json file in order to map Slack channels to Discourse categories and tags.
# The import script will create a template for you if you don't have one.

class ImportScripts::Slack < ImportScripts::Base
  TITLE_TIMEZONE = "America/Los_Angeles"

  def initialize(base_path)
    super()
    @base_path = base_path
    @db = ImportScripts::GenericDatabase.new(@base_path, recreate: true)
  end

  def execute
    @channel_mapping = load_channel_mapping
    read_json_files

    import_users
    import_categories
    import_topics
    import_posts
  end

  private

  def read_json_files
    puts "", "Reading JSON files..."

    json_from_file("users.json").each do |user|
      next if user[:deleted]

      @db.insert_user(
        id: user[:id],
        email: user[:profile][:email],
        name: user[:real_name],
        staged: !user[:is_email_confirmed],
        admin: user[:is_admin],
        avatar_path: user[:profile][:image_original],
      )
    end

    @channel_mapping.each do |mapping|
      @db.insert_category(id: mapping[:slack_channel], name: mapping[:discourse_category])

      json_from_directory(mapping[:slack_channel]).each do |message|
        raise "Unknown type: #{message[:type]}" if message[:type] != "message"

        topic_id = message[:thread_ts] || message[:ts]
        created_at = Time.at(message[:ts].to_f).in_time_zone(TITLE_TIMEZONE)
        attachments = message[:files]&.map { |file| file[:url_private_download] }

        if message[:ts] == topic_id
          @db.insert_topic(
            id: topic_id,
            title: "Thread starting at #{created_at.iso8601}",
            raw: message[:text].presence || "No text",
            category_id: mapping[:slack_channel],
            created_at: message[:ts],
            user_id: message[:user],
            tags: Oj.dump(mapping[:discourse_tags]),
            attachments: attachments,
          )
        else
          @db.insert_post(
            id: message[:client_msg_id],
            raw: message[:text].presence || "No text",
            topic_id: topic_id,
            created_at: message[:ts],
            user_id: message[:user],
            attachments: attachments,
          )
        end
      end

      @db.create_missing_topics do |topic|
        created_at = Time.at(topic["created_at"].to_f).in_time_zone(TITLE_TIMEZONE)
        topic[:title] = "Thread starting at #{created_at.iso8601}"
        topic[:category_id] = mapping[:slack_channel]
        topic[:tags] = Oj.dump(mapping[:discourse_tags])
        topic
      end
    end

    @db.calculate_user_created_at_dates
    @db.calculate_user_last_seen_at_dates
    @db.sort_posts_by_created_at
  end

  def import_categories
    puts "", "Creating categories..."
    rows = @db.fetch_categories

    create_categories(rows) { |row| { id: row["id"], name: row["name"] } }
  end

  def import_users
    puts "", "Creating users..."
    total_count = @db.count_users
    last_id = ""

    batches do |offset|
      rows, last_id = @db.fetch_users(last_id)
      break if rows.empty?

      next if all_records_exist?(:users, rows.map { |row| row["id"] })

      create_users(rows, total: total_count, offset: offset) do |row|
        {
          id: row["id"],
          email: row["email"].presence || fake_email,
          name: row["name"],
          created_at: row["created_at"],
          last_seen_at: row["last_seen_at"],
          active: row["active"] == 1,
          staged: row["staged"] == 1,
          admin: row["admin"] == 1,
          merge: true,
          post_create_action:
            proc do |user|
              if row["avatar_path"].present?
                begin
                  UserAvatar.import_url_for_user(row["avatar_path"], user)
                rescue StandardError
                  nil
                end
              end
            end,
        }
      end
    end
  end

  def import_topics
    puts "", "Creating topics..."
    total_count = @db.count_topics
    last_id = ""

    batches do |offset|
      rows, last_id = @db.fetch_topics(last_id)
      break if rows.empty?

      next if all_records_exist?(:posts, rows.map { |row| row["id"] })

      create_posts(rows, total: total_count, offset: offset) do |row|
        user_id = user_id_from_imported_user_id(row["user_id"]) || Discourse.system_user.id
        attachments = @db.fetch_topic_attachments(row["id"]) if row["upload_count"] > 0

        {
          id: row["id"],
          title: row["title"].present? ? row["title"].strip[0...255] : "Topic title missing",
          raw: to_markdown(row["raw"], attachments, user_id),
          category: category_id_from_imported_category_id(row["category_id"]),
          user_id: user_id,
          created_at: Time.at(row["created_at"].to_f),
          tags: Oj.load(row["tags"]),
        }
      end
    end
  end

  def import_posts
    puts "", "creating posts"
    total_count = @db.count_posts
    last_row_id = 0

    batches do |offset|
      rows, last_row_id = @db.fetch_sorted_posts(last_row_id)
      break if rows.empty?

      next if all_records_exist?(:posts, rows.map { |row| row["id"] })

      create_posts(rows, total: total_count, offset: offset) do |row|
        topic = topic_lookup_from_imported_post_id(row["topic_id"])
        user_id = user_id_from_imported_user_id(row["user_id"]) || Discourse.system_user.id
        attachments = @db.fetch_post_attachments(row["id"]) if row["upload_count"] > 0

        {
          id: row["id"],
          raw: to_markdown(row["raw"], attachments, user_id),
          user_id: user_id,
          topic_id: topic[:topic_id],
          created_at: Time.at(row["created_at"].to_f),
        }
      end
    end
  end

  def json_from_file(relative_path)
    absolute_path = File.join(@base_path, relative_path)
    load_json(absolute_path)
  end

  def json_from_directory(directory)
    base_path = File.join(@base_path, directory)
    raise "Directory #{base_path} does not exist" unless File.directory?(base_path)

    Enumerator.new do |y|
      # Don't use Dir[] because it allocates an array with the path of every file it finds
      # which can use a huge amount of memory!
      IO.popen(["find", base_path, "-name", "*.json"]) do |io|
        io.each_line do |path|
          path.chomp!
          load_json(path).each { |item| y.yield(item) }
        end
      end
    end
  end

  def load_json(path)
    raise "File #{path} does not exist" unless File.exist?(path)
    Oj.load(File.read(path), { mode: :strict, symbol_keys: true })
  end

  def load_channel_mapping
    path = File.join(@base_path, "channel-mapping.json")

    if !File.exist?(path)
      create_channel_mapping_file(path)
      puts "", "ERROR: channel-mapping.json is missing".red
      puts "An example file has been created at #{path}".red, "Please edit it and try again.".red
      exit 1
    end

    load_json(path)
  end

  def create_channel_mapping_file(mapping_file_path)
    mapping =
      Dir[File.join(@base_path, "/*/")].map do |path|
        channel = File.basename(path)
        { slack_channel: channel, discourse_category: channel, discourse_tags: [] }
      end

    File.write(mapping_file_path, Oj.dump(mapping, indent: 4))
  end

  def to_markdown(text, attachments, user_id)
    # Emoji skin tones
    text.gsub!(/::skin-tone-(\d):/, ':t\1:')

    # Mentions
    text.gsub!(/<@(\w+)>/) do
      mentioned_user_id = $1
      username = @lookup.find_username_by_import_id(mentioned_user_id)
      username ? "@#{username}" : "`@#{mentioned_user_id}`"
    end

    # Links
    text.gsub!(%r{<(https?://[^|]+?)\|([^>]+?)>}, '[\2](\1)')
    text.gsub!(%r{<(https?://[^>]+?)>}, '\1')

    # Code blocks
    text.gsub!(/```(.+?)```/m, "```\n\\1\n```")

    # Images and files
    if attachments
      attachments.each do |attachment|
        upload_markdown = download_file(attachment["path"], user_id)
        text << "\n#{upload_markdown}"
      end
    end

    text
  end

  def download_file(url, user_id)
    uri = URI.parse(url)
    filename = File.basename(uri.path)

    tempfile =
      FileHelper.download(
        url,
        max_file_size: SiteSetting.max_image_size_kb.kilobytes,
        tmp_file_name: "sso-avatar",
        follow_redirect: true,
      )

    return unless tempfile

    upload = UploadCreator.new(tempfile, filename, origin: url).create_for(user_id)
    html_for_upload(upload, filename)
  ensure
    tempfile.close! if tempfile && tempfile.respond_to?(:close!)
  end
end

ImportScripts::Slack.new(ARGV[0]).perform
