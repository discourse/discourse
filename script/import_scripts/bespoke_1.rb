# frozen_string_literal: true

# bespoke importer for a customer, feel free to borrow ideas

require 'csv'
require File.expand_path(File.dirname(__FILE__) + "/base.rb")

# Call it like this:
#   RAILS_ENV=production bundle exec ruby script/import_scripts/bespoke_1.rb
class ImportScripts::Bespoke < ImportScripts::Base

  BATCH_SIZE = 1000

  def initialize(path)
    @path = path
    super()
    @bbcode_to_md = true

    puts "loading post mappings..."
    @post_number_map = {}
    Post.pluck(:id, :post_number).each do |post_id, post_number|
      @post_number_map[post_id] = post_number
    end
  end

  def created_post(post)
    @post_number_map[post.id] = post.post_number
    super
  end

  def execute
    import_users
    import_categories
    import_posts

  end

  class RowResolver
    def load(row)
      @row = row
    end

    def self.create(cols)
      Class.new(RowResolver).new(cols)
    end

    def initialize(cols)
      cols.each_with_index do |col, idx|
        self.class.public_send(:define_method, col) do
          @row[idx]
        end
      end
    end
  end

  def load_user_batch!(users, offset, total)
    if users.length > 0
      create_users(users, offset: offset, total: total) do |user|
        user
      end
      users.clear
    end
  end

  def csv_parse(name)
    filename = "#{@path}/#{name}.csv"
    first = true
    row = nil

    current_row = +""
    double_quote_count = 0

    File.open(filename).each_line do |line|

      # escaping is mental here
      line.gsub!(/\\(.{1})/) { |m| m[-1] == '"' ? '""' : m[-1] }
      line.strip!

      current_row << "\n" unless current_row.empty?
      current_row << line

      double_quote_count += line.scan('"').count

      if double_quote_count % 2 == 1
        next
      end

      raw = begin
              CSV.parse(current_row)
            rescue CSV::MalformedCSVError => e
              puts e.message
              puts "*" * 100
              puts "Bad row skipped, line is: #{line}"
              puts
              puts current_row
              puts
              puts "double quote count is : #{double_quote_count}"
              puts "*" * 100

              current_row = ""
              double_quote_count = 0
              next
            end[0]

      if first
        row = RowResolver.create(raw)

        current_row = ""
        double_quote_count = 0
        first = false
        next
      end

      row.load(raw)

      yield row

      current_row = ""
      double_quote_count = 0
    end
  end

  def total_rows(table)
    File.foreach("#{@path}/#{table}.csv").inject(0) { |c, line| c + 1 } - 1
  end

  def import_users
    puts "", "creating users"

    count = 0
    users = []

    total = total_rows("users")

    csv_parse("users") do |row|

      id = row.id
      email = row.email

      # fake it
      if row.email.blank? || row.email !~ /@/
        email = fake_email
      end

      name = row.display_name
      username = row.key_custom
      created_at = DateTime.parse(row.dcreate)

      username = name if username == "NULL"
      username = email.split("@")[0] if username.blank?
      name = email.split("@")[0] if name.blank?

      users << {
        id: id,
        email: email,
        name: name,
        username: username,
        created_at: created_at
      }

      count += 1
      if count % BATCH_SIZE == 0
        load_user_batch! users, count - users.length, total
      end

    end

    load_user_batch! users, count, total
  end

  def import_categories
    rows = []
    csv_parse("categories") do |row|
      rows << { id: row.id, name: row.name, description: row.description }
    end

    create_categories(rows) do |row|
      row
    end
  end

  def normalize_raw!(raw)
    # purple and #1223f3
    raw.gsub!(/\[color=[#a-z0-9]+\]/i, "")
    raw.gsub!(/\[\/color\]/i, "")
    raw.gsub!(/\[signature\].+\[\/signature\]/im, "")
    raw
  end

  def import_post_batch!(posts, topics, offset, total)
    create_posts(posts, total: total, offset: offset) do |post|

      mapped = {}

      mapped[:id] = post[:id]
      mapped[:user_id] = user_id_from_imported_user_id(post[:user_id]) || -1
      mapped[:raw] = post[:body]
      mapped[:created_at] = post[:created_at]

      topic = topics[post[:topic_id]]

      unless topic[:post_id]
        mapped[:category] = category_id_from_imported_category_id(topic[:category_id])
        mapped[:title] = post[:title]
        topic[:post_id] = post[:id]
      else
        parent = topic_lookup_from_imported_post_id(topic[:post_id])
        next unless parent

        mapped[:topic_id] = parent[:topic_id]

        reply_to_post_id = post_id_from_imported_post_id(post[:reply_id])
        if reply_to_post_id
          reply_to_post_number = @post_number_map[reply_to_post_id]
          if reply_to_post_number && reply_to_post_number > 1
            mapped[:reply_to_post_number] = reply_to_post_number
          end
        end
      end

      next if topic[:deleted] || post[:deleted]

      mapped
    end

      posts.clear
  end

  def import_posts
    puts "", "creating topics and posts"

    topic_map = {}

    csv_parse("topics") do |topic|
      topic_map[topic.id] = {
        id: topic.id,
        category_id: topic.forum_category_id,
        deleted: topic.is_deleted.to_i == 1,
        locked: topic.is_locked.to_i == 1,
        pinned: topic.is_pinned.to_i == 1
      }
    end

    total = total_rows("posts")

    posts = []
    count = 0
    csv_parse("posts") do |row|

      unless row.dcreate
        puts "NO CREATION DATE FOR POST"
        p row
        next
      end

      row = {
        id: row.id,
        topic_id: row.forum_topic_id,
        reply_id: row.reply_id,
        user_id: row.user_id,
        title: row.title,
        body: normalize_raw!(row.body),
        deleted: row.is_deleted.to_i == 1,
        created_at: DateTime.parse(row.dcreate)
      }
      posts << row
      count += 1

      if posts.length > 0 && posts.length % BATCH_SIZE == 0
        import_post_batch!(posts, topic_map, count - posts.length, total)
      end
    end

    import_post_batch!(posts, topic_map, count - posts.length, total) if posts.length > 0

    exit
  end

end

unless ARGV[0] && Dir.exist?(ARGV[0])
  puts "", "Usage:", "", "bundle exec ruby script/import_scripts/bespoke_1.rb DIRNAME", ""
  exit 1
end

ImportScripts::Bespoke.new(ARGV[0]).perform
