# Import from Influitive.

require 'csv'
require File.expand_path(File.dirname(__FILE__) + "/base.rb")
require File.expand_path(File.dirname(__FILE__) + "/base/csv_helper.rb")

# Call it like this:
#   bundle exec ruby script/import_scripts/influitive.rb <path-to-csv-files>
class ImportScripts::Influitive < ImportScripts::Base

  include ImportScripts::CsvHelper

  BATCH_SIZE = 1000

  def initialize(path)
    @path = path
    @all_posts = []
    @categories = {} # key is the parent category, value is an array of sub-categories
    @topic_mapping = {}
    @current_row = nil
    super()
  end

  def execute
    import_users
    import_categories
    import_topics
    import_posts
    update_tl0
  end

  def import_users
    puts "", "Importing users"
    create_categories(CSV.parse(File.read(File.join(@path, 'contacts.csv')), headers: true)) do |u|
      {
        id: u['id'],
        email: u['email'],
        name: u['name'],
        created_at: u['created_at'],
        updated_at: u['updated_at'],
        admin: u['is_admin'] == 't',
        moderator: u['is_moderator'] == 't',
        title: u['title']
      }
    end
  end

  def import_categories
    puts "", "Importing categories"
    create_categories(CSV.parse(File.read(File.join(@path, 'forums.csv')),headers: true)) do |c|
      # id name forum_type active created_at updated_at company_id
      # hub_forum_id description is_public archived targeted_users
      # group_id uuid deleted_at group_uuid experience_id
      # experience_group_uuid
      {
        id: c['id'],
        name: c['name'],
        slug: c['forum_type'],
        description: c['description'],
        created_at: c['created_at']
      }
    end
  end

  def import_topics
    created = 0
    skipped = 0
    puts "", "Importing topics"

    topics = (CSV.parse(File.read(File.join(@path, 'topics.csv')), headers: true))

    created, skipped = create_posts(topics, total: topics.size) do |row|
      @current_row = row

      # id title body created_at updated_at author_id replies_count
      # likes_count forum_id topic_type hidden edited_at editor_id
      # last_activity sticky locked related_topic_id uuid

      user_id = user_id_from_imported_user_id(row['author_id']) || Discourse::SYSTEM_USER_ID
      editor_id = user_id_from_imported_user_id(row['editor_id'])
      category_id = category_id_from_imported_category_id(row['forum_id'])
      if !category_id
        puts "Skipping #{row['id']}, no category #{row['forum_id']}"
        next
      end
      {
        id: row['id'],
        user_id: user_id,
        category: category_id,
        title: row['title'],
        raw: row['body'],
        created_at: row['created_at'],
        updated_at: row['updated_at'],
        like_count: row['likes_count'],
        hidden: row['hidden'] == 't',
        hidden_at: row['edited_at'],
        pinned_until: sticky == 't' ? Time.now + 200.years : nil,
        locked_by_id: editor_id
      }
    end

    puts ""
    puts "Created: #{created}"
    puts "Skipped: #{skipped}"
    puts ""
  end

  def import_posts
    created = 0
    skipped = 0
    puts "", "Importing topics"

    topics = (CSV.parse(File.read(File.join(@path, 'replies.csv')), headers: true))

    created, skipped = create_posts(topics, total: topics.size) do |row|
      @current_row = row

      # id title body created_at updated_at author_id replies_count
      # likes_count forum_id topic_type hidden edited_at editor_id
      # last_activity sticky locked related_topic_id uuid

      user_id = user_id_from_imported_user_id(row['author_id']) || Discourse::SYSTEM_USER_ID
      editor_id = user_id_from_imported_user_id(row['editor_id'])
      topic = topic_lookup_from_imported_post_id(row['topic_id']
      if !topic_id
        puts "Skipping #{row['id']}, no topic #{row['topic_id']}"
        next
      end
      topic_id = topic[topic_id]
      if parent = topic_lookup_from_imported_post_id(row["reply_to_id"])
        reply_to_post_number = parent[:post_number]
      end
      {
        id: row['id'],
        topic_id: topic_id,
        user_id: user_id,
        raw: row['body'],
        created_at: row['created_at'],
        updated_at: row['updated_at'],
        like_count: row['likes_count'],
        hidden: row['hidden'] == 't',
        hidden_at: row['edited_at'],
        locked_by_id: editor_id,
        reply_to_post_number: reply_to_post_number
      }
    end

    puts ""
    puts "Created: #{created}"
    puts "Skipped: #{skipped}"
    puts ""
  end

  def cleanup_post(raw)
    raw
  end

end

unless ARGV[0] && Dir.exist?(ARGV[0])
  if ARGV[0] && !Dir.exist?(ARGV[0])
    puts "", "ERROR! Dir #{ARGV[0]} not found.", ""
  end

  puts "", "Usage:", "", "    bundle exec ruby script/import_scripts/influitive.rb DIRNAME", ""
  exit 1
end

ImportScripts::Influitive.new(ARGV[0]).perform
