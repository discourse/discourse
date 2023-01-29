# frozen_string_literal: true

require "csv"
require File.expand_path(File.dirname(__FILE__) + "/base.rb")

# Edit the constants and initialize method for your import data.
# Make sure to follow the right format in your CSV files.

class ImportScripts::CsvImporter < ImportScripts::Base
  CSV_FILE_PATH = ENV["CSV_USER_FILE"] || "/var/www/discourse/tmp/users.csv"
  CSV_CUSTOM_FIELDS = ENV["CSV_CUSTOM_FIELDS"] || "/var/www/discourse/tmp/custom_fields.csv"
  CSV_EMAILS = ENV["CSV_EMAILS"] || "/var/www/discourse/tmp/emails.csv"
  CSV_CATEGORIES = ENV["CSV_CATEGORIES"] || "/var/www/discourse/tmp/categories.csv"
  CSV_TOPICS = ENV["CSV_TOPICS"] || "/var/www/discourse/tmp/topics_new_users.csv"
  CSV_TOPICS_EXISTING_USERS =
    ENV["CSV_TOPICS"] || "/var/www/discourse/tmp/topics_existing_users.csv"
  IMPORT_PREFIX = ENV["IMPORT_PREFIX"] || "2022-08-11"
  IMPORT_USER_ID_PREFIX = "csv-user-import-" + IMPORT_PREFIX + "-"
  IMPORT_CATEGORY_ID_PREFIX = "csv-category-import-" + IMPORT_PREFIX + "-"
  IMPORT_TOPIC_ID_PREFIX = "csv-topic-import-" + IMPORT_PREFIX + "-"
  IMPORT_TOPIC_ID_EXISITNG_PREFIX = "csv-topic_existing-import-" + IMPORT_PREFIX + "-"

  def initialize
    super

    @imported_users = load_csv(CSV_FILE_PATH)
    @imported_emails = load_csv(CSV_EMAILS)
    @imported_custom_fields = load_csv(CSV_CUSTOM_FIELDS)
    @imported_custom_fields_names = @imported_custom_fields.headers.drop(1)
    @imported_categories = load_csv(CSV_CATEGORIES)
    @imported_topics = load_csv(CSV_TOPICS)
    @imported_topics_existing_users = load_csv(CSV_TOPICS_EXISTING_USERS)
    @skip_updates = true
  end

  def execute
    puts "", "Importing from CSV file..."
    import_users
    import_categories
    import_topics
    import_topics_existing_users

    puts "", "Done"
  end

  def load_csv(path)
    unless File.exist?(path)
      puts "File doesn't exist: #{path}"
      return nil
    end

    CSV.parse(File.read(path, encoding: "bom|utf-8"), headers: true)
  end

  def username_for(name)
    result = name.downcase.gsub(/[^a-z0-9\-\_]/, "")
    result = Digest::SHA1.hexdigest(name)[0...10] if result.blank?

    result
  end

  def get_email(id)
    email = nil
    @imported_emails.each { |e| email = e["email"] if e["user_id"] == id }

    email
  end

  def get_custom_fields(id)
    custom_fields = {}
    @imported_custom_fields.each do |cf|
      if cf["user_id"] == id
        @imported_custom_fields_names.each { |name| custom_fields[name] = cf[name] }
      end
    end

    custom_fields
  end

  def import_users
    puts "", "Importing users"

    users = []
    @imported_users.each do |u|
      email = get_email(u["id"])
      custom_fields = get_custom_fields(u["id"])
      u["email"] = email
      u["custom_fields"] = custom_fields
      u["id"] = IMPORT_USER_ID_PREFIX + u["id"]
      users << u
    end
    users.uniq!

    create_users(users) do |u|
      {
        id: u["id"],
        username: u["username"],
        email: u["email"],
        created_at: u["created_at"],
        custom_fields: u["custom_fields"],
      }
    end
  end

  def import_categories
    puts "", "Importing categories"

    categories = []
    @imported_categories.each do |c|
      c["user_id"] = user_id_from_imported_user_id(IMPORT_USER_ID_PREFIX + c["user_id"]) ||
        Discourse::SYSTEM_USER_ID
      c["id"] = IMPORT_CATEGORY_ID_PREFIX + c["id"]
      categories << c
    end
    categories.uniq!

    create_categories(categories) do |c|
      { id: c["id"], user_id: c["user_id"], name: c["name"], description: c["description"] }
    end
  end

  def import_topics
    puts "", "Importing topics"

    topics = []
    @imported_topics.each do |t|
      t["user_id"] = user_id_from_imported_user_id(IMPORT_USER_ID_PREFIX + t["user_id"]) ||
        Discourse::SYSTEM_USER_ID
      t["category_id"] = category_id_from_imported_category_id(
        IMPORT_CATEGORY_ID_PREFIX + t["category_id"],
      )
      t["id"] = IMPORT_TOPIC_ID_PREFIX + t["id"]
      topics << t
    end

    create_posts(topics) do |t|
      {
        id: t["id"],
        user_id: t["user_id"],
        title: t["title"],
        category: t["category_id"],
        raw: t["raw"],
      }
    end
  end

  def import_topics_existing_users
    # Import topics for users that already existed in the DB, not imported during this migration
    puts "", "Importing topics for existing users"

    topics = []
    @imported_topics_existing_users.each do |t|
      t["id"] = IMPORT_TOPIC_ID_EXISITNG_PREFIX + t["id"]
      topics << t
    end

    create_posts(topics) do |t|
      {
        id: t["id"],
        user_id: t["user_id"], # This is a Discourse user ID
        title: t["title"],
        category: t["category_id"], # This is a Discourse category ID
        raw: t["raw"],
      }
    end
  end
end

ImportScripts::CsvImporter.new.perform if __FILE__ == $0

# == CSV files format
#
# + File name: users
#
#  headers: id,username
#
# + File name: emails
#
#  headers: user_id,email
#
# + File name: custom_fields
#
#  headers: user_id,user_field_1,user_field_2,user_field_3,user_field_4
#
#  note: the "user_field_1","user_field_2", .. headers are the names of the
#        custom fields, as defined in Discourse's user_custom_fields table.
#
# + File name: categories
#
#  headers: id,user_id,name,description
#
# + File name: topics_new_users
#
#  headers: id,user_id,title,category_id,raw
#
# + File name: topics_existing_users
#
#  headers: id,user_id,title,category_id,raw
#
# == Important: except for the topics_existing_users, the IDs in the data can be anything
#            as long as they are consistent among the files.
#
