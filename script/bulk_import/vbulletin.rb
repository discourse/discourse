# frozen_string_literal: true

require_relative "base"
require "mysql2"
require "htmlentities"
require "parallel"

class BulkImport::VBulletin < BulkImport::Base
  TABLE_PREFIX = ENV["TABLE_PREFIX"] || "vb_"
  SUSPENDED_TILL = Date.new(3000, 1, 1)
  ATTACHMENT_DIR = ENV["ATTACHMENT_DIR"] || "/shared/import/data/attachments"
  AVATAR_DIR = ENV["AVATAR_DIR"] || "/shared/import/data/customavatars"

  def initialize
    super

    host = ENV["DB_HOST"] || "localhost"
    username = ENV["DB_USERNAME"] || "root"
    password = ENV["DB_PASSWORD"]
    database = ENV["DB_NAME"] || "vbulletin"
    charset = ENV["DB_CHARSET"] || "utf8"

    @html_entities = HTMLEntities.new
    @encoding = CHARSET_MAP[charset]

    @client =
      Mysql2::Client.new(
        host: host,
        username: username,
        password: password,
        database: database,
        encoding: charset,
        reconnect: true,
      )

    @client.query_options.merge!(as: :array, cache_rows: false)

    @has_post_thanks = mysql_query(<<-SQL).to_a.count > 0
        SELECT `COLUMN_NAME`
          FROM `INFORMATION_SCHEMA`.`COLUMNS`
         WHERE `TABLE_SCHEMA`='#{database}'
           AND `TABLE_NAME`='user'
           AND `COLUMN_NAME` LIKE 'post_thanks_%'
    SQL

    @user_ids_by_email = {}
  end

  def execute
    # enable as per requirement:
    # SiteSetting.automatic_backups_enabled = false
    # SiteSetting.disable_emails = "non-staff"
    # SiteSetting.authorized_extensions = '*'
    # SiteSetting.max_image_size_kb = 102400
    # SiteSetting.max_attachment_size_kb = 102400
    # SiteSetting.clean_up_uploads = false
    # SiteSetting.clean_orphan_uploads_grace_period_hours = 43200

    import_groups
    import_users
    import_group_users

    import_user_emails
    import_user_stats

    import_user_passwords
    import_user_salts
    import_user_profiles

    import_categories
    import_topics
    import_posts

    import_likes

    import_private_topics
    import_topic_allowed_users
    import_private_posts

    create_permalink_file
    import_attachments
    import_avatars
    import_signatures
  end

  def execute_after
    max_age = SiteSetting.delete_user_max_post_age
    SiteSetting.delete_user_max_post_age = 50 * 365

    merge_duplicated_users

    SiteSetting.delete_user_max_post_age = max_age
  end

  def import_groups
    puts "", "Importing groups..."

    groups = mysql_stream <<-SQL
        SELECT usergroupid, title, description, usertitle
          FROM #{TABLE_PREFIX}usergroup
         WHERE usergroupid > #{@last_imported_group_id}
      ORDER BY usergroupid
    SQL

    create_groups(groups) do |row|
      {
        imported_id: row[0],
        name: normalize_text(row[1]),
        bio_raw: normalize_text(row[2]),
        title: normalize_text(row[3]),
      }
    end
  end

  def import_users
    puts "", "Importing users..."

    users = mysql_stream <<-SQL
        SELECT u.userid, username, email, joindate, birthday, ipaddress, u.usergroupid, bandate, liftdate
          FROM #{TABLE_PREFIX}user u
     LEFT JOIN #{TABLE_PREFIX}userban ub ON ub.userid = u.userid
         WHERE u.userid > #{@last_imported_user_id}
      ORDER BY u.userid
    SQL

    create_users(users) do |row|
      u = {
        imported_id: row[0],
        username: normalize_text(row[1]),
        name: normalize_text(row[1]),
        email: row[2],
        created_at: Time.zone.at(row[3]),
        date_of_birth: parse_birthday(row[4]),
        primary_group_id: group_id_from_imported_id(row[6]),
      }
      u[:ip_address] = row[5][/\b(?:\d{1,3}\.){3}\d{1,3}\b/] if row[5].present?
      if row[7]
        u[:suspended_at] = Time.zone.at(row[7])
        u[:suspended_till] = row[8] > 0 ? Time.zone.at(row[8]) : SUSPENDED_TILL
      end
      u
    end
  end

  def import_user_emails
    puts "", "Importing user emails..."

    users = mysql_stream <<-SQL
        SELECT u.userid, email, joindate
          FROM #{TABLE_PREFIX}user u
         WHERE u.userid > #{@last_imported_user_id}
      ORDER BY u.userid
    SQL

    create_user_emails(users) do |row|
      user_id, email = row[0..1]

      @user_ids_by_email[email.downcase] ||= []
      user_ids = @user_ids_by_email[email.downcase] << user_id

      if user_ids.count > 1
        # fudge email to avoid conflicts; accounts from the 2nd and on will later be merged back into the first
        # NOTE: gsub! is used to avoid creating a new (frozen) string
        email.gsub!(/^/, SecureRandom.hex)
      end

      {
        imported_id: user_id,
        imported_user_id: user_id,
        email: email,
        created_at: Time.zone.at(row[2]),
      }
    end

    # for debugging purposes; not used operationally
    save_duplicated_users
  end

  def import_user_stats
    puts "", "Importing user stats..."

    users = mysql_stream <<-SQL
              SELECT u.userid, joindate, posts, COUNT(t.threadid) AS threads, p.dateline
                     #{", post_thanks_user_amount, post_thanks_thanked_times" if @has_post_thanks}
                FROM #{TABLE_PREFIX}user u
     LEFT OUTER JOIN #{TABLE_PREFIX}post p ON p.postid = u.lastpostid
     LEFT OUTER JOIN #{TABLE_PREFIX}thread t ON u.userid = t.postuserid
               WHERE u.userid > #{@last_imported_user_id}
            GROUP BY u.userid
            ORDER BY u.userid
    SQL

    create_user_stats(users) do |row|
      user = {
        imported_id: row[0],
        imported_user_id: row[0],
        new_since: Time.zone.at(row[1]),
        post_count: row[2],
        topic_count: row[3],
        first_post_created_at: row[4] && Time.zone.at(row[4]),
      }

      if @has_post_thanks
        user[:likes_given] = row[5]
        user[:likes_received] = row[6]
      end

      user
    end
  end

  def import_group_users
    puts "", "Importing group users..."

    group_users = mysql_stream <<-SQL
      SELECT usergroupid, userid
        FROM #{TABLE_PREFIX}user
       WHERE userid > #{@last_imported_user_id}
    SQL

    create_group_users(group_users) do |row|
      { group_id: group_id_from_imported_id(row[0]), user_id: user_id_from_imported_id(row[1]) }
    end
  end

  def import_user_passwords
    puts "", "Importing user passwords..."

    user_passwords = mysql_stream <<-SQL
        SELECT userid, password
          FROM #{TABLE_PREFIX}user
         WHERE userid > #{@last_imported_user_id}
      ORDER BY userid
    SQL

    create_custom_fields("user", "password", user_passwords) do |row|
      { record_id: user_id_from_imported_id(row[0]), value: row[1] }
    end
  end

  def import_user_salts
    puts "", "Importing user salts..."

    user_salts = mysql_stream <<-SQL
        SELECT userid, salt
          FROM #{TABLE_PREFIX}user
         WHERE userid > #{@last_imported_user_id}
           AND LENGTH(COALESCE(salt, '')) > 0
      ORDER BY userid
    SQL

    create_custom_fields("user", "salt", user_salts) do |row|
      { record_id: user_id_from_imported_id(row[0]), value: row[1] }
    end
  end

  def import_user_profiles
    puts "", "Importing user profiles..."

    user_profiles = mysql_stream <<-SQL
        SELECT userid, homepage, profilevisits
          FROM #{TABLE_PREFIX}user
         WHERE userid > #{@last_imported_user_id}
      ORDER BY userid
    SQL

    create_user_profiles(user_profiles) do |row|
      {
        user_id: user_id_from_imported_id(row[0]),
        website:
          (
            begin
              URI.parse(row[1]).to_s
            rescue StandardError
              nil
            end
          ),
        views: row[2],
      }
    end
  end

  def import_categories
    puts "", "Importing categories..."

    categories = mysql_query(<<-SQL).to_a
      select
        forumid,
        parentid,
        case
          when forumid in (
            select distinct forumid from (
              select forumid, title, count(title)
              from forum
              group by replace(replace(title, ':', ''), '&', '')
              having count(title) > 1
            ) as duplicated_forum_ids
          )
          then
            -- deduplicate by fudging the title; categories will needed to be manually merged later
            concat(title, '_DUPLICATE_', forumid)
          else
            title
        end as title,
        description,
        displayorder
      from forum
      order by forumid
      SQL

    return if categories.empty?

    parent_categories = categories.select { |c| c[1] == -1 }
    children_categories = categories.select { |c| c[1] != -1 }

    parent_category_ids = Set.new parent_categories.map { |c| c[0] }

    # cut down the tree to only 2 levels of categories
    children_categories.each do |cc|
      cc[1] = categories.find { |c| c[0] == cc[1] }[1] until parent_category_ids.include?(cc[1])
    end

    puts "", "Importing parent categories..."
    create_categories(parent_categories) do |row|
      {
        imported_id: row[0],
        name: normalize_text(row[2]),
        description: normalize_text(row[3]),
        position: row[4],
      }
    end

    puts "", "Importing children categories..."
    create_categories(children_categories) do |row|
      {
        imported_id: row[0],
        name: normalize_text(row[2]),
        description: normalize_text(row[3]),
        position: row[4],
        parent_category_id: category_id_from_imported_id(row[1]),
      }
    end
  end

  def import_topics
    puts "", "Importing topics..."

    topics = mysql_stream <<-SQL
        SELECT threadid, title, forumid, postuserid, open, dateline, views, visible, sticky
          FROM #{TABLE_PREFIX}thread t
         WHERE threadid > #{@last_imported_topic_id}
           AND EXISTS (SELECT 1 FROM #{TABLE_PREFIX}post p WHERE p.threadid = t.threadid)
      ORDER BY threadid
    SQL

    create_topics(topics) do |row|
      created_at = Time.zone.at(row[5])

      t = {
        imported_id: row[0],
        title: normalize_text(row[1]),
        category_id: category_id_from_imported_id(row[2]),
        user_id: user_id_from_imported_id(row[3]),
        closed: row[4] == 0,
        created_at: created_at,
        views: row[6],
        visible: row[7] == 1,
      }

      t[:pinned_at] = created_at if row[8] == 1

      t
    end
  end

  def import_posts
    puts "", "Importing posts..."

    posts = mysql_stream <<-SQL
        SELECT postid, p.threadid, parentid, userid, p.dateline, p.visible, pagetext
               #{", post_thanks_amount" if @has_post_thanks}

          FROM #{TABLE_PREFIX}post p
          JOIN #{TABLE_PREFIX}thread t ON t.threadid = p.threadid
         WHERE postid > #{@last_imported_post_id}
      ORDER BY postid
    SQL

    create_posts(posts) do |row|
      topic_id = topic_id_from_imported_id(row[1])
      replied_post_topic_id = topic_id_from_imported_post_id(row[2])
      reply_to_post_number =
        topic_id == replied_post_topic_id ? post_number_from_imported_id(row[2]) : nil

      post = {
        imported_id: row[0],
        topic_id: topic_id,
        reply_to_post_number: reply_to_post_number,
        user_id: user_id_from_imported_id(row[3]),
        created_at: Time.zone.at(row[4]),
        hidden: row[5] != 1,
        raw: normalize_text(row[6]),
      }

      post[:like_count] = row[7] if @has_post_thanks
      post
    end
  end

  def import_likes
    return unless @has_post_thanks
    puts "", "Importing likes..."

    @imported_likes = Set.new
    @last_imported_post_id = 0

    post_thanks = mysql_stream <<-SQL
        SELECT postid, userid, date
          FROM #{TABLE_PREFIX}post_thanks
         WHERE postid > #{@last_imported_post_id}
      ORDER BY postid
    SQL

    create_post_actions(post_thanks) do |row|
      post_id = post_id_from_imported_id(row[0])
      user_id = user_id_from_imported_id(row[1])

      next if post_id.nil? || user_id.nil?
      next if @imported_likes.add?([post_id, user_id]).nil?

      {
        post_id: post_id_from_imported_id(row[0]),
        user_id: user_id_from_imported_id(row[1]),
        post_action_type_id: 2,
        created_at: Time.zone.at(row[2]),
      }
    end
  end

  def import_private_topics
    puts "", "Importing private topics..."

    @imported_topics = {}

    topics = mysql_stream <<-SQL
        SELECT pmtextid, title, fromuserid, touserarray, dateline
          FROM #{TABLE_PREFIX}pmtext
         WHERE pmtextid > (#{@last_imported_private_topic_id - PRIVATE_OFFSET})
      ORDER BY pmtextid
    SQL

    create_topics(topics) do |row|
      title = extract_pm_title(row[1])
      user_ids = [row[2], row[3].scan(/i:(\d+)/)].flatten.map(&:to_i).sort
      key = [title, user_ids]

      next if @imported_topics.has_key?(key)
      @imported_topics[key] = row[0] + PRIVATE_OFFSET
      {
        archetype: Archetype.private_message,
        imported_id: row[0] + PRIVATE_OFFSET,
        title: title,
        user_id: user_id_from_imported_id(row[2]),
        created_at: Time.zone.at(row[4]),
      }
    end
  end

  def import_topic_allowed_users
    puts "", "Importing topic allowed users..."

    allowed_users = Set.new

    mysql_stream(<<-SQL).each do |row|
        SELECT pmtextid, touserarray
          FROM #{TABLE_PREFIX}pmtext
         WHERE pmtextid > (#{@last_imported_private_topic_id - PRIVATE_OFFSET})
      ORDER BY pmtextid
    SQL
      next unless topic_id = topic_id_from_imported_id(row[0] + PRIVATE_OFFSET)
      row[1]
        .scan(/i:(\d+)/)
        .flatten
        .each do |id|
          next unless user_id = user_id_from_imported_id(id)
          allowed_users << [topic_id, user_id]
        end
    end

    create_topic_allowed_users(allowed_users) { |row| { topic_id: row[0], user_id: row[1] } }
  end

  def import_private_posts
    puts "", "Importing private posts..."

    posts = mysql_stream <<-SQL
        SELECT pmtextid, title, fromuserid, touserarray, dateline, message
          FROM #{TABLE_PREFIX}pmtext
         WHERE pmtextid > #{@last_imported_private_post_id - PRIVATE_OFFSET}
      ORDER BY pmtextid
    SQL

    create_posts(posts) do |row|
      title = extract_pm_title(row[1])
      user_ids = [row[2], row[3].scan(/i:(\d+)/)].flatten.map(&:to_i).sort
      key = [title, user_ids]

      next unless topic_id = topic_id_from_imported_id(@imported_topics[key])

      {
        imported_id: row[0] + PRIVATE_OFFSET,
        topic_id: topic_id,
        user_id: user_id_from_imported_id(row[2]),
        created_at: Time.zone.at(row[4]),
        raw: normalize_text(row[5]),
      }
    end
  end

  def create_permalink_file
    puts "", "Creating Permalink File...", ""

    total = Topic.listable_topics.count
    start = Time.now

    i = 0
    File.open(File.expand_path("../vb_map.csv", __FILE__), "w") do |f|
      Topic.listable_topics.find_each do |topic|
        i += 1
        pcf = topic.posts.includes(:_custom_fields).where(post_number: 1).first.custom_fields
        if pcf && pcf["import_id"]
          id = pcf["import_id"].split("-").last

          f.print ["XXX#{id}  YYY#{topic.id}"].to_csv
          print "\r%7d/%7d - %6d/sec" % [i, total, i.to_f / (Time.now - start)] if i % 5000 == 0
        end
      end
    end
  end

  # find the uploaded file information from the db
  def find_upload(post, attachment_id)
    sql =
      "SELECT a.attachmentid attachment_id, a.userid user_id, a.filename filename
             FROM #{TABLE_PREFIX}attachment a
            WHERE a.attachmentid = #{attachment_id}"
    results = mysql_query(sql)

    unless row = results.first
      puts "Couldn't find attachment record for attachment_id = #{attachment_id} post.id = #{post.id}"
      return
    end

    attachment_id = row[0]
    user_id = row[1]
    db_filename = row[2]

    filename =
      File.join(ATTACHMENT_DIR, user_id.to_s.split("").join("/"), "#{attachment_id}.attach")
    real_filename = db_filename
    real_filename.prepend SecureRandom.hex if real_filename[0] == "."

    unless File.exist?(filename)
      puts "Attachment file #{row.inspect} doesn't exist"
      return nil
    end

    upload = create_upload(post.user.id, filename, real_filename)

    if upload.nil? || upload.errors.any?
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

  def import_attachments
    puts "", "importing attachments..."

    RateLimiter.disable
    current_count = 0
    total_count = Post.count
    success_count = 0
    fail_count = 0

    attachment_regex = %r{\[attach[^\]]*\](\d+)\[/attach\]}i

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
          # should we strip invalid attach tags?
        end

        html_for_upload(upload, filename)
      end

      if new_raw != post.raw
        PostRevisor.new(post).revise!(
          post.user,
          { raw: new_raw },
          bypass_bump: true,
          edit_reason: "Import attachments from vBulletin",
        )
      end

      success_count += 1
    end

    puts "", "imported #{success_count} attachments... failed: #{fail_count}."
    RateLimiter.enable
  end

  def import_avatars
    if AVATAR_DIR && File.exist?(AVATAR_DIR)
      puts "", "importing user avatars"

      RateLimiter.disable
      start = Time.now
      count = 0

      Dir.foreach(AVATAR_DIR) do |item|
        print "\r%7d - %6d/sec" % [count, count.to_f / (Time.now - start)]

        next if item == (".") || item == ("..") || item == (".DS_Store")
        next unless item =~ /avatar(\d+)_(\d).gif/
        scan = item.scan(/avatar(\d+)_(\d).gif/)
        next if scan[0][0].blank?
        u = UserCustomField.find_by(name: "import_id", value: scan[0][0]).try(:user)
        next if u.blank?
        # raise "User not found for id #{user_id}" if user.blank?

        photo_real_filename = File.join(AVATAR_DIR, item)
        puts "#{photo_real_filename} not found" unless File.exist?(photo_real_filename)

        upload = create_upload(u.id, photo_real_filename, File.basename(photo_real_filename))
        count += 1
        if upload.persisted?
          u.import_mode = false
          u.create_user_avatar
          u.import_mode = true
          u.user_avatar.update(custom_upload_id: upload.id)
          u.update(uploaded_avatar_id: upload.id)
        else
          puts "Error: Upload did not persist for #{u.username} #{photo_real_filename}!"
        end
      end

      puts "", "imported #{count} avatars..."
      RateLimiter.enable
    end
  end

  def import_signatures
    puts "Importing user signatures..."

    total_count = mysql_query(<<-SQL).first[0].to_i
      SELECT COUNT(userid) count
        FROM #{TABLE_PREFIX}sigparsed
    SQL
    current_count = 0

    user_signatures = mysql_stream <<-SQL
        SELECT userid, signatureparsed
          FROM #{TABLE_PREFIX}sigparsed
      ORDER BY userid
    SQL

    user_signatures.each do |sig|
      current_count += 1
      print_status current_count, total_count
      user_id = sig[0]
      user_sig = sig[1]
      next if user_id.blank? || user_sig.blank?

      u = UserCustomField.find_by(name: "import_id", value: user_id).try(:user)
      next if u.blank?

      # can not hold dupes
      UserCustomField.where(
        user_id: u.id,
        name: %w[see_signatures signature_raw signature_cooked],
      ).destroy_all

      user_sig.gsub!(%r{\[/?sigpic\]}i, "")

      UserCustomField.create!(user_id: u.id, name: "see_signatures", value: true)
      UserCustomField.create!(user_id: u.id, name: "signature_raw", value: user_sig)
      UserCustomField.create!(
        user_id: u.id,
        name: "signature_cooked",
        value: PrettyText.cook(user_sig, omit_nofollow: false),
      )
    end
  end

  def merge_duplicated_users
    count = 0
    total_count = 0

    duplicated = {}
    @user_ids_by_email
      .select { |e, ids| ids.count > 1 }
      .each_with_index do |(email, ids), i|
        duplicated[email] = [ids, i]
        count += 1
        total_count += ids.count
      end

    puts "", "Merging #{total_count} duplicated users across #{count} distinct emails..."

    start = Time.now

    Parallel.each duplicated do |email, (user_ids, i)|
      # nothing to do about these - they will remain a randomized hex string
      next unless email.presence

      # queried one by one to ensure ordering
      first, *rest =
        user_ids.map do |id|
          UserCustomField.includes(:user).find_by!(name: "import_id", value: id).user
        end

      rest.each do |dup|
        UserMerger.new(dup, first).merge!
        first.reload
        printf "."
      end

      print "\n%6d/%6d - %6d/sec" % [i, count, i.to_f / (Time.now - start)] if i % 10 == 0
    end

    puts
  end

  def save_duplicated_users
    File.open("duplicated_users.json", "w+") { |f| f.puts @user_ids_by_email.to_json }
  end

  def read_duplicated_users
    @user_ids_by_email = JSON.parse File.read("duplicated_users.json")
  end

  def extract_pm_title(title)
    normalize_text(title).scrub.gsub(/^Re\s*:\s*/i, "")
  end

  def parse_birthday(birthday)
    return if birthday.blank?
    date_of_birth =
      begin
        Date.strptime(birthday.gsub(/[^\d-]+/, ""), "%m-%d-%Y")
      rescue StandardError
        nil
      end
    return if date_of_birth.nil?
    if date_of_birth.year < 1904
      Date.new(1904, date_of_birth.month, date_of_birth.day)
    else
      date_of_birth
    end
  end

  def print_status(current, max, start_time = nil)
    if start_time.present?
      elapsed_seconds = Time.now - start_time
      elements_per_minute = "[%.0f items/min]  " % [current / elapsed_seconds.to_f * 60]
    else
      elements_per_minute = ""
    end

    print "\r%9d / %d (%5.1f%%)  %s" % [current, max, current / max.to_f * 100, elements_per_minute]
  end

  def mysql_stream(sql)
    @client.query(sql, stream: true)
  end

  def mysql_query(sql)
    @client.query(sql)
  end
end

BulkImport::VBulletin.new.run
