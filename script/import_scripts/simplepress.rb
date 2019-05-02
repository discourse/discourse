# frozen_string_literal: true

require 'mysql2'
require File.expand_path(File.dirname(__FILE__) + "/base.rb")

class ImportScripts::SimplePress < ImportScripts::Base

  SIMPLE_PRESS_DB ||= ENV['SIMPLEPRESS_DB'] || "simplepress"
  TABLE_PREFIX = "wp_sf"
  BATCH_SIZE ||= 1000

  def initialize
    super

    @client = Mysql2::Client.new(
      host: "localhost",
      username: "root",
      database: SIMPLE_PRESS_DB,
    )

    SiteSetting.max_username_length = 50
  end

  def execute
    import_users
    import_categories
    import_topics
    import_posts
  end

  def import_users
    puts "", "importing users..."

    last_user_id = -1
    total_users = mysql_query("SELECT COUNT(*) count FROM wp_users WHERE user_email LIKE '%@%'").first["count"]

    batches(BATCH_SIZE) do |offset|
      users = mysql_query(<<-SQL
        SELECT ID id, user_nicename, display_name, user_email, user_registered, user_url
          FROM wp_users
         WHERE user_email LIKE '%@%'
           AND id > #{last_user_id}
      ORDER BY id
         LIMIT #{BATCH_SIZE}
      SQL
      ).to_a

      break if users.empty?

      last_user_id = users[-1]["id"]
      user_ids = users.map { |u| u["id"].to_i }

      next if all_records_exist?(:users, user_ids)

      user_ids_sql = user_ids.join(",")

      users_description = {}
      mysql_query(<<-SQL
        SELECT user_id, meta_value description
          FROM wp_usermeta
         WHERE user_id IN (#{user_ids_sql})
           AND meta_key = 'description'
      SQL
      ).each { |um| users_description[um["user_id"]] = um["description"] }

      create_users(users, total: total_users, offset: offset) do |u|
        {
          id: u["id"].to_i,
          username: u["user_nicename"],
          email: u["user_email"].downcase,
          name: u["display_name"],
          created_at: u["user_registered"],
          website: u["user_url"],
          bio_raw: users_description[u["id"]]
        }
      end
    end
  end

  def import_categories
    puts "", "importing categories..."

    categories = mysql_query(<<-SQL
        SELECT forum_id, forum_name, forum_seq, forum_desc, parent
        FROM #{TABLE_PREFIX}forums
        ORDER BY forum_id
    SQL
    )

    create_categories(categories) do |c|
      category = { id: c['forum_id'], name: CGI.unescapeHTML(c['forum_name']), description: CGI.unescapeHTML(c['forum_desc']), position: c['forum_seq'] }
      if (parent_id = c['parent'].to_i) > 0
        category[:parent_category_id] = category_id_from_imported_category_id(parent_id)
      end
      category
    end
  end

  def import_topics
    puts "", "creating topics"

    total_count = mysql_query("SELECT COUNT(*) count FROM #{TABLE_PREFIX}posts WHERE post_index = 1").first["count"]

    batches(BATCH_SIZE) do |offset|
      results = mysql_query("
        SELECT p.post_id id,
               p.topic_id topic_id,
               t.forum_id category_id,
               t.topic_name title,
               t.topic_opened views,
               t.topic_pinned pinned,
               p.user_id user_id,
               p.post_content raw,
               p.post_date post_time
          FROM #{TABLE_PREFIX}posts p,
               #{TABLE_PREFIX}topics t
         WHERE p.topic_id = t.topic_id
           AND p.post_index = 1
      ORDER BY p.post_id
         LIMIT #{BATCH_SIZE}
        OFFSET #{offset};
      ")

      break if results.size < 1

      next if all_records_exist? :posts, results.map { |m| m['id'].to_i }

      create_posts(results, total: total_count, offset: offset) do |m|
        created_at = Time.zone.at(m['post_time'])
        {
          id: m['id'],
          user_id: user_id_from_imported_user_id(m['user_id']) || -1,
          raw: process_simplepress_post(m['raw'], m['id']),
          created_at: created_at,
          category: category_id_from_imported_category_id(m['category_id']),
          title: CGI.unescapeHTML(m['title']),
          views: m['views'],
          pinned_at: m['pinned'] == 1 ? created_at : nil,
        }
      end
    end
  end

  def import_posts
    puts "", "creating posts"

    topic_first_post_id = {}

    mysql_query("
      SELECT t.topic_id, p.post_id
        FROM #{TABLE_PREFIX}topics t
        JOIN #{TABLE_PREFIX}posts p ON p.topic_id = t.topic_id
       WHERE p.post_index = 1
    ").each { |r| topic_first_post_id[r["topic_id"]] = r["post_id"] }

    total_count = mysql_query("SELECT count(*) count FROM #{TABLE_PREFIX}posts WHERE post_index <> 1").first["count"]

    batches(BATCH_SIZE) do |offset|
      results = mysql_query("
        SELECT p.post_id id,
               p.topic_id topic_id,
               p.user_id user_id,
               p.post_content raw,
               p.post_date post_time
          FROM #{TABLE_PREFIX}posts p,
               #{TABLE_PREFIX}topics t
         WHERE p.topic_id = t.topic_id
           AND p.post_index <> 1
      ORDER BY p.post_id
         LIMIT #{BATCH_SIZE}
        OFFSET #{offset};
      ")

      break if results.size < 1

      next if all_records_exist? :posts, results.map { |m| m['id'].to_i }

      create_posts(results, total: total_count, offset: offset) do |m|
        if parent = topic_lookup_from_imported_post_id(topic_first_post_id[m['topic_id']])
          {
            id: m['id'],
            user_id: user_id_from_imported_user_id(m['user_id']) || -1,
            topic_id: parent[:topic_id],
            raw: process_simplepress_post(m['raw'], m['id']),
            created_at: Time.zone.at(m['post_time']),
          }
        else
          puts "Parent post #{m['topic_id']} doesn't exist. Skipping #{m["id"]}"
          nil
        end
      end
    end
  end

  def process_simplepress_post(raw, import_id)
    s = raw.dup

    # convert the quote line
    s.gsub!(/\[quote='([^']+)'.*?pid='(\d+).*?\]/) {
      "[quote=\"#{convert_username($1, import_id)}, " + post_id_to_post_num_and_topic($2, import_id) + '"]'
    }

    # :) is encoded as <!-- s:) --><img src="{SMILIES_PATH}/icon_e_smile.gif" alt=":)" title="Smile" /><!-- s:) -->
    s.gsub!(/<!-- s(\S+) -->(?:.*)<!-- s(?:\S+) -->/, '\1')

    # Some links look like this: <!-- m --><a class="postlink" href="http://www.onegameamonth.com">http://www.onegameamonth.com</a><!-- m -->
    s.gsub!(/<!-- \w --><a(?:.+)href="(\S+)"(?:.*)>(.+)<\/a><!-- \w -->/, '[\2](\1)')

    # Many phpbb bbcode tags have a hash attached to them. Examples:
    #   [url=https&#58;//google&#46;com:1qh1i7ky]click here[/url:1qh1i7ky]
    #   [quote=&quot;cybereality&quot;:b0wtlzex]Some text.[/quote:b0wtlzex]
    s.gsub!(/:(?:\w{8})\]/, ']')

    # Remove mybb video tags.
    s.gsub!(/(^\[video=.*?\])|(\[\/video\]$)/, '')

    s = CGI.unescapeHTML(s)

    # phpBB shortens link text like this, which breaks our markdown processing:
    #   [http://answers.yahoo.com/question/index ... 223AAkkPli](http://answers.yahoo.com/question/index?qid=20070920134223AAkkPli)
    #
    # Work around it for now:
    s.gsub!(/\[http(s)?:\/\/(www\.)?/, '[')

    s
  end

  def mysql_query(sql)
    @client.query(sql, cache_rows: false)
  end

end

ImportScripts::SimplePress.new.perform
