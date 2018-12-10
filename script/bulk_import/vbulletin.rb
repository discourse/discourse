require_relative "base"
require "set"
require "mysql2"
require "htmlentities"

class BulkImport::VBulletin < BulkImport::Base

  TABLE_PREFIX = "vb_"
  SUSPENDED_TILL ||= Date.new(3000, 1, 1)

  def initialize
    super

    host     = ENV["DB_HOST"] || "localhost"
    username = ENV["DB_USERNAME"] || "root"
    password = ENV["DB_PASSWORD"]
    database = ENV["DB_NAME"] || "vbulletin"
    charset  = ENV["DB_CHARSET"] || "utf8"

    @html_entities = HTMLEntities.new
    @encoding = CHARSET_MAP[charset]

    @client = Mysql2::Client.new(
      host: host,
      username: username,
      password: password,
      database: database,
      encoding: charset
    )

    @client.query_options.merge!(as: :array, cache_rows: false)

    @has_post_thanks = mysql_query(<<-SQL
        SELECT `COLUMN_NAME`
          FROM `INFORMATION_SCHEMA`.`COLUMNS`
         WHERE `TABLE_SCHEMA`='#{database}'
           AND `TABLE_NAME`='user'
           AND `COLUMN_NAME` LIKE 'post_thanks_%'
    SQL
    ).to_a.count > 0
  end

  def execute
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
  end

  def import_groups
    puts "Importing groups..."

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
    puts "Importing users..."

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
    puts "Importing user emails..."

    users = mysql_stream <<-SQL
        SELECT u.userid, email, joindate
          FROM #{TABLE_PREFIX}user u
         WHERE u.userid > #{@last_imported_user_id}
      ORDER BY u.userid
    SQL

    create_user_emails(users) do |row|
      {
        imported_id: row[0],
        imported_user_id: row[0],
        email: row[1],
        created_at: Time.zone.at(row[2])
      }
    end
  end

  def import_user_stats
    puts "Importing user stats..."

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
        first_post_created_at: row[4] && Time.zone.at(row[4])
      }

      if @has_post_thanks
        user[:likes_given] = row[5]
        user[:likes_received] = row[6]
      end

      user
    end
  end

  def import_group_users
    puts "Importing group users..."

    group_users = mysql_stream <<-SQL
      SELECT usergroupid, userid
        FROM #{TABLE_PREFIX}user
       WHERE userid > #{@last_imported_user_id}
    SQL

    create_group_users(group_users) do |row|
      {
        group_id: group_id_from_imported_id(row[0]),
        user_id: user_id_from_imported_id(row[1]),
      }
    end
  end

  def import_user_passwords
    puts "Importing user passwords..."

    user_passwords = mysql_stream <<-SQL
        SELECT userid, password
          FROM #{TABLE_PREFIX}user
         WHERE userid > #{@last_imported_user_id}
      ORDER BY userid
    SQL

    create_custom_fields("user", "password", user_passwords) do |row|
      {
        record_id: user_id_from_imported_id(row[0]),
        value: row[1],
      }
    end
  end

  def import_user_salts
    puts "Importing user salts..."

    user_salts = mysql_stream <<-SQL
        SELECT userid, salt
          FROM #{TABLE_PREFIX}user
         WHERE userid > #{@last_imported_user_id}
           AND LENGTH(COALESCE(salt, '')) > 0
      ORDER BY userid
    SQL

    create_custom_fields("user", "salt", user_salts) do |row|
      {
        record_id: user_id_from_imported_id(row[0]),
        value: row[1],
      }
    end
  end

  def import_user_profiles
    puts "Importing user profiles..."

    user_profiles = mysql_stream <<-SQL
        SELECT userid, homepage, profilevisits
          FROM #{TABLE_PREFIX}user
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
        SELECT forumid, parentid, title, description, displayorder
          FROM #{TABLE_PREFIX}forum
         WHERE forumid > #{@last_imported_category_id}
      ORDER BY forumid
    SQL
    ).to_a

    return if categories.empty?

    parent_categories   = categories.select { |c| c[1] == -1 }
    children_categories = categories.select { |c| c[1] != -1 }

    parent_category_ids = Set.new parent_categories.map { |c| c[0] }

    # cut down the tree to only 2 levels of categories
    children_categories.each do |cc|
      until parent_category_ids.include?(cc[1])
        cc[1] = categories.find { |c| c[0] == cc[1] }[1]
      end
    end

    puts "Importing parent categories..."
    create_categories(parent_categories) do |row|
      {
        imported_id: row[0],
        name: normalize_text(row[2]),
        description: normalize_text(row[3]),
        position: row[4],
      }
    end

    puts "Importing children categories..."
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
    puts "Importing topics..."

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
    puts "Importing posts..."

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
      reply_to_post_number = topic_id == replied_post_topic_id ? post_number_from_imported_id(row[2]) : nil

      post = {
        imported_id: row[0],
        topic_id: topic_id,
        reply_to_post_number: reply_to_post_number,
        user_id: user_id_from_imported_id(row[3]),
        created_at: Time.zone.at(row[4]),
        hidden: row[5] == 0,
        raw: normalize_text(row[6]),
      }

      post[:like_count] = row[7] if @has_post_thanks
      post
    end
  end

  def import_likes
    return unless @has_post_thanks
    puts "Importing likes..."

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
        created_at: Time.zone.at(row[2])
      }
    end
  end

  def import_private_topics
    puts "Importing private topics..."

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
    puts "Importing topic allowed users..."

    allowed_users = Set.new

    mysql_stream(<<-SQL
        SELECT pmtextid, touserarray
          FROM #{TABLE_PREFIX}pmtext
         WHERE pmtextid > (#{@last_imported_private_topic_id - PRIVATE_OFFSET})
      ORDER BY pmtextid
    SQL
    ).each do |row|
      next unless topic_id = topic_id_from_imported_id(row[0] + PRIVATE_OFFSET)
      row[1].scan(/i:(\d+)/).flatten.each do |id|
        next unless user_id = user_id_from_imported_id(id)
        allowed_users << [topic_id, user_id]
      end
    end

    create_topic_allowed_users(allowed_users) do |row|
      {
        topic_id: row[0],
        user_id: row[1],
      }
    end
  end

  def import_private_posts
    puts "Importing private posts..."

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

  def extract_pm_title(title)
    normalize_text(title).scrub.gsub(/^Re\s*:\s*/i, "")
  end

  def parse_birthday(birthday)
    return if birthday.blank?
    date_of_birth = Date.strptime(birthday.gsub(/[^\d-]+/, ""), "%m-%d-%Y") rescue nil
    return if date_of_birth.nil?
    date_of_birth.year < 1904 ? Date.new(1904, date_of_birth.month, date_of_birth.day) : date_of_birth
  end

  def mysql_stream(sql)
    @client.query(sql, stream: true)
  end

  def mysql_query(sql)
    @client.query(sql)
  end

end

BulkImport::VBulletin.new.run
