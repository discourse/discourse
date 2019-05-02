# frozen_string_literal: true

require_relative "base"
require "pg"
require "htmlentities"
require 'ruby-bbcode-to-md'

class BulkImport::PhpBB < BulkImport::Base

  SUSPENDED_TILL ||= Date.new(3000, 1, 1)
  TABLE_PREFIX ||= ENV['TABLE_PREFIX'] || "phpbb_"

  def initialize
    super

    charset  = ENV["DB_CHARSET"] || "utf8"
    database = ENV["DB_NAME"] || "flightaware"
    password = ENV["DB_PASSWORD"] || "discourse"

    @html_entities = HTMLEntities.new
    @encoding = CHARSET_MAP[charset]

    @client = PG.connect(dbname: database, password: password)

    @smiley_map = {}
    add_default_smilies
  end

  def execute
    import_groups
    import_users
    import_group_users

    import_user_emails
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

    groups = psql_query <<-SQL
        SELECT group_id, group_name, group_desc
          FROM #{TABLE_PREFIX}groups
         WHERE group_id > #{@last_imported_group_id}
      ORDER BY group_id
    SQL

    create_groups(groups) do |row|
      {
        imported_id: row["group_id"],
        name: normalize_text(row["group_name"]),
        bio_raw: normalize_text(row["group_desc"])
      }
    end
  end

  def import_users
    puts "Importing users..."

    users = psql_query <<-SQL
      SELECT u.user_id, u.username, u.user_email, u.user_regdate, u.user_lastvisit, u.user_ip,
        u.user_type, u.user_inactive_reason, g.group_id, g.group_name, b.ban_start, b.ban_end, b.ban_reason,
        u.user_posts, u.user_website, u.user_from, u.user_birthday, u.user_avatar_type, u.user_avatar
      FROM #{TABLE_PREFIX}users u
        LEFT OUTER JOIN #{TABLE_PREFIX}groups g ON (g.group_id = u.group_id)
        LEFT OUTER JOIN #{TABLE_PREFIX}banlist b ON (
          u.user_id = b.ban_userid AND b.ban_exclude = 0 AND
          b.ban_end = 0
        )
      WHERE u.user_id > #{@last_imported_user_id}
      ORDER BY u.user_id
    SQL

    create_users(users) do |row|
      u = {
        imported_id: row["user_id"],
        username: normalize_text(row["username"]),
        created_at: Time.zone.at(row["user_regdate"].to_i),
        last_seen_at: row["user_lastvisit"] == 0 ? Time.zone.at(row["user_regdate"].to_i) : Time.zone.at(row["user_lastvisit"].to_i),
        trust_level: row["user_posts"] == 0 ? TrustLevel[0] : TrustLevel[1],
        date_of_birth: parse_birthday(row["user_birthday"]),
        primary_group_id: group_id_from_imported_id(row["group_id"])
      }
      u[:ip_address] = row["user_ip"][/\b(?:\d{1,3}\.){3}\d{1,3}\b/] if row["user_ip"].present?
      if row["ban_start"]
        u[:suspended_at] = Time.zone.at(row["ban_start"].to_i)
        u[:suspended_till] = row["ban_end"].to_i > 0 ? Time.zone.at(row["ban_end"].to_i) : SUSPENDED_TILL
      end
      u
    end
  end

  def import_user_emails
    puts "Importing user emails..."

    users = psql_query <<-SQL
        SELECT user_id, user_email, user_regdate
          FROM #{TABLE_PREFIX}users u
         WHERE user_id > #{@last_imported_user_id}
      ORDER BY user_id
    SQL

    create_user_emails(users) do |row|
      {
        imported_id: row["user_id"],
        imported_user_id: row["user_id"],
        email: row["user_email"],
        created_at: Time.zone.at(row["user_regdate"].to_i)
      }
    end
  end

  def import_group_users
    puts "Importing group users..."

    group_users = psql_query <<-SQL
      SELECT user_id, group_id
        FROM #{TABLE_PREFIX}users u
       WHERE user_id > #{@last_imported_user_id}
    SQL

    create_group_users(group_users) do |row|
      {
        group_id: group_id_from_imported_id(row["group_id"]),
        user_id: user_id_from_imported_id(row["user_id"]),
      }
    end
  end

  def import_user_profiles
    puts "Importing user profiles..."

    user_profiles = psql_query <<-SQL
        SELECT user_id, user_website, user_from
          FROM #{TABLE_PREFIX}users
         WHERE user_id > #{@last_imported_user_id}
      ORDER BY user_id
    SQL

    create_user_profiles(user_profiles) do |row|
      {
        user_id: user_id_from_imported_id(row["user_id"]),
        website: (URI.parse(row["user_website"]).to_s rescue nil),
        location: row["user_from"],
      }
    end
  end

  def import_categories
    puts "Importing categories..."

    categories = psql_query(<<-SQL
        SELECT forum_id, parent_id, forum_name, forum_desc
          FROM #{TABLE_PREFIX}forums
         WHERE forum_id > #{@last_imported_category_id}
      ORDER BY parent_id, left_id
    SQL
    ).to_a

    return if categories.empty?

    parent_categories   = categories.select { |c| c["parent_id"].to_i == 0 }
    children_categories = categories.select { |c| c["parent_id"].to_i != 0 }

    puts "Importing parent categories..."
    create_categories(parent_categories) do |row|
      {
        imported_id: row["forum_id"],
        name: normalize_text(row["forum_name"]),
        description: normalize_text(row["forum_desc"])
      }
    end

    puts "Importing children categories..."
    create_categories(children_categories) do |row|
      {
        imported_id: row["forum_id"],
        name: normalize_text(row["forum_name"]),
        description: normalize_text(row["forum_desc"]),
        parent_category_id: category_id_from_imported_id(row["parent_id"])
      }
    end
  end

  def import_topics
    puts "Importing topics..."

    topics = psql_query <<-SQL
        SELECT topic_id, topic_title, forum_id, topic_poster, topic_time, topic_views
          FROM #{TABLE_PREFIX}topics
         WHERE topic_id > #{@last_imported_topic_id}
           AND EXISTS (SELECT 1 FROM #{TABLE_PREFIX}posts WHERE #{TABLE_PREFIX}posts.topic_id = #{TABLE_PREFIX}topics.topic_id)
      ORDER BY topic_id
    SQL

    create_topics(topics) do |row|
      {
        imported_id: row["topic_id"],
        title: normalize_text(row["topic_title"]),
        category_id: category_id_from_imported_id(row["forum_id"]),
        user_id: user_id_from_imported_id(row["topic_poster"]),
        created_at: Time.zone.at(row["topic_time"].to_i),
        views: row["topic_views"]
      }
    end
  end

  def import_posts
    puts "Importing posts..."

    posts = psql_query <<-SQL
        SELECT p.post_id, p.topic_id, p.poster_id, p.post_time, p.post_text
          FROM #{TABLE_PREFIX}posts p
          JOIN #{TABLE_PREFIX}topics t ON t.topic_id = p.topic_id
         WHERE p.post_id > #{@last_imported_post_id}
      ORDER BY p.post_id
    SQL

    create_posts(posts) do |row|
      {
        imported_id: row["post_id"],
        topic_id: topic_id_from_imported_id(row["topic_id"]),
        user_id: user_id_from_imported_id(row["poster_id"]),
        created_at: Time.zone.at(row["post_time"].to_i),
        raw: process_raw_text(row["post_text"]),
      }
    end
  end

  def import_private_topics
    puts "Importing private topics..."

    @imported_topics = {}

    topics = psql_query <<-SQL
        SELECT msg_id, message_subject, author_id, to_address, message_time
          FROM #{TABLE_PREFIX}privmsgs
         WHERE msg_id > (#{@last_imported_private_topic_id - PRIVATE_OFFSET})
      ORDER BY msg_id
    SQL

    create_topics(topics) do |row|
      user_ids = get_message_recipients(row["author_id"], row["to_address"])
      title = extract_pm_title(row["message_subject"])
      key = [title, user_ids]

      next if @imported_topics.has_key?(key) || title.blank?
      @imported_topics[key] = row["msg_id"].to_i + PRIVATE_OFFSET

      {
        archetype: Archetype.private_message,
        imported_id: row["msg_id"].to_i + PRIVATE_OFFSET,
        title: normalize_text(title),
        user_id: user_id_from_imported_id(row["author_id"].to_i),
        created_at: Time.zone.at(row["message_time"].to_i)
      }
    end
  end

  def import_topic_allowed_users
    puts "Importing topic allowed users..."

    allowed_users = []

    psql_query(<<-SQL
        SELECT msg_id, author_id, to_address
          FROM #{TABLE_PREFIX}privmsgs
         WHERE msg_id > (#{@last_imported_private_topic_id - PRIVATE_OFFSET})
      ORDER BY msg_id
    SQL
    ).each do |row|
      next unless topic_id = topic_id_from_imported_id(row["msg_id"].to_i + PRIVATE_OFFSET)

      user_ids = get_message_recipients(row["author_id"], row["to_address"])
      user_ids.each do |id|
        next unless user_id = user_id_from_imported_id(id.to_i)
        allowed_users << [topic_id, user_id]
      end
    end

    create_topic_allowed_users(allowed_users) do |row|
      {
        topic_id: row[0],
        user_id: row[1]
      }
    end
  end

  def import_private_posts
    puts "Importing private posts..."

    posts = psql_query <<-SQL
        SELECT msg_id, message_subject, author_id, to_address, message_time, message_text
          FROM #{TABLE_PREFIX}privmsgs
         WHERE msg_id > (#{@last_imported_private_topic_id - PRIVATE_OFFSET})
      ORDER BY msg_id
    SQL

    create_posts(posts) do |row|
      user_ids = get_message_recipients(row["author_id"], row["to_address"])
      title = extract_pm_title(row["message_subject"])
      key = [title, user_ids]

      next unless topic_id = topic_id_from_imported_id(@imported_topics[key])
      {
        imported_id: row["msg_id"].to_i + PRIVATE_OFFSET,
        topic_id: topic_id,
        user_id: user_id_from_imported_id(row["author_id"].to_i),
        created_at: Time.zone.at(row["message_time"].to_i),
        raw: process_raw_text(row["message_text"])
      }
    end
  end

  def get_message_recipients(from, to)
    user_ids = to.split(':')
    user_ids.map! { |u| u[2..-1].to_i }
    user_ids.push(from.to_i)
    user_ids.uniq!
    user_ids = user_ids.flatten.map(&:to_i).sort
    user_ids
  end

  def extract_pm_title(title)
    pm_title = CGI.unescapeHTML(title)
    pm_title = title.gsub(/^Re\s*:\s*/i, "") rescue nil
    pm_title
  end

  def parse_birthday(birthday)
    return if birthday.blank?
    date_of_birth = Date.strptime(birthday.gsub(/[^\d-]+/, ""), "%m-%d-%Y") rescue nil
    return if date_of_birth.nil?
    date_of_birth.year < 1904 ? Date.new(1904, date_of_birth.month, date_of_birth.day) : date_of_birth
  end

  def psql_query(sql)
    @client.query(sql)
  end

  def process_raw_text(raw)
    return "" if raw.blank?
    text = raw.dup
    text = CGI.unescapeHTML(text)

    text.gsub!(/:(?:\w{8})\]/, ']')

    # Some links look like this: <!-- m --><a class="postlink" href="http://www.onegameamonth.com">http://www.onegameamonth.com</a><!-- m -->
    text.gsub!(/<!-- \w --><a(?:.+)href="(\S+)"(?:.*)>(.+)<\/a><!-- \w -->/i, '[\2](\1)')

    # phpBB shortens link text like this, which breaks our markdown processing:
    #   [http://answers.yahoo.com/question/index ... 223AAkkPli](http://answers.yahoo.com/question/index?qid=20070920134223AAkkPli)
    #
    # Work around it for now:
    text.gsub!(/\[http(s)?:\/\/(www\.)?/i, '[')

    # convert list tags to ul and list=1 tags to ol
    # list=a is not supported, so handle it like list=1
    # list=9 and list=x have the same result as list=1 and list=a
    text.gsub!(/\[list\](.*?)\[\/list:u\]/mi, '[ul]\1[/ul]')
    text.gsub!(/\[list=.*?\](.*?)\[\/list:o\]/mi, '[ol]\1[/ol]')

    # convert *-tags to li-tags so bbcode-to-md can do its magic on phpBB's lists:
    text.gsub!(/\[\*\](.*?)\[\/\*:m\]/mi, '[li]\1[/li]')

    # [QUOTE="<username>"] -- add newline
    text.gsub!(/(\[quote="[a-zA-Z\d]+"\])/i) { "#{$1}\n" }

    # [/QUOTE] -- add newline
    text.gsub!(/(\[\/quote\])/i) { "\n#{$1}" }

    # :) is encoded as <!-- s:) --><img src="{SMILIES_PATH}/icon_e_smile.gif" alt=":)" title="Smile" /><!-- s:) -->
    text.gsub!(/<!-- s(\S+) --><img src="\{SMILIES_PATH\}\/(.+?)" alt="(.*?)" title="(.*?)" \/><!-- s(?:\S+) -->/) do
      smiley = $1
      @smiley_map.fetch(smiley) do
        # upload_smiley(smiley, $2, $3, $4) || smiley_as_text(smiley)
        @smiley_map[smiley] = smiley
      end
    end

    text = bbcode_to_md(text)

    text
  end

  protected

  def bbcode_to_md(text)
    begin
      text.bbcode_to_md(false)
    rescue => e
      puts "Problem converting \n#{text}\n using ruby-bbcode-to-md"
      text
    end
  end

  def add_default_smilies
    {
      [':D', ':-D', ':grin:'] => ':smiley:',
      [':)', ':-)', ':smile:'] => ':slight_smile:',
      [';)', ';-)', ':wink:'] => ':wink:',
      [':(', ':-(', ':sad:'] => ':frowning:',
      [':o', ':-o', ':eek:'] => ':astonished:',
      [':shock:'] => ':open_mouth:',
      [':?', ':-?', ':???:'] => ':confused:',
      ['8-)', ':cool:'] => ':sunglasses:',
      [':lol:'] => ':laughing:',
      [':x', ':-x', ':mad:'] => ':angry:',
      [':P', ':-P', ':razz:'] => ':stuck_out_tongue:',
      [':oops:'] => ':blush:',
      [':cry:'] => ':cry:',
      [':evil:'] => ':imp:',
      [':twisted:'] => ':smiling_imp:',
      [':roll:'] => ':unamused:',
      [':!:'] => ':exclamation:',
      [':?:'] => ':question:',
      [':idea:'] => ':bulb:',
      [':arrow:'] => ':arrow_right:',
      [':|', ':-|'] => ':neutral_face:',
      [':geek:'] => ':nerd:'
    }.each do |smilies, emoji|
      smilies.each { |smiley| @smiley_map[smiley] = emoji }
    end
  end

end

BulkImport::PhpBB.new.run
