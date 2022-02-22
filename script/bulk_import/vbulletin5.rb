# frozen_string_literal: true

require_relative "base"
require "cgi"
require "set"
require "mysql2"
require "htmlentities"
require 'ruby-bbcode-to-md'
require 'find'

class BulkImport::VBulletin5 < BulkImport::Base

  DB_PREFIX = ""
  SUSPENDED_TILL ||= Date.new(3000, 1, 1)
  ATTACH_DIR ||= ENV['ATTACH_DIR'] || '/shared/import/data/attachments'
  AVATAR_DIR ||= ENV['AVATAR_DIR'] || '/shared/import/data/customavatars'
  ROOT_NODE = 2

  def initialize
    super

    host     = ENV["DB_HOST"] || "localhost"
    username = ENV["DB_USERNAME"] || "root"
    password = ENV["DB_PASSWORD"]
    database = ENV["DB_NAME"] || "vbulletin"
    charset  = ENV["DB_CHARSET"] || "utf8"

    @html_entities = HTMLEntities.new
    @encoding = CHARSET_MAP[charset]
    @bbcode_to_md = true

    @client = Mysql2::Client.new(
      host: host,
      username: username,
      password: password,
      database: database,
      encoding: charset,
      reconnect: true
    )

    @client.query_options.merge!(as: :array, cache_rows: false)

    # TODO: Add `LIMIT 1` to the below queries
    # ------
    # be aware there may be other contenttypeid's in use, such as poll, link, video, etc.
    @forum_typeid = mysql_query("SELECT contenttypeid FROM #{DB_PREFIX}contenttype WHERE class='Forum'").to_a[0][0]
    @channel_typeid = mysql_query("SELECT contenttypeid FROM #{DB_PREFIX}contenttype WHERE class='Channel'").to_a[0][0]
    @text_typeid = mysql_query("SELECT contenttypeid FROM #{DB_PREFIX}contenttype WHERE class='Text'").to_a[0][0]
  end

  def execute
    # enable as per requirement:
    #SiteSetting.automatic_backups_enabled = false
    #SiteSetting.disable_emails = "non-staff"
    #SiteSetting.authorized_extensions = '*'
    #SiteSetting.max_image_size_kb = 102400
    #SiteSetting.max_attachment_size_kb = 102400
    #SiteSetting.clean_up_uploads = false
    #SiteSetting.clean_orphan_uploads_grace_period_hours = 43200
    #SiteSetting.max_category_nesting = 3

    import_groups
    import_users
    import_group_users

    import_user_emails
    import_user_stats
    import_user_profiles
    import_user_account_id

    import_categories
    import_topics
    import_topic_first_posts
    import_replies

    import_likes

    import_private_topics
    import_topic_allowed_users
    import_private_first_posts
    import_private_replies

    create_oauth_records
    create_permalinks
    import_attachments
  end

  def import_groups
    puts "Importing groups..."

    groups = mysql_stream <<-SQL
        SELECT usergroupid, title, description, usertitle
          FROM #{DB_PREFIX}usergroup
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
    puts "Importing users..."

    users = mysql_stream <<-SQL
        SELECT u.userid, u.username, u.joindate, u.birthday,
               u.ipaddress, u.usergroupid, ub.bandate, ub.liftdate, u.email
          FROM #{DB_PREFIX}user u
     LEFT JOIN #{DB_PREFIX}userban ub ON ub.userid = u.userid
         WHERE u.userid > #{@last_imported_user_id}
      ORDER BY u.userid
    SQL

    create_users(users) do |row|
      u = {
        imported_id: row[0],
        username: normalize_text(row[1].truncate(60)),
        name: normalize_text(row[1]),
        email: row[8],
        created_at: Time.zone.at(row[2]),
        date_of_birth: parse_birthday(row[3]),
        primary_group_id: group_id_from_imported_id(row[5]),
        admin: row[5] == 6,
        moderator: row[5] == 7
      }
      u[:ip_address] = row[4][/\b(?:\d{1,3}\.){3}\d{1,3}\b/] if row[4].present?
      if row[7]
        u[:suspended_at] = Time.zone.at(row[6])
        u[:suspended_till] = row[7] > 0 ? Time.zone.at(row[7]) : SUSPENDED_TILL
      end
      u
    end
  end

  def import_user_emails
    puts "Importing user emails..."

    users = mysql_stream <<-SQL
        SELECT u.userid, u.email, u.joindate
          FROM #{DB_PREFIX}user u
         WHERE u.userid > #{@last_imported_user_id}
      ORDER BY u.userid
    SQL

    create_user_emails(users) do |row|
      {
        imported_id: row[0],
        imported_user_id: row[0],
        email: random_email,
        created_at: Time.zone.at(row[2])
      }
    end
  end

  def import_user_stats
    puts "Importing user stats..."

    users = mysql_stream <<-SQL
      SELECT u.userid, u.joindate, u.posts,
             SUM(
               CASE
                 WHEN n.contenttypeid = #{@text_typeid}
                  AND n.parentid IN ( select nodeid from #{DB_PREFIX}node where contenttypeid=#{@channel_typeid} )
                 THEN 1
                 ELSE 0
               END
             ) AS threads
        FROM #{DB_PREFIX}user u
        LEFT OUTER JOIN #{DB_PREFIX}node n ON u.userid = n.userid
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
      }

      user
    end
  end

  def import_group_users
    puts "Importing group users..."

    # import primary groups

    group_users = mysql_stream <<-SQL
      SELECT usergroupid, userid
        FROM #{DB_PREFIX}user
       WHERE userid > #{@last_imported_user_id}
    SQL

    create_group_users(group_users) do |row|
      {
        group_id: group_id_from_imported_id(row[0]),
        user_id: user_id_from_imported_id(row[1]),
      }
    end

    # import secondary group memberships

    secondary_group_users = mysql_stream <<-SQL
      SELECT membergroupids, userid
        FROM #{DB_PREFIX}user
    SQL

    group_mapping = []

    secondary_group_users.each do |user|
      next unless user_id = user_id_from_imported_id(user[1])
      member_groups = user[0].split(",")

      member_groups.each do |group|
        next unless group_id = group_id_from_imported_id(group)
        group_mapping << [group_id, user_id]
      end
    end

    create_group_users(group_mapping) do |row|
      {
        group_id: row[0],
        user_id: row[1]
      }
    end
  end

  def import_user_profiles
    puts "Importing user profiles..."

    user_profiles = mysql_stream <<-SQL
        SELECT userid, homepage, profilevisits
          FROM #{DB_PREFIX}user
         WHERE userid > #{@last_imported_user_id}
      ORDER BY userid
    SQL

    create_user_profiles(user_profiles) do |row|
      {
        user_id: user_id_from_imported_id(row[0]),
        website: (URI.parse(row[1]).to_s rescue nil),
        views: row[2],
      }
    end
  end

  def import_categories
    puts "Importing categories..."

    categories = mysql_query(<<-SQL
      SELECT nodeid AS forumid, title, description, displayorder, parentid, urlident
        FROM #{DB_PREFIX}node
       WHERE parentid = #{ROOT_NODE}
         AND nodeid > #{@last_imported_category_id}
       UNION
         SELECT nodeid, title, description, displayorder, parentid, urlident
           FROM #{DB_PREFIX}node
          WHERE contenttypeid = #{@channel_typeid}
            AND nodeid > #{@last_imported_category_id}
    SQL
    ).to_a

    return if categories.empty?

    parent_categories   = categories.select { |c| c[4] == ROOT_NODE }
    children_categories = categories.select { |c| c[4] != ROOT_NODE }

    parent_category_ids = Set.new parent_categories.map { |c| c[0] }

    puts "Importing parent categories..."
    create_categories(parent_categories) do |row|
      {
        imported_id: row[0],
        name: normalize_text(row[1]),
        description: normalize_text(row[2]),
        position: row[3],
        slug: row[5]
      }
    end

    puts "Importing children categories..."
    create_categories(children_categories) do |row|
      {
        imported_id: row[0],
        name: normalize_text(row[1]),
        description: normalize_text(row[2]),
        position: row[3],
        parent_category_id: category_id_from_imported_id(row[4]),
        slug: row[5]
      }
    end
  end

  def import_topics
    puts "Importing topics..."

    topics = mysql_stream <<-SQL
      SELECT t.nodeid AS threadid, t.title, t.parentid AS forumid,
             t.open, t.userid AS postuserid, t.publishdate AS dateline,
             nv.count views, 1 AS visible, t.sticky
            FROM #{DB_PREFIX}node t
       LEFT JOIN #{DB_PREFIX}nodeview nv ON nv.nodeid = t.nodeid
           WHERE t.parentid IN (SELECT nodeid from #{DB_PREFIX}node WHERE contenttypeid = #{@channel_typeid} )
             AND t.contenttypeid = #{@text_typeid}
             AND t.parentid != 7
             AND (t.unpublishdate = 0 OR t.unpublishdate IS NULL)
             AND t.approved = 1 AND t.showapproved = 1
             AND t.nodeid > #{@last_imported_topic_id}
        ORDER BY t.nodeid
    SQL

    create_topics(topics) do |row|
      created_at = Time.zone.at(row[5])

      title = normalize_text(row[1])

      t = {
        imported_id: row[0],
        title: title,
        category_id: category_id_from_imported_id(row[2]),
        user_id: user_id_from_imported_id(row[4]),
        closed: row[3] == 0,
        created_at: created_at,
        views: row[6],
        visible: row[7] == 1,
      }

      t[:pinned_at] = created_at if row[8] == 1

      t
    end
  end

  def import_topic_first_posts
    puts "Importing topic first posts..."

    topics = mysql_stream <<-SQL
      SELECT t.nodeid, t.parentid, t.userid,
             t.publishdate, 1 AS visible, rawtext
            FROM #{DB_PREFIX}node t
       LEFT JOIN #{DB_PREFIX}nodeview nv ON nv.nodeid = t.nodeid
       LEFT JOIN #{DB_PREFIX}text txt ON txt.nodeid = t.nodeid
           WHERE t.parentid IN (SELECT nodeid from #{DB_PREFIX}node WHERE contenttypeid = #{@channel_typeid} )
             AND t.contenttypeid = #{@text_typeid}
             AND t.parentid != 7
             AND (t.unpublishdate = 0 OR t.unpublishdate IS NULL)
             AND t.approved = 1 AND t.showapproved = 1
             AND t.nodeid > #{@last_imported_topic_id}
        ORDER BY t.nodeid
    SQL

    create_posts(topics) do |row|
      next unless topic_id = topic_id_from_imported_id(row[0])
      post = {
        imported_id: row[0],
        user_id: user_id_from_imported_id(row[2]) || -1,
        topic_id: topic_id,
        created_at: Time.zone.at(row[3]),
        hidden: row[4] != 1,
        raw: preprocess_raw(row[5]),
      }

      post
    end
  end

  def import_replies
    puts "Importing replies..."

    posts = mysql_stream <<-SQL
      SELECT p.nodeid, p.userid, p.parentid,
             CONVERT(CAST(rawtext AS BINARY)USING utf8),
             p.publishdate, 1 AS visible, p.parentid
        FROM #{DB_PREFIX}node p
        LEFT JOIN #{DB_PREFIX}nodeview nv ON nv.nodeid = p.nodeid
        LEFT JOIN #{DB_PREFIX}text txt ON txt.nodeid = p.nodeid
       WHERE p.parentid NOT IN (SELECT nodeid FROM #{DB_PREFIX}node WHERE contenttypeid = #{@channel_typeid} )
         AND p.contenttypeid = #{@text_typeid} AND p.nodeid > #{@last_imported_post_id}
       ORDER BY p.nodeid
    SQL

    create_posts(posts) do |row|
      next unless topic_id = topic_id_from_imported_id(row[2]) || topic_id_from_imported_id(row[0])
      post = {
        imported_id: row[0],
        user_id: user_id_from_imported_id(row[1]) || -1,
        topic_id: topic_id,
        created_at: Time.zone.at(row[4]),
        hidden: row[5] == 0,
        raw: preprocess_raw(row[3]),
      }

      post
    end
  end

  def import_likes
    puts "Importing likes..."

    @imported_likes = Set.new

    post_likes = mysql_stream <<-SQL
        SELECT nodeid, userid, dateline
          FROM #{DB_PREFIX}reputation
         WHERE nodeid > #{@last_imported_post_id}
      ORDER BY nodeid
    SQL

    create_post_actions(post_likes) do |row|
      post_id = post_id_from_imported_id(row[0])
      user_id = user_id_from_imported_id(row[1])

      next if post_id.nil? || user_id.nil?
      next if @imported_likes.add?([post_id, user_id]).nil?

      {
        post_id: post_id,
        user_id: user_id,
        post_action_type_id: 2,
        created_at: Time.zone.at(row[2])
      }
    end
  end

  def import_private_topics
    puts "Importing private topics..."

    topics = mysql_stream <<-SQL
      SELECT t.nodeid, t.title, t.userid, t.publishdate AS dateline
            FROM #{DB_PREFIX}node t
       LEFT JOIN #{DB_PREFIX}privatemessage pm ON pm.nodeid = t.nodeid
           WHERE pm.msgtype = 'message'
             AND t.parentid = 8
             AND t.nodeid > #{@last_imported_private_topic_id - PRIVATE_OFFSET}
        ORDER BY t.nodeid
    SQL

    create_topics(topics) do |row|
      title = row[1] || "No title given"
      {
        archetype: Archetype.private_message,
        imported_id: row[0] + PRIVATE_OFFSET,
        title: title,
        user_id: user_id_from_imported_id(row[2]),
        created_at: Time.zone.at(row[3]),
      }

    end
  end

  def import_topic_allowed_users
    puts "Importing topic allowed users..."

    allowed_users_sql = <<-SQL
      SELECT p.nodeid, p.userid, p.parentid
        FROM #{DB_PREFIX}node p
        LEFT JOIN #{DB_PREFIX}privatemessage pm ON pm.nodeid = p.nodeid
       WHERE pm.msgtype = 'message'
       ORDER BY p.nodeid
    SQL

    added = 0

    users_added = Set.new

    create_topic_allowed_users(mysql_stream(allowed_users_sql)) do |row|
      next unless topic_id = topic_id_from_imported_id(row[0] + PRIVATE_OFFSET) || topic_id_from_imported_id(row[2] + PRIVATE_OFFSET)
      next unless user_id = user_id_from_imported_id(row[1])
      next if users_added.add?([topic_id, user_id]).nil?
      added += 1
      {
        topic_id: topic_id,
        user_id: user_id,
      }
    end

    puts '', "Added #{added} topic allowed users records."
  end

  def import_private_first_posts
    puts "Importing private message first posts..."

    posts = mysql_stream <<-SQL
      SELECT p.nodeid, p.userid,
             CONVERT(CAST(rawtext AS BINARY)USING utf8),
             p.publishdate
        FROM #{DB_PREFIX}node p
        LEFT JOIN #{DB_PREFIX}text txt ON txt.nodeid = p.nodeid
        LEFT JOIN #{DB_PREFIX}privatemessage pm ON pm.nodeid = p.nodeid
       WHERE pm.msgtype = 'message'
         AND p.parentid = 8
         AND p.nodeid > #{@last_imported_private_post_id - PRIVATE_OFFSET}
       ORDER BY p.nodeid
    SQL

    create_posts(posts) do |row|
      {
        imported_id: row[0] + PRIVATE_OFFSET,
        topic_id: topic_id_from_imported_id(row[0] + PRIVATE_OFFSET),
        user_id: user_id_from_imported_id(row[1]),
        created_at: Time.zone.at(row[3]),
        raw: preprocess_raw(row[2]),
      }
    end
  end

  def import_private_replies
    puts "Importing private replies..."

    posts = mysql_stream <<-SQL
      SELECT p.nodeid, p.userid, p.parentid,
             CONVERT(CAST(rawtext AS BINARY)USING utf8),
             p.publishdate
        FROM #{DB_PREFIX}node p
        LEFT JOIN #{DB_PREFIX}text txt ON txt.nodeid = p.nodeid
        LEFT JOIN #{DB_PREFIX}privatemessage pm ON pm.nodeid = p.nodeid
       WHERE pm.msgtype = 'message'
         AND p.parentid != 8
         AND p.nodeid > #{@last_imported_private_post_id - PRIVATE_OFFSET}
       ORDER BY p.nodeid
    SQL

    create_posts(posts) do |row|
      {
        imported_id: row[0] + PRIVATE_OFFSET,
        topic_id: topic_id_from_imported_id(row[2] + PRIVATE_OFFSET),
        user_id: user_id_from_imported_id(row[1]),
        created_at: Time.zone.at(row[4]),
        raw: preprocess_raw(row[3]),
      }
    end
  end

  def create_permalinks
    puts '', 'creating permalinks...', ''

    # add permalink normalizations to site settings
    # EVERYTHING: /.*\/([\w-]+)$/\1 -- selects the last segment of the URL
    # and matches in the permalink table

    # create permalinks

    Topic.listable_topics.find_each do |topic|
      pcf = topic&.custom_fields
      if pcf && pcf["import_id"]
        id = pcf["import_id"]
        url = "#{id}-#{topic.slug}"
        Permalink.create(url: url, topic_id: topic.id) unless permalink_exists(url)
      end
    end

    Category.find_each do |cat|
      ccf = cat&.custom_fields
      if ccf && ccf["import_id"]
        url = cat.slug
        Permalink.create(url: url, category_id: cat.id) unless permalink_exists(url)
      end
    end
  end

  def permalink_exists(url)
    Permalink.find_by(url: url)
  end

  def check_database_for_attachment(row)
    # check if attachment resides in the database & try to retrieve
    if row[4].to_i == 0
      puts "Attachment file #{row.inspect} doesn't exist"
      return nil
    end

    tmpfile = 'attach_' + row[6].to_s
    filename = File.join('/tmp/', tmpfile)
    File.open(filename, 'wb') { |f| f.write(row[5]) }
    filename
  end

  def find_upload(post, opts = {})
    if opts[:node_id].present?
      sql = "SELECT a.nodeid, n.parentid, a.filename, fd.userid, LENGTH(fd.filedata), filedata, fd.filedataid
               FROM #{DB_PREFIX}attach a
               LEFT JOIN #{DB_PREFIX}filedata fd ON fd.filedataid = a.filedataid
               LEFT JOIN #{DB_PREFIX}node n ON n.nodeid = a.nodeid
              WHERE a.nodeid = #{opts[:node_id]}"
    elsif opts[:attachment_id].present?
      sql = "SELECT a.nodeid, n.parentid, a.filename, fd.userid, LENGTH(fd.filedata), filedata, fd.filedataid
               FROM #{DB_PREFIX}attachment a
               LEFT JOIN #{DB_PREFIX}filedata fd ON fd.filedataid = a.filedataid
               LEFT JOIN #{DB_PREFIX}node n ON n.nodeid = a.nodeid
              WHERE a.attachmentid = #{opts[:attachment_id]}"
    end

    results = mysql_query(sql)

    unless row = results.first
      puts "Couldn't find attachment record -- nodeid/filedataid = #{opts[:attachment_id] || opts[:filedata_id]} / post.id = #{post.id}"
      return nil
    end

    attachment_id = row[6]
    user_id = row[3]
    db_filename = row[2]

    filename = File.join(ATTACH_DIR, user_id.to_s.split('').join('/'), "#{attachment_id}.attach")
    real_filename = db_filename
    real_filename.prepend SecureRandom.hex if real_filename[0] == '.'

    unless File.exist?(filename)
      filename = check_database_for_attachment(row) if filename.blank?
      return nil if filename.nil?
    end

    upload = create_upload(post.user_id, filename, real_filename)

    if upload.nil? || !upload.valid?
      puts "Upload not valid"
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
    puts '', 'importing attachments...'

    # add extensions to authorized setting
    #ext = mysql_query("SELECT GROUP_CONCAT(DISTINCT(extension)) exts FROM #{DB_PREFIX}filedata").first[0].split(',')
    #SiteSetting.authorized_extensions = (SiteSetting.authorized_extensions.split("|") + ext).uniq.join("|")

    RateLimiter.disable
    current_count = 0

    total_count = Post.all.count

    success_count = 0
    fail_count = 0

    # we need to match an older and newer style for inline attachment import
    # new style matches the nodeid in the attach table
    # old style matches the filedataid in attach/filedata tables
    # if the site is very old, there may be multiple different attachment syntaxes used in posts
    attachment_regex = /\[attach[^\]]*\].*\"data-attachmentid\":"?(\d+)"?,?.*\[\/attach\]/i
    attachment_regex_oldstyle = /\[attach[^\]]*\](\d+)\[\/attach\]/i

    Post.find_each do |post|
      current_count += 1
      print_status current_count, total_count

      pcf = post.custom_fields
      next if pcf && pcf["import_attachments"] && pcf["import_attachments"] == true

      new_raw = post.raw.dup

      # look for new style attachments
      new_raw.gsub!(attachment_regex) do |s|
        matches = attachment_regex.match(s)
        node_id = matches[1]

        upload, filename = find_upload(post, { node_id: node_id })

        unless upload
          fail_count += 1
          next
        end

        html_for_upload(upload, filename)
      end

      # look for old style attachments
      new_raw.gsub!(attachment_regex_oldstyle) do |s|
        matches = attachment_regex_oldstyle.match(s)
        attachment_id = matches[1]

        upload, filename = find_upload(post, { attachment_id: attachment_id })

        unless upload
          fail_count += 1
          next
        end

        html_for_upload(upload, filename)
      end

      if new_raw != post.raw
        post.raw = new_raw
        post.save(validate: false)
        PostCustomField.create(post_id: post.id, name: "import_attachments", value: true)
        success_count += 1
      end
    end

    puts "", "imported #{success_count} attachments... failed: #{fail_count}"
    RateLimiter.enable
  end

  def extract_pm_title(title)
    normalize_text(title).scrub.gsub(/^Re\s*:\s*/i, "")
  end

  def parse_birthday(birthday)
    return if birthday.blank?
    date_of_birth = Date.strptime(birthday.gsub(/[^\d-]+/, ""), "%m-%d-%Y") rescue nil
    return if date_of_birth.nil?
    date_of_birth.year < 1904 ? Date.new(1904, date_of_birth.month, date_of_birth.day) : date_of_birth
  end

  def preprocess_raw(raw)
    return "" if raw.nil?
    raw = normalize_text(raw)
    raw = raw.dup

    # [PLAINTEXT]...[/PLAINTEXT]
    raw.gsub!(/\[\/?PLAINTEXT\]/i, "\n\n```\n\n")

    # [FONT=font]...[/FONT]
    raw.gsub!(/\[FONT=\w*\]/im, "")
    raw.gsub!(/\[\/FONT\]/im, "")

    # @[URL=<user_profile>]<username>[/URL]
    # [USER=id]username[/USER]
    # [MENTION=id]username[/MENTION]
    raw.gsub!(/@\[URL=\"\S+\"\]([\w\s]+)\[\/URL\]/i) { "@#{$1.gsub(" ", "_")}" }
    raw.gsub!(/\[USER=\"\d+\"\]([\S]+)\[\/USER\]/i) { "@#{$1.gsub(" ", "_")}" }
    raw.gsub!(/\[MENTION=\d+\]([\S]+)\[\/MENTION\]/i) { "@#{$1.gsub(" ", "_")}" }

    # [IMG2=JSON]{..."src":"<url>"}[/IMG2]
    raw.gsub!(/\[img2[^\]]*\].*\"src\":\"?([\w\\\/:\.\-;%]*)\"?}.*\[\/img2\]/i) { "\n#{CGI::unescape($1)}\n" }

    # [TABLE]...[/TABLE]
    raw.gsub!(/\[TABLE=\\"[\w:\-\s,]+\\"\]/i, "")
    raw.gsub!(/\[\/TABLE\]/i, "")

    # [HR]...[/HR]
    raw.gsub(/\[HR\]\s*\[\/HR\]/im, "---")

    # [VIDEO=youtube_share;<id>]...[/VIDEO]
    # [VIDEO=vimeo;<id>]...[/VIDEO]
    raw.gsub!(/\[VIDEO=YOUTUBE_SHARE;([^\]]+)\].*?\[\/VIDEO\]/i) { "\nhttps://www.youtube.com/watch?v=#{$1}\n" }
    raw.gsub!(/\[VIDEO=VIMEO;([^\]]+)\].*?\[\/VIDEO\]/i) { "\nhttps://vimeo.com/#{$1}\n" }

    raw
  end

  def print_status(current, max, start_time = nil)
    if start_time.present?
      elapsed_seconds = Time.now - start_time
      elements_per_minute = '[%.0f items/min]  ' % [current / elapsed_seconds.to_f * 60]
    else
      elements_per_minute = ''
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

BulkImport::VBulletin5.new.run
