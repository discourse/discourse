# getsatisfaction importer
#
# pre-req: you will get a bunch of CSV files, be sure to rename them all so
#
# - users.csv is the users table export (it may come from getsatisfaction as Users-Table 1.csv
# - replies.csv is the reply table export
# - topics.csv is the topics table export
#
#
# note, the importer will import all topics into a new category called 'Old Forum' and close all the topics
#
require 'csv'
require File.expand_path(File.dirname(__FILE__) + "/base.rb")

# Call it like this:
#   RAILS_ENV=production bundle exec ruby script/import_scripts/getsatisfaction.rb
class ImportScripts::GetSatisfaction < ImportScripts::Base

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
    c = Category.find_by(name: 'Old Forum') ||
      Category.create!(name: 'Old Forum', user: Discourse.system_user)

    import_users
    import_posts(c)

    Topic.where(category: c).update_all(closed: true)
  end

  class RowResolver
    def load(row)
      @row = row
    end

    def self.create(cols)
      Class.new(RowResolver).new(cols)
    end

    def initialize(cols)
      cols.each_with_index do |col,idx|
        self.class.send(:define_method, col) do
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

    current_row = "";
    double_quote_count = 0

    File.open(filename).each_line do |line|

      line.strip!

      current_row << "\n" unless current_row.empty?
      current_row << line

      raw = begin
              CSV.parse(current_row, col_sep: ";")
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
    File.foreach("#{@path}/#{table}.csv").inject(0) {|c, line| c+1} - 1
  end

  def import_users
    puts "", "creating users"

    count = 0
    users = []

    total = total_rows("users")

    csv_parse("users") do |row|

      if row.suspended_at
        puts "skipping suspended user"
        p row
        next
      end

      id = row.user_id
      email = row.email

      # fake it
      if row.email.blank? || row.email !~ /@/
        email = SecureRandom.hex << "@domain.com"
      end

      name = row.real_name
      username = row.nick
      created_at = DateTime.parse(row.m_created)

      username = name if username == "NULL"
      username = email.split("@")[0] if username.blank?
      name = email.split("@")[0] if name.blank?

      users << {
        id: id,
        email: email,
        name: name,
        username: username,
        created_at: created_at,
        active: false
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
      rows << {id: row.id, name: row.name, description: row.description}
    end

    create_categories(rows) do |row|
      row
    end
  end

  def normalize_raw!(raw)
    raw = raw.dup

    # hoist code
    hoisted = {}
    raw.gsub!(/(<pre>\s*)?<code>(.*?)<\/code>(\s*<\/pre>)?/mi) do
      code = $2
      hoist = SecureRandom.hex
      # tidy code, wow, this is impressively crazy
      code.gsub!(/  (\s*)/,"\n\\1")
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

        unless topic
          p "MISSING TOPIC #{post[:topic_id]}"
          p post
          next
        end


        unless topic[:post_id]
          mapped[:title] = post[:title] || "Topic title missing"
          topic[:post_id] = post[:id]
          mapped[:category] = post[:category]
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

        next if topic[:deleted] or post[:deleted]

        mapped
      end

      posts.clear
  end

  def import_posts(category)
    puts "", "creating topics and posts"

    topic_map = {}

    csv_parse("topics") do |topic|
      topic_map[topic.id] = {
        id: topic.id,
        topic_id: topic.id,
        title: topic.subject,
        deleted: topic.removed == "1",
        closed: true,
        body: normalize_raw!(topic.additional_detail || topic.subject || "<missing>"),
        created_at: DateTime.parse(topic.created_at),
        user_id: topic.UserId,
        category: category.name
      }
    end

    total = total_rows("replies")

    posts = []
    count = 0

    topic_map.each do |_, topic|
      # a bit lazy
      posts << topic if topic[:body]
    end

    csv_parse("replies") do |row|

      unless row.created_at
        puts "NO CREATION DATE FOR POST"
        p row
        next
      end

      row = {
        id: row.id,
        topic_id: row.topic_id,
        reply_id: row.parent_id,
        user_id: row.UserId,
        body: normalize_raw!(row.content),
        created_at: DateTime.parse(row.created_at)
      }
      posts << row
      count+=1

      if posts.length > 0 && posts.length % BATCH_SIZE == 0
        import_post_batch!(posts, topic_map, count - posts.length, total)
      end
    end

    import_post_batch!(posts, topic_map, count - posts.length, total) if posts.length > 0
  end


end

unless ARGV[0] && Dir.exist?(ARGV[0])
  puts "", "Usage:", "", "bundle exec ruby script/import_scripts/getsatisfaction.rb DIRNAME", ""
  exit 1
end

ImportScripts::GetSatisfaction.new(ARGV[0]).perform
