# frozen_string_literal: true

# getsatisfaction importer
#
# pre-req: You will either get an Excel or a bunch of CSV files. Be sure to rename them all so that
#
# - users.csv is the users table export
# - replies.csv is the reply table export
# - topics.csv is the topics table export
# - categories.csv is the categories table export
# - topics_categories.csv is the mapping between the topics and categories table
#
# Make sure that the CSV files use UTF-8 encoding, have consistent line endings and use comma as column separator.
# That's usually the case when you export Excel sheets as CSV.
# When you get MalformedCSVError during the import, try converting the line endings of the CSV into the Unix format.
# Mixed line endings in CSV files can create weird errors!
#
# You need to call fix_quotes_in_csv() for CSV files that use \" to escape quotes within quoted fields.
# The import script expects quotes to be escaped with "".
#
# It's likely that some posts in replies.csv aren't in the correct order. Currently the import script doesn't handle
# that correctly and will import the replies in the wrong order.
# You should run `rake posts:reorder_posts` after the import.

require 'csv'
require 'set'
require File.expand_path(File.dirname(__FILE__) + "/base.rb")
require 'reverse_markdown' # gem 'reverse_markdown'

# Call it like this:
#   RAILS_ENV=production bundle exec ruby script/import_scripts/getsatisfaction.rb DIRNAME
class ImportScripts::GetSatisfaction < ImportScripts::Base

  IMPORT_ARCHIVED_TOPICS = false

  # The script classifies each topic as private when at least one associated category
  # in "topics_categories.csv" is unknown (not included i "categories.csv").
  IMPORT_PRIVATE_TOPICS = false

  # Should the creation of permalinks be skipped? Make sure you configure OLD_DOMAIN if you
  CREATE_PERMALINKS = true

  # Replace "http://community.example.com/" with the URL of your community for permalinks
  OLD_DOMAIN = "http://community.example.com/"
  BATCH_SIZE = 1000

  def initialize(path)
    @path = path
    super()
    @bbcode_to_md = true
    @topic_slug = {}
    @topic_categories = {}
    @skipped_topics = Set.new
  end

  def execute
    # TODO Remove the call to fix_quotes_in_csv() if your replies.csv uses the double quotes ("").
    # That's usually the case when you exported the file from Excel.
    fix_quotes_in_csv("replies")

    import_users
    import_categories
    import_topics
    import_posts

    create_permalinks if CREATE_PERMALINKS
  end

  def csv_filename(table_name, use_fixed: true)
    if use_fixed
      filename = File.join(@path, "#{table_name}_fixed.csv")
      return filename if File.exists?(filename)
    end

    File.join(@path, "#{table_name}.csv")
  end

  def fix_quotes_in_csv(*table_names)
    puts "", "fixing CSV files"

    table_names.each do |table_name|
      source_filename = csv_filename(table_name, use_fixed: false)
      target_filename = csv_filename("#{table_name}_fixed", use_fixed: false)

      previous_line = nil

      File.open(target_filename, "w") do |file|
        File.open(source_filename).each_line do |line|
          line.gsub!(/(?<![^\\]\\)\\"/, '""')
          line.gsub!(/\\\\/, '\\')

          if previous_line
            previous_line << "\n" unless line.starts_with?(",")
            line = "#{previous_line}#{line}"
            previous_line = nil
          end

          if line.gsub!(/,\+1\\\R$/m, ',"+1"').present?
            previous_line = line
          else
            file.puts(line)
          end
        end

        file.puts(previous_line) if previous_line
      end
    end
  end

  def csv_parse(table_name)
    CSV.foreach(csv_filename(table_name),
                headers: true,
                header_converters: :symbol,
                skip_blanks: true,
                encoding: 'bom|utf-8') { |row| yield row }
  end

  def total_rows(table_name)
    CSV.foreach(csv_filename(table_name),
                headers: true,
                skip_blanks: true,
                encoding: 'bom|utf-8')
      .inject(0) { |c, _| c + 1 }
  end

  def import_users
    puts "", "creating users"

    count = 0
    users = []

    total = total_rows("users")

    csv_parse("users") do |row|
      users << {
        id: row[:user_id],
        email: row[:email],
        name: row[:realname],
        username: row[:nickname],
        created_at: DateTime.parse(row[:joined_date]),
        active: true
      }

      count += 1
      if count % BATCH_SIZE == 0
        import_users_batch!(users, count - users.length, total)
      end
    end

    import_users_batch!(users, count - users.length, total)
  end

  def import_users_batch!(users, offset, total)
    return if users.empty?

    create_users(users, offset: offset, total: total) do |user|
      user
    end
    users.clear
  end

  def import_categories
    puts "", "creating categories"

    rows = []

    csv_parse("categories") do |row|
      rows << {
        id: row[:category_id],
        name: row[:name],
        description: row[:description].present? ? normalize_raw!(row[:description]) : nil
      }
    end

    create_categories(rows) do |row|
      row
    end
  end

  def import_topic_id(topic_id)
    "T#{topic_id}"
  end

  def import_topics
    read_topic_categories

    puts "", "creating topics"

    count = 0
    topics = []

    total = total_rows("topics")

    csv_parse("topics") do |row|
      topic = nil
      topic_id = import_topic_id(row[:topic_id])

      if skip_topic?(row)
        @skipped_topics.add(topic_id)
      else
        topic = map_post(row)
        topic[:id] = topic_id
        topic[:title] = row[:subject].present? ? row[:subject].strip[0...255] : "Topic title missing"
        topic[:category] = category_id(row)
        topic[:archived] = row[:archived_at].present?

        @topic_slug[topic[:id]] = row[:url] if CREATE_PERMALINKS
      end

      topics << topic
      count += 1

      if count % BATCH_SIZE == 0
        import_topics_batch!(topics, count - topics.length, total)
      end
    end

    import_topics_batch!(topics, count - topics.length, total)
  end

  def skip_topic?(row)
    return true if row[:removed] == "1"
    return true unless IMPORT_ARCHIVED_TOPICS || row[:archived_at].blank?

    unless IMPORT_PRIVATE_TOPICS
      categories = @topic_categories[row[:topic_id]]
      return true if categories && categories[:has_unknown_category]
    end

    false
  end

  def category_id(row)
    categories = @topic_categories[row[:topic_id]]
    return categories[:category_ids].last if categories

    SiteSetting.uncategorized_category_id
  end

  def read_topic_categories
    puts "", "reading topic_categories"

    count = 0
    total = total_rows("topics_categories")

    csv_parse("topics_categories") do |row|
      topic_id = row[:topic_id]
      category_id = category_id_from_imported_category_id(row[:category_id])

      @topic_categories[topic_id] ||= { category_ids: [], has_unknown_category: false }

      if category_id.nil?
        @topic_categories[topic_id][:has_unknown_category] = true
      else
        @topic_categories[topic_id][:category_ids] << category_id
      end

      count += 1
      print_status(count, total)
    end
  end

  def import_topics_batch!(topics, offset, total)
    return if topics.empty?

    create_posts(topics, total: total, offset: offset) { |topic| topic }
    topics.clear
  end

  def import_posts
    puts "", "creating posts"

    count = 0
    posts = []

    total = total_rows("replies")

    csv_parse("replies") do |row|
      post = nil

      if row[:removed] != "1"
        parent = topic_lookup_from_imported_post_id(row[:parent_id]) if row[:parent_id] != "NULL"

        post = map_post(row)
        post[:id] = row[:reply_id]
        post[:topic_id] = import_topic_id(row[:topic_id])
        post[:reply_to_post_number] = parent[:post_number] if parent
      end

      posts << post
      count += 1

      if count % BATCH_SIZE == 0
        import_posts_batch!(posts, count - posts.length, total)
      end
    end

    import_posts_batch!(posts, count - posts.length, total)
  end

  def import_posts_batch!(posts, offset, total)
    return if posts.empty?

    create_posts(posts, total: total, offset: offset) do |post|
      next if post.nil? || @skipped_topics.include?(post[:topic_id])

      topic = topic_lookup_from_imported_post_id(post[:topic_id])

      if topic
        post[:topic_id] = topic[:topic_id]
      else
        p "MISSING TOPIC #{post[:topic_id]}"
        p post
        next
      end

      post
    end

    posts.clear
  end

  def map_post(row)
    {
      user_id: user_id_from_imported_user_id(row[:user_id]) || Discourse.system_user.id,
      created_at: DateTime.parse(row[:created_at]),
      raw: normalize_raw!(row[:formatted_content])
    }
  end

  def normalize_raw!(raw)
    return "<missing>" if raw.blank?
    raw = raw.dup

    # hoist code
    hoisted = {}
    raw.gsub!(/(<pre>\s*)?<code>(.*?)<\/code>(\s*<\/pre>)?/mi) do
      code = $2
      hoist = SecureRandom.hex
      # tidy code, wow, this is impressively crazy
      code.gsub!(/  (\s*)/, "\n\\1")
      code.gsub!(/^\s*\n$/, "\n")
      code.gsub!(/\n+/m, "\n")
      code.strip!
      hoisted[hoist] = code
      hoist
    end

    # impressive seems to be using tripple space as a <p> unless hoisted
    # in this case double space works best ... so odd
    raw.gsub!("   ", "\n\n")

    hoisted.each do |hoist, code|
      raw.gsub!(hoist, "\n```\n" << code << "\n```\n")
    end

    raw = CGI.unescapeHTML(raw)
    raw = ReverseMarkdown.convert(raw)
    raw
  end

  def create_permalinks
    puts '', 'Creating Permalinks...', ''

    Topic.listable_topics.find_each do |topic|
      tcf = topic.first_post.custom_fields
      if tcf && tcf["import_id"]
        slug = @topic_slug[tcf["import_id"]]
        slug = slug.gsub(OLD_DOMAIN, "")
        Permalink.create(url: slug, topic_id: topic.id)
      end
    end
  end

end

unless ARGV[0] && Dir.exist?(ARGV[0])
  puts "", "Usage:", "", "bundle exec ruby script/import_scripts/getsatisfaction.rb DIRNAME", ""
  exit 1
end

ImportScripts::GetSatisfaction.new(ARGV[0]).perform
