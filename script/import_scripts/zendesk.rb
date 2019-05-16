# frozen_string_literal: true

# Zendesk importer
#
# You will need a bunch of CSV files:
#
# - users.csv
# - topics.csv (topics in Zendesk are categories in Discourse)
# - posts.csv (posts in Zendesk are topics in Discourse)
# - comments.csv (comments in Zendesk are posts in Discourse)

require 'csv'
require 'reverse_markdown'
require_relative 'base'
require_relative 'base/generic_database'

# Call it like this:
#   RAILS_ENV=production bundle exec ruby script/import_scripts/zendesk.rb DIRNAME
class ImportScripts::Zendesk < ImportScripts::Base
  OLD_DOMAIN = "https://support.example.com"
  BATCH_SIZE = 1000

  def initialize(path)
    super()

    @path = path
    @db = ImportScripts::GenericDatabase.new(@path, batch_size: BATCH_SIZE, recreate: true)
  end

  def execute
    read_csv_files

    import_categories
    import_users
    import_topics
    import_posts
  end

  def read_csv_files
    puts "", "reading CSV files"

    csv_parse("topics") do |row|
      @db.insert_category(
        id: row[:id],
        name: row[:name],
        description: row[:description],
        position: row[:position],
        url: row[:htmlurl]
      )
    end

    csv_parse("users") do |row|
      @db.insert_user(
        id: row[:id],
        email: row[:email],
        name: row[:name],
        created_at: parse_datetime(row[:createdat]),
        last_seen_at: parse_datetime(row[:lastloginat]),
        active: true
      )
    end

    csv_parse("posts") do |row|
      @db.insert_topic(
        id: row[:id],
        title: row[:title],
        raw: row[:details],
        category_id: row[:topicid],
        closed: row[:closed] == "TRUE",
        user_id: row[:authorid],
        created_at: parse_datetime(row[:createdat]),
        url: row[:htmlurl]
      )
    end

    csv_parse("comments") do |row|
      @db.insert_post(
        id: row[:id],
        raw: row[:body],
        topic_id: row[:postid],
        user_id: row[:authorid],
        created_at: parse_datetime(row[:createdat]),
        url: row[:htmlurl]
      )
    end

    @db.delete_unused_users
    @db.sort_posts_by_created_at
  end

  def parse_datetime(text)
    return nil if text.blank? || text == "null"
    DateTime.parse(text)
  end

  def import_categories
    puts "", "creating categories"
    rows = @db.fetch_categories

    create_categories(rows) do |row|
      {
        id: row['id'],
        name: row['name'],
        description: row['description'],
        position: row['position'],
        post_create_action: proc do |category|
          url = remove_domain(row['url'])
          Permalink.create(url: url, category_id: category.id) unless permalink_exists?(url)
        end
      }
    end
  end

  def batches
    super(BATCH_SIZE)
  end

  def import_users
    puts "", "creating users"
    total_count = @db.count_users
    last_id = ''

    batches do |offset|
      rows, last_id = @db.fetch_users(last_id)
      break if rows.empty?

      next if all_records_exist?(:users, rows.map { |row| row['id'] })

      create_users(rows, total: total_count, offset: offset) do |row|
        {
          id: row['id'],
          email: row['email'],
          name: row['name'],
          created_at: row['created_at'],
          last_seen_at: row['last_seen_at'],
          active: row['active'] == 1
        }
      end
    end
  end

  def import_topics
    puts "", "creating topics"
    total_count = @db.count_topics
    last_id = ''

    batches do |offset|
      rows, last_id = @db.fetch_topics(last_id)
      break if rows.empty?

      next if all_records_exist?(:posts, rows.map { |row| import_topic_id(row['id']) })

      create_posts(rows, total: total_count, offset: offset) do |row|
        {
          id: import_topic_id(row['id']),
          title: row['title'].present? ? row['title'].strip[0...255] : "Topic title missing",
          raw: normalize_raw(row['raw']),
          category: category_id_from_imported_category_id(row['category_id']),
          user_id: user_id_from_imported_user_id(row['user_id']) || Discourse.system_user.id,
          created_at: row['created_at'],
          closed: row['closed'] == 1,
          post_create_action: proc do |post|
            url = remove_domain(row['url'])
            Permalink.create(url: url, topic_id: post.topic.id) unless permalink_exists?(url)
          end
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

      next if all_records_exist?(:posts, rows.map { |row| row['id'] })

      create_posts(rows, total: total_count, offset: offset) do |row|
        topic = topic_lookup_from_imported_post_id(import_topic_id(row['topic_id']))

        if topic.nil?
          p "MISSING TOPIC #{row['topic_id']}"
          p row
          next
        end

        {
          id: row['id'],
          raw: normalize_raw(row['raw']),
          user_id: user_id_from_imported_user_id(row['user_id']) || Discourse.system_user.id,
          topic_id: topic[:topic_id],
          created_at: row['created_at'],
          post_create_action: proc do |post|
            url = remove_domain(row['url'])
            Permalink.create(url: url, post_id: post.id) unless permalink_exists?(url)
          end
        }
      end
    end
  end

  def normalize_raw(raw)
    raw = raw.gsub('\n', '')
    raw = ReverseMarkdown.convert(raw)
    raw
  end

  def remove_domain(url)
    url.sub(OLD_DOMAIN, "")
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
  puts "", "Usage:", "", "bundle exec ruby script/import_scripts/zendesk.rb DIRNAME", ""
  exit 1
end

ImportScripts::Zendesk.new(ARGV[0]).perform
