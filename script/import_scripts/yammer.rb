# frozen_string_literal: true

# Yammer importer
#  https://docs.microsoft.com/en-us/yammer/manage-security-and-compliance/export-yammer-enterprise-data#export-yammer-network-data-by-date-range-and-network
#
# You will need a bunch of CSV files:
#
# - Users.csv Groups.csv Topics.csv Groups.csv Files.csv Messages.csv
# (Others included in Yammer export are ignored)

require "csv"
require_relative "base"
require_relative "base/generic_database"

# Call it like this:
#   RAILS_ENV=production bundle exec ruby script/import_scripts/yammer.rb DIRNAME

class ImportScripts::Yammer < ImportScripts::Base
  BATCH_SIZE = 1000
  NUM_WORDS_IN_TITLE = ENV["NUM_WORDS_IN_TITLE"].to_i || 20
  SKIP_EMPTY_EMAIL = true
  SKIP_INACTIVE_USERS = false
  PARENT_CATEGORY_NAME = ENV["PARENT_CATEGORY_NAME"] || "Yammer Import"
  IMPORT_GROUPS_AS_TAGS = true
  MERGE_USERS = true
  # import groups as tags rather than as categories
  SiteSetting.tagging_enabled = true if IMPORT_GROUPS_AS_TAGS
  PM_TAG = ENV["PM_TAG"] || "eht"

  def initialize(path)
    super()

    @path = path
    @db = ImportScripts::GenericDatabase.new(@path, batch_size: BATCH_SIZE, recreate: true)
  end

  def execute
    create_developer_users
    read_csv_files

    import_categories
    import_users
    import_topics
    import_pm_topics
    import_posts
    import_pm_posts
  end

  def create_developer_users
    GlobalSetting
      .developer_emails
      .split(",")
      .each { |e| User.create(email: e, active: true, username: e.split("@")[0]) }
  end

  def read_csv_files
    puts "", "reading CSV files"

    # consider csv_parse Tags.csv
    # consider Admins.csv that has admins

    u_count = 0
    csv_parse("Users") do |row|
      next if SKIP_INACTIVE_USERS && row[:state] != "active"
      u_count += 1
      @db.insert_user(
        id: row[:id],
        email: row[:email],
        name: row[:name],
        username: row[:name],
        bio: "",
        # job_title: row[:job_title],
        # location: row[:location],
        # department: row[:department],
        created_at: parse_datetime(row[:joined_at]),
        # deleted_at: parse_datetime(row[:deleted_at]),
        # suspended_at: parse_datetime(row[:suspended_at]),
        # guid: row[:guid],
        # state: row[:state],
        avatar_path: row[:user_cover_image_url],
        # last_seen_at: ,
        active: row[:state] == "active" ? 1 : 0,
      )
    end

    category_position = 0
    csv_parse("Groups") do |row|
      @db.insert_category(
        id: row[:id],
        name: row[:name],
        description: row[:description],
        position: category_position += 1,
      )
    end

    csv_parse("Files") do |row|
      @db.insert_upload(
        id: row[:file_id],
        user_id: row[:uploader_id],
        original_filename: row[:name],
        filename: row[:path],
        description: row[:description],
      )
    end

    # get topics from messages
    csv_parse("Messages") do |row|
      next unless row[:thread_id] == row[:id]
      next if row[:in_private_conversation] == "true"
      next if row[:deleted_at].present?
      # next if row[:message_type] == 'system'
      title = ""
      url = ""
      description = ""
      raw = row[:body]
      reg = /opengraphobject:\[(\d*?) : (.*?) : title="(.*?)" : description="(.*?)"\]/
      if row[:attachments]
        row[:attachments].match(reg) do
          url = Regexp.last_match(2)
          title = Regexp.last_match(3) if Regexp.last_match(3)
          description = Regexp.last_match(4)
          raw += "\n***\n#{description}\n#{url}\n" if raw.exclude?(url)
        end
        row[:attachments].match(/uploadedfile:(\d*)$/) do
          file_id = Regexp.last_match(1).to_i
          up = @db.fetch_upload(file_id).first
          path = File.join(@path, up["filename"])
          filename = up["original_filename"]
          user_id = user_id_from_imported_user_id(row["user_id"]) || Discourse.system_user.id
          if File.exist?(path)
            upload = create_upload(user_id, path, filename)
            raw += html_for_upload(upload, filename) if upload&.persisted?
          end
        end
      end
      @db.insert_topic(
        id: row[:id],
        title: title,
        raw: raw,
        category_id: row[:group_id],
        closed: row[:closed] == "TRUE" ? 1 : 0,
        user_id: row[:sender_id],
        created_at: parse_datetime(row[:created_at]),
      )
    end

    # get pm topics
    csv_parse("Messages") do |row|
      next unless row[:thread_id] == row[:id]
      next unless row[:in_private_conversation] == "true"
      next if row[:deleted_at].present?
      # next if row[:message_type] == 'system'
      title = ""
      url = ""
      description = ""
      raw = row[:body]
      reg = /opengraphobject:\[(\d*?) : (.*?) : title="(.*?)" : description="(.*?)"\]/
      if row[:attachments]
        row[:attachments].match(reg) do
          url = Regexp.last_match(2)
          title = Regexp.last_match(3) if Regexp.last_match(3)
          description = Regexp.last_match(4)
          raw += "\n***\n#{description}\n#{url}\n" if raw.exclude?(url)
        end
        row[:attachments].match(/uploadedfile:(\d*)$/) do
          file_id = Regexp.last_match(1).to_i
          up = @db.fetch_upload(file_id).first
          path = File.join(@path, up["filename"])
          filename = up["original_filename"]
          user_id = user_id_from_imported_user_id(row["user_id"]) || Discourse.system_user.id
          if File.exist?(path)
            upload = create_upload(user_id, path, filename)
            raw += html_for_upload(upload, filename) if upload&.persisted?
          end
        end
      end
      @db.insert_pm_topic(
        id: row[:id],
        title: title,
        raw: raw,
        category_id: row[:group_id],
        closed: row[:closed] == "TRUE" ? 1 : 0,
        target_users: row[:participants].gsub("user:", ""),
        user_id: row[:sender_id],
        created_at: parse_datetime(row[:created_at]),
      )
    end

    # get posts from messages
    csv_parse("Messages") do |row|
      next if row[:thread_id] == row[:id]
      next if row[:deleted_at].present?
      next if row[:in_private_conversation] == "true"
      @db.insert_post(
        id: row[:id],
        raw: row[:body] + "\n" + row[:attachments],
        topic_id: row[:thread_id],
        reply_to_post_id: row[:replied_to_id],
        user_id: row[:sender_id],
        created_at: parse_datetime(row[:created_at]),
      )
    end

    # get pm posts from messages
    csv_parse("Messages") do |row|
      next if row[:thread_id] == row[:id]
      next if row[:deleted_at].present?
      next unless row[:in_private_conversation] == "false"
      @db.insert_pm_post(
        id: row[:id],
        raw: row[:body] + "\n" + row[:attachments],
        topic_id: row[:thread_id],
        reply_to_post_id: row[:replied_to_id],
        user_id: row[:sender_id],
        created_at: parse_datetime(row[:created_at]),
      )
    end

    #@db.delete_unused_users
    @db.sort_posts_by_created_at
  end

  def parse_datetime(text)
    return nil if text.blank? || text == "null"
    DateTime.parse(text)
  end

  def import_categories
    puts "", "creating categories"
    parent_category = nil
    if !PARENT_CATEGORY_NAME.blank?
      parent_category = Category.find_by(name: PARENT_CATEGORY_NAME)
      parent_category =
        Category.create(
          name: PARENT_CATEGORY_NAME,
          user_id: Discourse.system_user.id,
        ) unless parent_category
    end

    if IMPORT_GROUPS_AS_TAGS
      @tag_map = {}
      rows = @db.fetch_categories
      rows.each { |row| @tag_map[row["id"]] = row["name"] }
    else
      rows = @db.fetch_categories
      create_categories(rows) do |row|
        {
          id: row["id"],
          name: row["name"],
          description: row["description"],
          position: row["position"],
          parent_category_id: parent_category,
        }
      end
    end
  end

  def batches
    super(BATCH_SIZE)
  end

  def import_users
    puts "", "creating users"
    total_count = @db.count_users
    puts "", "Got #{total_count} users!"
    last_id = ""

    batches do |offset|
      rows, last_id = @db.fetch_users(last_id)
      break if rows.empty?

      next if all_records_exist?(:users, rows.map { |row| row["id"] })

      create_users(rows, total: total_count, offset: offset) do |row|
        user = User.find_by_email(row["email"].downcase)
        if user
          user.custom_fields["import_id"] = row["id"]
          user.custom_fields["matched_existing"] = "yes"
          user.save
          add_user(row["id"].to_s, user)
          next
        end
        {
          id: row["id"],
          email: row["email"],
          name: row["name"],
          created_at: row["created_at"],
          last_seen_at: row["last_seen_at"],
          active: row["active"] == 1,
        }
      end
    end
  end

  def import_topics
    puts "", "creating topics"
    staff_guardian = Guardian.new(Discourse.system_user)

    total_count = @db.count_topics
    last_id = ""

    batches do |offset|
      rows, last_id = @db.fetch_topics(last_id)
      base_category = Category.find_by(name: PARENT_CATEGORY_NAME)
      break if rows.empty?

      next if all_records_exist?(:posts, rows.map { |row| import_topic_id(row["id"]) })

      create_posts(rows, total: total_count, offset: offset) do |row|
        {
          id: import_topic_id(row["id"]),
          title:
            (
              if row["title"].present?
                row["title"]
              else
                row["raw"].split(/\W/)[0..(NUM_WORDS_IN_TITLE - 1)].join(" ")
              end
            ),
          raw: normalize_raw(row["raw"]),
          category:
            (
              if IMPORT_GROUPS_AS_TAGS
                base_category.id
              else
                category_id_from_imported_category_id(row["category_id"])
              end
            ),
          user_id: user_id_from_imported_user_id(row["user_id"]) || Discourse.system_user.id,
          created_at: row["created_at"],
          closed: row["closed"] == 1,
          post_create_action:
            proc do |post|
              if IMPORT_GROUPS_AS_TAGS
                topic = Topic.find(post.topic_id)
                tag_names = [@tag_map[row["category_id"]]]
                DiscourseTagging.tag_topic_by_names(topic, staff_guardian, tag_names)
              end
            end,
        }
      end
    end
  end

  def import_pm_topics
    puts "", "creating pm topics"
    staff_guardian = Guardian.new(Discourse.system_user)

    total_count = @db.count_pm_topics
    last_id = ""

    batches do |offset|
      rows, last_id = @db.fetch_pm_topics(last_id)
      base_category = Category.find_by(name: PARENT_CATEGORY_NAME)
      break if rows.empty?

      next if all_records_exist?(:posts, rows.map { |row| import_topic_id(row["id"]) })
      create_posts(rows, total: total_count, offset: offset) do |row|
        target_users = []
        row["target_users"]
          .split(",")
          .each do |u|
            user_id = user_id_from_imported_user_id(u)
            next unless user_id
            user = User.find(user_id)
            target_users.append(user.username)
          end
        target_usernames = target_users.join(",")
        {
          id: import_topic_id(row["id"]),
          title:
            (
              if row["title"].present?
                row["title"]
              else
                row["raw"].split(/\W/)[0..(NUM_WORDS_IN_TITLE - 1)].join(" ")
              end
            ),
          raw: normalize_raw(row["raw"]),
          category:
            (
              if IMPORT_GROUPS_AS_TAGS
                base_category.id
              else
                category_id_from_imported_category_id(row["category_id"])
              end
            ),
          user_id: user_id_from_imported_user_id(row["user_id"]) || Discourse.system_user.id,
          created_at: row["created_at"],
          closed: row["closed"] == 1,
          archetype: Archetype.private_message,
          target_usernames: target_usernames,
          post_create_action:
            proc do |post|
              if PM_TAG
                topic = Topic.find(post.topic_id)
                tag_names = [PM_TAG]
                DiscourseTagging.tag_topic_by_names(topic, staff_guardian, tag_names)
              end
            end,
        }
      end
    end
  end

  def import_topic_id(topic_id)
    "T#{topic_id}"
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
        topic = topic_lookup_from_imported_post_id(import_topic_id(row["topic_id"]))
        if topic.nil?
          p "MISSING TOPIC #{row["topic_id"]}"
          p row
          next
        end
        {
          id: row["id"],
          raw: normalize_raw(row["raw"]),
          user_id: user_id_from_imported_user_id(row["user_id"]) || Discourse.system_user.id,
          topic_id: topic[:topic_id],
          created_at: row["created_at"],
        }
      end
    end
  end

  def import_pm_posts
    puts "", "creating pm posts"
    total_count = @db.count_pm_posts
    last_row_id = 0

    batches do |offset|
      rows, last_row_id = @db.fetch_pm_posts(last_row_id)
      break if rows.empty?

      next if all_records_exist?(:posts, rows.map { |row| row["id"] })

      create_posts(rows, total: total_count, offset: offset) do |row|
        topic = topic_lookup_from_imported_post_id(import_topic_id(row["topic_id"]))

        if topic.nil?
          p "MISSING TOPIC #{row["topic_id"]}"
          p row
          next
        end

        {
          id: row["id"],
          raw: normalize_raw(row["raw"]),
          user_id: user_id_from_imported_user_id(row["user_id"]) || Discourse.system_user.id,
          topic_id: topic[:topic_id],
          created_at: row["created_at"],
        }
      end
    end
  end

  def normalize_raw(raw)
    return "<missing>" if raw.blank?

    raw = raw.gsub('\n', "")
    raw.gsub!(/\[\[user:(\d+)\]\]/) do
      u = Regexp.last_match(1)
      user_id = user_id_from_imported_user_id(u) || Discourse.system_user.id
      if user_id
        user = User.find(user_id)
        "@#{user.username}"
      else
        u
      end
    end
    raw
  end

  def permalink_exists?(url)
    Permalink.find_by(url: url)
  end

  def csv_parse(table_name)
    CSV.foreach(
      File.join(@path, "#{table_name}.csv"),
      headers: true,
      header_converters: :symbol,
      skip_blanks: true,
      encoding: "bom|utf-8",
    ) { |row| yield row }
  end
end

unless ARGV[0] && Dir.exist?(ARGV[0])
  puts "", "Usage:", "", "bundle exec ruby script/import_scripts/yammer.rb DIRNAME", ""
  exit 1
end

ImportScripts::Yammer.new(ARGV[0]).perform
