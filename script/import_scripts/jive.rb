# Jive importer
require 'nokogiri'
require 'csv'
require File.expand_path(File.dirname(__FILE__) + "/base.rb")

class ImportScripts::Jive < ImportScripts::Base

  BATCH_SIZE = 1000
  CATEGORY_IDS = [2023, 2003, 2004, 2042, 2036, 2029] # categories that should be imported

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
    import_groups
    import_group_members
    import_categories
    import_posts

    # Topic.update_all(closed: true)
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

    current_row = ""
    double_quote_count = 0

    File.open(filename).each_line do |line|

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

  def import_groups
    puts "", "importing groups..."

    rows = []
    csv_parse("groups") do |row|
      rows << { id: row.groupid, name: row.name }
    end

    create_groups(rows) do |row|
      row
    end
  end

  def import_users
    puts "", "creating users"

    count = 0
    users = []

    total = total_rows("users")

    csv_parse("users") do |row|

      id = row.userid

      email = "#{row.email}"

      # fake it
      if row.email.blank? || row.email !~ /@/
        email = SecureRandom.hex << "@domain.com"
      end

      name = "#{row.firstname} #{row.lastname}"
      username = row.username
      created_at = DateTime.parse(row.creationdate)
      last_seen_at = DateTime.parse(row.lastloggedin)
      is_activated = row.userenabled

      username = name if username == "NULL"
      username = email.split("@")[0] if username.blank?
      name = email.split("@")[0] if name.blank?

      users << {
        id: id,
        email: email,
        name: name,
        username: username,
        created_at: created_at,
        last_seen_at: last_seen_at,
        active: is_activated.to_i == 1,
        approved: true
      }

      count += 1
      if count % BATCH_SIZE == 0
        load_user_batch! users, count - users.length, total
      end

    end

    load_user_batch! users, count, total
  end

  def import_group_members
    puts "", "importing group members..."

    csv_parse("group_members") do |row|
      user_id = user_id_from_imported_user_id(row.userid)
      group_id = group_id_from_imported_group_id(row.groupid)

      if user_id && group_id
        GroupUser.find_or_create_by(user_id: user_id, group_id: group_id)
      end
    end
  end

  def import_categories
    rows = []

    csv_parse("communities") do |row|
      next unless CATEGORY_IDS.include?(row.communityid.to_i)
      rows << { id: row.communityid, name: "#{row.name} (#{row.communityid})" }
    end

    create_categories(rows) do |row|
      row
    end
  end

  def normalize_raw!(raw)
    raw = raw.dup
    raw = raw[5..-6]

    doc = Nokogiri::HTML.fragment(raw)
    doc.css('img').each do |img|
      img.remove if img['class'] == "jive-image"
    end

    raw = doc.to_html
    raw = raw[4..-1]

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
    thread_map = {}

    csv_parse("messages") do |thread|

      next unless CATEGORY_IDS.include?(thread.containerid.to_i)

      if !thread.parentmessageid
        # topic

        thread_map[thread.threadid] = thread.messageid

        #IMAGE UPLOADER
        if thread.imagecount
          Dir.foreach("/var/www/discourse/script/import_scripts/jive/img/#{thread.messageid}") do |item|
            next if item == ('.') || item == ('..') || item == ('.DS_Store')
            photo_path = "/var/www/discourse/script/import_scripts/jive/img/#{thread.messageid}/#{item}"
            upload = create_upload(thread.userid, photo_path, File.basename(photo_path))
               if upload.persisted?
                 puts "Image upload is successful for #{photo_path}, new path is #{upload.url}!"
                  thread.body.gsub!(item, upload.url)
               else
                 puts "Error: Image upload is not successful for #{photo_path}!"
               end
          end
        end

        #ATTACHMENT UPLOADER
        if thread.attachmentcount
          Dir.foreach("/var/www/discourse/script/import_scripts/jive/attach/#{thread.messageid}") do |item|
            next if item == ('.') || item == ('..') || item == ('.DS_Store')
            attach_path = "/var/www/discourse/script/import_scripts/jive/attach/#{thread.messageid}/#{item}"
            upload = create_upload(thread.userid, attach_path, File.basename(attach_path))
               if upload.persisted?
                 puts "Attachment upload is successful for #{attach_path}, new path is #{upload.url}!"
                  thread.body.gsub!(item, upload.url)
                  thread.body << "<br/><br/> #{attachment_html(upload, item)}"
               else
                 puts "Error: Attachment upload is not successful for #{attach_path}!"
               end
          end
        end

        topic_map[thread.messageid] = {
          id: thread.messageid,
          topic_id: thread.messageid,
          category_id: thread.containerid,
          user_id: thread.userid,
          title: thread.subject,
          body: normalize_raw!(thread.body || thread.subject || "<missing>"),
          created_at: DateTime.parse(thread.creationdate),
        }

      end
    end

    total = total_rows("messages")
    posts = []
    count = 0

    topic_map.each do |_, topic|
      posts << topic if topic[:body]
      count += 1
    end

    csv_parse("messages") do |thread|
      # post

      next unless CATEGORY_IDS.include?(thread.containerid.to_i)

      if thread.parentmessageid

        #IMAGE UPLOADER
        if thread.imagecount
          Dir.foreach("/var/www/discourse/script/import_scripts/jive/img/#{thread.messageid}") do |item|
            next if item == ('.') || item == ('..') || item == ('.DS_Store')
            photo_path = "/var/www/discourse/script/import_scripts/jive/img/#{thread.messageid}/#{item}"
            upload = create_upload(thread.userid, photo_path, File.basename(photo_path))
               if upload.persisted?
                 puts "Image upload is successful for #{photo_path}, new path is #{upload.url}!"
                  thread.body.gsub!(item, upload.url)
               else
                 puts "Error: Image upload is not successful for #{photo_path}!"
               end
          end
        end

        #ATTACHMENT UPLOADER
        if thread.attachmentcount
          Dir.foreach("/var/www/discourse/script/import_scripts/jive/attach/#{thread.messageid}") do |item|
            next if item == ('.') || item == ('..') || item == ('.DS_Store')
            attach_path = "/var/www/discourse/script/import_scripts/jive/attach/#{thread.messageid}/#{item}"
            upload = create_upload(thread.userid, attach_path, File.basename(attach_path))
               if upload.persisted?
                 puts "Attachment upload is successful for #{attach_path}, new path is #{upload.url}!"
                  thread.body.gsub!(item, upload.url)
                  thread.body << "<br/><br/> #{attachment_html(upload, item)}"
               else
                 puts "Error: Attachment upload is not successful for #{attach_path}!"
               end
          end
        end

        row = {
          id: thread.messageid,
          topic_id: thread_map["#{thread.threadid}"],
          user_id: thread.userid,
          title: thread.subject,
          body: normalize_raw!(thread.body),
          created_at: DateTime.parse(thread.creationdate)
        }
        posts << row
        count += 1

        if posts.length > 0 && posts.length % BATCH_SIZE == 0
          import_post_batch!(posts, topic_map, count - posts.length, total)
        end
      end
    end

    import_post_batch!(posts, topic_map, count - posts.length, total) if posts.length > 0
  end

end

unless ARGV[0] && Dir.exist?(ARGV[0])
  puts "", "Usage:", "", "bundle exec ruby script/import_scripts/jive.rb DIRNAME", ""
  exit 1
end

ImportScripts::Jive.new(ARGV[0]).perform
