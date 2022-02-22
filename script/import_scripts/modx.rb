# frozen_string_literal: true

require 'mysql2'
require File.expand_path(File.dirname(__FILE__) + "/base.rb")
require 'htmlentities'

class ImportScripts::Modx < ImportScripts::Base
  BATCH_SIZE = 1000

  # CHANGE THESE BEFORE RUNNING THE IMPORTER

  DB_HOST ||= ENV['DB_HOST'] || "localhost"
  DB_NAME ||= ENV['DB_NAME'] || "modx"
  DB_PW ||= ENV['DB_PW'] || "modex"
  DB_USER ||= ENV['DB_USER'] || "modx"
  TIMEZONE ||= ENV['TIMEZONE'] || "America/Los_Angeles"
  TABLE_PREFIX ||= ENV['TABLE_PREFIX'] || "modx_"
  ATTACHMENT_DIR ||= ENV['ATTACHMENT_DIR'] || '/path/to/your/attachment/folder'
  RANDOM_CATEGORY_COLOR ||= !ENV['RANDOM_CATEGORY_COLOR'].nil?
  SUSPEND_ALL_USERS ||= !ENV['SUSPEND_ALL_USERS']

  #   TODO: replace modx_ with #{TABLE_PREFIX}

  puts "#{DB_USER}:#{DB_PW}@#{DB_HOST} wants #{DB_NAME}"

  def initialize
    super

    SiteSetting.disable_emails = "non-staff"

    @old_username_to_new_usernames = {}

    @tz = TZInfo::Timezone.get(TIMEZONE)

    @htmlentities = HTMLEntities.new

    @client = Mysql2::Client.new(
      host: DB_HOST,
      username: DB_USER,
      password: DB_PW,
      database: DB_NAME
    )
  rescue Exception => e
    puts '=' * 50
    puts e.message
    puts <<EOM
Cannot connect in to database.

Hostname: #{DB_HOST}
Username: #{DB_USER}
Password: #{DB_PW}
database: #{DB_NAME}

Edit the script or set these environment variables:

export DB_HOST="localhost"
export DB_NAME="modx"
export DB_PW="modx"
export DB_USER="modx"
export TABLE_PREFIX="modx_"
export ATTACHMENT_DIR '/path/to/your/attachment/folder'

Exiting.
EOM
    exit
  end

  def execute
    import_users
    import_categories
    import_topics_and_posts
    deactivate_all_users
    suspend_users
  end

  def not_import_groups
    puts "", "importing groups..."

    groups = mysql_query <<-SQL
        SELECT usergroupid, title
          FROM #{TABLE_PREFIX}usergroup
      ORDER BY usergroupid
    SQL

    create_groups(groups) do |group|
      {
        id: group["usergroupid"],
        name: @htmlentities.decode(group["title"]).strip
      }
    end
  end

  def import_users
    puts "", "importing users"

    user_count = mysql_query("SELECT COUNT(id) count FROM #{TABLE_PREFIX}discuss_users").first["count"]

    last_user_id = -1

    batches(BATCH_SIZE) do |offset|
      users = mysql_query(<<-SQL
SELECT id as userid, email, concat (name_first, " ", name_last) as name, username,
location, website, status, last_active as last_seen_at,
createdon as created_at, birthdate as date_of_birth,
avatar as avatar_url,
password,
salt,
display_name,
use_display_name
FROM #{TABLE_PREFIX}discuss_users
           WHERE id > #{last_user_id}
        ORDER BY id
           LIMIT #{BATCH_SIZE};
      SQL
                         ).to_a

      break if users.empty?

      last_user_id = users[-1]["userid"]
      before = users.size
      users.reject! { |u| @lookup.user_already_imported?(u["userid"].to_i) }

      create_users(users, total: user_count, offset: offset) do |user|
        {
          id: user["userid"],
          name: user['name'],
          username: user['username'],
          email: user['email'],
          website: user['website'],
          created_at: parse_timestamp(user["created_at"]),
          last_seen_at: parse_timestamp(user["last_seen_at"]),
          date_of_birth: user['date_of_birth'],
          password: "#{user['password']}:#{user['salt']}" # not tested
        }
      end
    end
  end

  def import_categories
    # import modx_discuss_categories as categories
    # import modx_discuss_boards as subcategories
    puts "", "importing categories..."

    categories = mysql_query("select id, name, description from modx_discuss_categories").to_a

    create_categories(categories) do |category|
      puts "Creating #{category['name']}"
      puts category
      {
        id: "cat#{category['id']}",
        name: category["name"],
        color: RANDOM_CATEGORY_COLOR ? (0..2).map { "%0x" % (rand * 0x80) }.join : nil,
        description: category["description"]
      }
    end

    puts "", "importing boards as subcategories..."

    boards = mysql_query("select id, category, name, description from modx_discuss_boards;").to_a
    create_categories(boards) do |category|
      puts category
      parent_category_id = category_id_from_imported_category_id("cat#{category['category']}")
      {
        id: category["id"],
        parent_category_id: parent_category_id.to_s,
        name: category["name"],
        color: RANDOM_CATEGORY_COLOR ? (0..2).map { "%0x" % (rand * 0x80) }.join : nil,
        description: category["description"]
      }
    end
  end

  def import_topics_and_posts
    puts "", "creating topics and posts"

    total_count = mysql_query("SELECT count(id) count from #{TABLE_PREFIX}discuss_posts").first["count"]

    topic_first_post_id = {}

    batches(BATCH_SIZE) do |offset|
      results = mysql_query("
         SELECT id,
		thread topic_id,
                board category_id,
                title,
                message raw,
                parent,
                author user_id,
                createdon created_at
	        from modx_discuss_posts
       ORDER BY createdon
         LIMIT #{BATCH_SIZE}
        OFFSET #{offset};
      ")

      break if results.size < 1

      next if all_records_exist? :posts, results.map { |m| m['id'].to_i }

      create_posts(results, total: total_count, offset: offset) do |m|
        skip = false
        mapped = {}

        mapped[:id] = m['id']
        mapped[:user_id] = user_id_from_imported_user_id(m['user_id']) || -1
        mapped[:raw] = post_process_raw(m['raw'])
        mapped[:created_at] = Time.zone.at(m['created_at'])

        if m['parent'] == 0
          mapped[:category] = category_id_from_imported_category_id(m['category_id'])
          mapped[:title] = m['title']
          topic_first_post_id[m['topic_id']] = m['id']
        else
          parent = topic_lookup_from_imported_post_id(topic_first_post_id[m['topic_id']])
          if parent
            mapped[:topic_id] = parent[:topic_id]
          else
            puts "Parent post #{first_post_id} doesn't exist. Skipping #{m["id"]}: #{m["title"][0..40]}"
            skip = true
          end
        end

        skip ? nil : mapped
      end
    end
  end

  def post_process_raw(raw)
    # [QUOTE]...[/QUOTE]
    raw = raw.gsub(/\[quote.*?\](.+?)\[\/quote\]/im) { |quote|
      quote = quote.gsub(/\[quote author=(.*?) .+\]/i) { "\n[quote=\"#{$1}\"]\n" }
      quote = quote.gsub(/[^\n]\[\/quote\]/im) { "\n[/quote]\n" }
    }

    raw
  end

  def not_mark_topics_as_solved
    puts "", "Marking topics as solved..."

    DB.exec <<~SQL
      INSERT INTO topic_custom_fields (name, value, topic_id, created_at, updated_at)
      SELECT 'accepted_answer_post_id', pcf.post_id, p.topic_id, p.created_at, p.created_at
        FROM post_custom_fields pcf
        JOIN posts p ON p.id = pcf.post_id
       WHERE pcf.name = 'is_accepted_answer'
    SQL
  end

  # find the uploaded file information from the db
  def not_find_upload(post, attachment_id)
    sql = "SELECT a.attachmentid attachment_id, a.userid user_id, a.filedataid file_id, a.filename filename,
                  a.caption caption
             FROM #{TABLE_PREFIX}attachment a
            WHERE a.attachmentid = #{attachment_id}"
    results = mysql_query(sql)

    unless row = results.first
      puts "Couldn't find attachment record for post.id = #{post.id}, import_id = #{post.custom_fields['import_id']}"
      return
    end

    filename = File.join(ATTACHMENT_DIR, row['user_id'].to_s.split('').join('/'), "#{row['file_id']}.attach")
    unless File.exist?(filename)
      puts "Attachment file doesn't exist: #{filename}"
      return
    end

    real_filename = row['filename']
    real_filename.prepend SecureRandom.hex if real_filename[0] == '.'
    upload = create_upload(post.user.id, filename, real_filename)

    if upload.nil? || !upload.valid?
      puts "Upload not valid :("
      puts upload.errors.inspect if upload
      return
    end

    [upload, real_filename]
  rescue Mysql2::Error => e
    puts "SQL Error"
    puts e.message
    puts sql
  end

  def not_import_private_messages
    puts "", "importing private messages..."

    topic_count = mysql_query("SELECT COUNT(pmtextid) count FROM #{TABLE_PREFIX}pmtext").first["count"]

    last_private_message_id = -1

    batches(BATCH_SIZE) do |offset|
      private_messages = mysql_query(<<-SQL
          SELECT pmtextid, fromuserid, title, message, touserarray, dateline
            FROM #{TABLE_PREFIX}pmtext
           WHERE pmtextid > #{last_private_message_id}
        ORDER BY pmtextid
           LIMIT #{BATCH_SIZE}
      SQL
                                    ).to_a

      break if private_messages.empty?

      last_private_message_id = private_messages[-1]["pmtextid"]
      private_messages.reject! { |pm| @lookup.post_already_imported?("pm-#{pm['pmtextid']}") }

      title_username_of_pm_first_post = {}

      create_posts(private_messages, total: topic_count, offset: offset) do |m|
        skip = false
        mapped = {}

        mapped[:id] = "pm-#{m['pmtextid']}"
        mapped[:user_id] = user_id_from_imported_user_id(m['fromuserid']) || Discourse::SYSTEM_USER_ID
        mapped[:raw] = preprocess_post_raw(m['message']) rescue nil
        mapped[:created_at] = Time.zone.at(m['dateline'])
        title = @htmlentities.decode(m['title']).strip[0...255]
        topic_id = nil

        next if mapped[:raw].blank?

        # users who are part of this private message.
        target_usernames = []
        target_userids = []
        begin
          to_user_array = PHP.unserialize(m['touserarray'])
        rescue
          puts "#{m['pmtextid']} -- #{m['touserarray']}"
          skip = true
        end

        begin
          to_user_array.each do |to_user|
            if to_user[0] == "cc" || to_user[0] == "bcc" # not sure if we should include bcc users
              to_user[1].each do |to_user_cc|
                user_id = user_id_from_imported_user_id(to_user_cc[0])
                username = User.find_by(id: user_id).try(:username)
                target_userids << user_id || Discourse::SYSTEM_USER_ID
                target_usernames << username if username
              end
            else
              user_id = user_id_from_imported_user_id(to_user[0])
              username = User.find_by(id: user_id).try(:username)
              target_userids << user_id || Discourse::SYSTEM_USER_ID
              target_usernames << username if username
            end
          end
        rescue
          puts "skipping pm-#{m['pmtextid']} `to_user_array` is not properly serialized -- #{to_user_array.inspect}"
          skip = true
        end

        participants = target_userids
        participants << mapped[:user_id]
        begin
          participants.sort!
        rescue
          puts "one of the participant's id is nil -- #{participants.inspect}"
        end

        if title =~ /^Re:/

          parent_id = title_username_of_pm_first_post[[title[3..-1], participants]] ||
                      title_username_of_pm_first_post[[title[4..-1], participants]] ||
                      title_username_of_pm_first_post[[title[5..-1], participants]] ||
                      title_username_of_pm_first_post[[title[6..-1], participants]] ||
                      title_username_of_pm_first_post[[title[7..-1], participants]] ||
                      title_username_of_pm_first_post[[title[8..-1], participants]]

          if parent_id
            if t = topic_lookup_from_imported_post_id("pm-#{parent_id}")
              topic_id = t[:topic_id]
            end
          end
        else
          title_username_of_pm_first_post[[title, participants]] ||= m['pmtextid']
        end

        unless topic_id
          mapped[:title] = title
          mapped[:archetype] = Archetype.private_message
          mapped[:target_usernames] = target_usernames.join(',')

          if mapped[:target_usernames].size < 1 # pm with yourself?
            # skip = true
            mapped[:target_usernames] = "system"
            puts "pm-#{m['pmtextid']} has no target (#{m['touserarray']})"
          end
        else
          mapped[:topic_id] = topic_id
        end

        skip ? nil : mapped
      end
    end
  end

  def not_import_attachments
    puts '', 'importing attachments...'

    current_count = 0

    total_count = mysql_query(<<-SQL
      SELECT COUNT(postid) count
        FROM #{TABLE_PREFIX}post p
        JOIN #{TABLE_PREFIX}thread t ON t.threadid = p.threadid
       WHERE t.firstpostid <> p.postid
    SQL
                             ).first["count"]

    success_count = 0
    fail_count = 0

    attachment_regex = /\[attach[^\]]*\](\d+)\[\/attach\]/i

    Post.find_each do |post|
      current_count += 1
      print_status current_count, total_count

      new_raw = post.raw.dup
      new_raw.gsub!(attachment_regex) do |s|
        matches = attachment_regex.match(s)
        attachment_id = matches[1]

        upload, filename = find_upload(post, attachment_id)
        unless upload
          fail_count += 1
          next
        end

        html_for_upload(upload, filename)
      end

      if new_raw != post.raw
        PostRevisor.new(post).revise!(post.user, { raw: new_raw }, bypass_bump: true, edit_reason: 'Import attachments from modx')
      end

      success_count += 1
    end
  end

  def not_close_topics
    puts "", "Closing topics..."

    # keep track of closed topics
    closed_topic_ids = []

    topics = mysql_query <<-MYSQL
        SELECT t.threadid threadid, firstpostid, open
          FROM #{TABLE_PREFIX}thread t
          JOIN #{TABLE_PREFIX}post p ON p.postid = t.firstpostid
      ORDER BY t.threadid
    MYSQL
    topics.each do |topic|
      topic_id = "thread-#{topic["threadid"]}"
      closed_topic_ids << topic_id if topic["open"] == 0
    end

    sql = <<-SQL
      WITH closed_topic_ids AS (
        SELECT t.id AS topic_id
        FROM post_custom_fields pcf
        JOIN posts p ON p.id = pcf.post_id
        JOIN topics t ON t.id = p.topic_id
        WHERE pcf.name = 'import_id'
        AND pcf.value IN (?)
      )
      UPDATE topics
      SET closed = true
      WHERE id IN (SELECT topic_id FROM closed_topic_ids)
    SQL

    DB.exec(sql, closed_topic_ids)
  end

  def not_post_process_posts
    puts "", "Postprocessing posts..."

    current = 0
    max = Post.count

    Post.find_each do |post|
      begin
        new_raw = postprocess_post_raw(post.raw)
        if new_raw != post.raw
          post.raw = new_raw
          post.save
        end
      rescue PrettyText::JavaScriptError
        nil
      ensure
        print_status(current += 1, max)
      end
    end
  end

  def not_create_permalink_file
    puts '', 'Creating Permalink File...', ''

    id_mapping = []

    Topic.listable_topics.find_each do |topic|
      pcf = topic.first_post.custom_fields
      if pcf && pcf["import_id"]
        id = pcf["import_id"].split('-').last
        id_mapping.push("XXX#{id}  YYY#{topic.id}")
      end
    end

    # Category.find_each do |cat|
    #   ccf = cat.custom_fields
    #   if ccf && ccf["import_id"]
    #     id = ccf["import_id"].to_i
    #     id_mapping.push("/forumdisplay.php?#{id}  http://forum.quartertothree.com#{cat.url}")
    #   end
    # end

    CSV.open(File.expand_path("../vb_map.csv", __FILE__), "w") do |csv|
      id_mapping.each do |value|
        csv << [value]
      end
    end

  end

  def deactivate_all_users
    User.where("id > 0 and admin != true").update_all(active: true)
  end

  def suspend_users
    puts '', "updating blocked users"

    banned = 0
    failed = 0
    total = mysql_query("SELECT count(*) count FROM #{TABLE_PREFIX}user_attributes where blocked != 0").first['count']

    system_user = Discourse.system_user

    mysql_query("SELECT id, blockedafter, blockeduntil FROM #{TABLE_PREFIX}user_attributes").each do |b|
      user = User.find_by_id(user_id_from_imported_user_id(b['id']))
      if user
        user.suspended_at = parse_timestamp(user["blockedafter"])
        user.suspended_till = parse_timestamp(user["blockeduntil"])
        if user.save
          StaffActionLogger.new(system_user).log_user_suspend(user, "banned during initial import")
          banned += 1
        else
          puts "Failed to suspend user #{user.username}. #{user.errors.try(:full_messages).try(:inspect)}"
          failed += 1
        end
      else
        puts "Not found: #{b['userid']}"
        failed += 1
      end

      print_status banned + failed, total
    end
  end

  def parse_timestamp(timestamp)
    Time.zone.at(@tz.utc_to_local(timestamp))
  end

  def mysql_query(sql)
    @client.query(sql, cache_rows: true)
  end

end

ImportScripts::Modx.new.perform
