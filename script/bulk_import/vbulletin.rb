require_relative "base"
require "mysql2"
require "htmlentities"

class BulkImport::VBulletin < BulkImport::Base

  SUSPENDED_TILL ||= Date.new(3000, 1, 1)

  def initialize
    super

    host     = ENV["DB_HOST"]
    username = ENV["DB_USERNAME"] || "root"
    password = ENV["DB_PASSWORD"]
    database = ENV["DB_NAME"] || "vbulletin"

    @html_entities = HTMLEntities.new

    @client = Mysql2::Client.new(host: host, username: username, password: password, database: database)
    @client.query_options.merge!(as: :array, cache_rows: false)
  end

  def execute
    import_groups
    import_users
    import_group_users

    import_user_passwords
    import_user_salts
    import_user_profiles

    import_categories
    import_topics
    import_posts

    import_private_topics
    import_topic_allowed_users
    import_private_posts
  end

  def import_groups
    puts "Importing groups..."

    groups = mysql_stream <<-SQL
        SELECT usergroupid, title, description, usertitle
          FROM usergroup
         WHERE usergroupid > #{@last_imported_group_id}
      ORDER BY usergroupid
    SQL

    create_groups(groups) do |row|
      {
        imported_id: row[0],
        name: html_decode(row[1]),
        bio_raw: html_decode(row[2]),
        title: html_decode(row[3]),
      }
    end
  end

  def import_users
    puts "Importing users..."

    users = mysql_stream <<-SQL
        SELECT user.userid, username, email, joindate, birthday, ipaddress, user.usergroupid, bandate, liftdate
          FROM user
     LEFT JOIN userban ON userban.userid = user.userid
         WHERE user.userid > #{@last_imported_user_id}
      ORDER BY user.userid
    SQL

    create_users(users) do |row|
      u = {
        imported_id: row[0],
        username: row[1],
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

  def import_group_users
    puts "Importing group users..."

    group_users = mysql_stream <<-SQL
      SELECT usergroupid, userid
        FROM user
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
          FROM user
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
          FROM user
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
          FROM user
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
          FROM forum
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
        name: html_decode(row[2]),
        description: html_decode(row[3]),
        position: row[4],
      }
    end

    puts "Importing children categories..."
    create_categories(children_categories) do |row|
      {
        imported_id: row[0],
        name: html_decode(row[2]),
        description: html_decode(row[3]),
        position: row[4],
        parent_category_id: category_id_from_imported_id(row[1]),
      }
    end
  end

  def import_topics
    puts "Importing topics..."

    topics = mysql_stream <<-SQL
        SELECT threadid, title, forumid, postuserid, open, dateline, views, visible, sticky
          FROM thread
         WHERE threadid > #{@last_imported_topic_id}
           AND EXISTS (SELECT 1 FROM post WHERE post.threadid = thread.threadid)
      ORDER BY threadid
    SQL

    create_topics(topics) do |row|
      created_at = Time.zone.at(row[5])

      t = {
        imported_id: row[0],
        title: html_decode(row[1]),
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

  THREADID_TO_LAST_SPLIT_TOPIC ||= {
    "23402" => 356403,
    "41718" => 356406,
    "65557" => 356407,
    "116821" => 356408,
    "145183" => 356437,
    "147012" => 356438,
    "150573" => 356439,
    "165466" => 356440,
    "168440" => 356447,
    "172673" => 356451,
    "197396" => 356457,
    "214985" => 356467,
    "241020" => 356472,
    "261505" => 356473,
    "273075" => 356475,
    "279362" => 356480,
    "294442" => 356481,
    "296316" => 356484,
    "303838" => 356488,
    "304623" => 356489,
    "306609" => 356490,
    "308308" => 356492,
    "309479" => 356493,
    "310594" => 356497,
    "324756" => 356499,
    "326427" => 356500,
    "337786" => 356502,
    "343157" => 356503,
    "348725" => 356504,
    "351609" => 356505,
    "352959" => 356507,
    "362675" => 356535,
    "364296" => 356548,
    "364345" => 356549,
    "367170" => 356550,
    "367864" => 356551,
    "368039" => 356555,
    "370097" => 356556,
    "370692" => 356557,
    "370973" => 356560,
    "371616" => 356571,
    "371800" => 356576,
    "372110" => 356577,
    "372523" => 356578,
    "374095" => 356580,
    "374101" => 356582,
    "375370" => 356590,
    "375720" => 356597,
    "376222" => 356600,
    "377327" => 356602,
    "377602" => 356605,
    "378410" => 356649,
    "378427" => 356688,
    "378601" => 356715,
    "378626" => 356719,
    "379022" => 356723,
    "379154" => 356759,
    "380049" => 356765,
    "380369" => 356766,
    "382255" => 356768,
    "383977" => 356782,
    "383979" => 356800,
    "383984" => 356816,
    "384244" => 356817,
    "385428" => 356818,
    "385468" => 356835,
    "386359" => 356840,
    "388832" => 356841,
    "392270" => 356842,
    "395046" => 356844,
    "399345" => 356845,
    "401198" => 356992,
    "403768" => 356884,
    "407143" => 356891,
    "418161" => 356893,
    "421055" => 356894,
    "433491" => 356895,
    "437060" => 356897,
    "443007" => 356898,
    "447225" => 356899,
    "457936" => 356903,
    "459688" => 356906,
    "470279" => 356911,
    "473557" => 356912,
    "473994" => 356913,
    "475738" => 356916,
    "485760" => 356918,
    "504381" => 356921,
    "510334" => 356922,
    "514835" => 356924,
    "522255" => 356925,
    "527966" => 356935,
    "531947" => 356937,
    "532704" => 356938,
    "538822" => 356940,
    "540348" => 356942,
    "542165" => 356943,
    "550355" => 356945,
    "556908" => 356946,
    "573595" => 356949,
    "575689" => 356952,
    "586690" => 356953,
    "591079" => 356954,
    "592192" => 356957,
    "595446" => 356964,
    "603469" => 356975,
    "717852" => 356978,
    "732735" => 356979,
    "736189" => 356985,
    "760442" => 356993,
    "819366" => 357001,
    "819368" => 357014,
    "819370" => 357020,
    "377038" => 356601,
    "450088" => 356900,
  }

  def import_posts
    puts "Importing posts..."

    posts = mysql_stream <<-SQL
        SELECT postid, post.threadid, parentid, userid, post.dateline, post.visible, pagetext
          FROM post
          JOIN thread ON thread.threadid = post.threadid
         WHERE postid > #{@last_imported_post_id}
      ORDER BY postid
    SQL

    create_posts(posts) do |row|
      topic_id = THREADID_TO_LAST_SPLIT_TOPIC[row[1].to_s] || topic_id_from_imported_id(row[1])
      replied_post_topic_id = topic_id_from_imported_post_id(row[2])
      reply_to_post_number = topic_id == replied_post_topic_id ? post_number_from_imported_id(row[2]) : nil

      {
        imported_id: row[0],
        topic_id: topic_id,
        reply_to_post_number: reply_to_post_number,
        user_id: user_id_from_imported_id(row[3]),
        created_at: Time.zone.at(row[4]),
        hidden: row[5] == 0,
        raw: html_decode(row[6]),
      }
    end
  end

  def import_private_topics
    puts "Importing private topics..."

    @imported_topics = {}

    topics = mysql_stream <<-SQL
        SELECT pmtextid, title, fromuserid, touserarray, dateline
          FROM pmtext
         WHERE pmtextid > (#{@last_imported_private_topic_id - PRIVATE_OFFSET})
           AND dateline > 1426930967
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

    allowed_users = []

    mysql_stream(<<-SQL
        SELECT pmtextid, touserarray
          FROM pmtext
         WHERE pmtextid > (#{@last_imported_private_topic_id - PRIVATE_OFFSET})
           AND dateline > 1426930967
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
          FROM pmtext
         WHERE pmtextid > #{@last_imported_private_post_id - PRIVATE_OFFSET}
           AND dateline > 1426930967
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
        raw: html_decode(row[5]),
      }
    end
  end

  def extract_pm_title(title)
    html_decode(title).scrub.gsub(/^Re\s*:\s*/i, "")
  end

  def html_decode(text)
    @html_entities.decode((text.presence || "").scrub)
  end

  def parse_birthday(birthday)
    return if birthday.blank?
    date_of_birth = Date.strptime(birthday, "%m-%d-%Y")
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
