require File.expand_path(File.dirname(__FILE__) + "/base.rb")

require "mysql2"

class ImportScripts::PhpBB3 < ImportScripts::Base

  PHPBB_DB   = "phpbb"
  BATCH_SIZE = 1000

  def initialize
    super

    @client = Mysql2::Client.new(
      host: "localhost",
      username: "root",
      #password: "password",
      database: PHPBB_DB
    )
  end

  def execute
    import_users
    import_categories
    import_posts
    import_private_messages
    suspend_users
  end

  def import_users
    puts '', "creating users"

    total_count = mysql_query("SELECT count(*) count
                                 FROM phpbb_users u
                                 JOIN phpbb_groups g ON g.group_id = u.group_id
                                WHERE g.group_name != 'BOTS'
                                  AND u.user_type != 1;").first['count']

    batches(BATCH_SIZE) do |offset|
      results = mysql_query(
        "SELECT user_id id, user_email email, username, user_regdate, group_name
           FROM phpbb_users u
           JOIN phpbb_groups g ON g.group_id = u.group_id
          WHERE g.group_name != 'BOTS'
            AND u.user_type != 1
          ORDER BY u.user_id ASC
          LIMIT #{BATCH_SIZE}
         OFFSET #{offset};")

      break if results.size < 1

      create_users(results, total: total_count, offset: offset) do |user|
        { id: user['id'],
          email: user['email'],
          username: user['username'],
          created_at: Time.zone.at(user['user_regdate']),
          moderator: user['group_name'] == 'GLOBAL_MODERATORS',
          admin: user['group_name'] == 'ADMINISTRATORS' }
      end
    end
  end

  def import_categories
    results = mysql_query("
      SELECT forum_id id, parent_id, forum_name name, forum_desc description
        FROM phpbb_forums
    ORDER BY parent_id ASC, forum_id ASC
    ")

    create_categories(results) do |row|
      h = {id: row['id'], name: CGI.unescapeHTML(row['name']), description: CGI.unescapeHTML(row['description'])}
      if row['parent_id'].to_i > 0
        parent = category_from_imported_category_id(row['parent_id'])
        h[:parent_category_id] = parent.id if parent
      end
      h
    end
  end

  def import_posts
    puts "", "creating topics and posts"

    total_count = mysql_query("SELECT count(*) count from phpbb_posts").first["count"]

    batches(BATCH_SIZE) do |offset|
      results = mysql_query("
        SELECT p.post_id id,
               p.topic_id topic_id,
               t.forum_id category_id,
               t.topic_title title,
               t.topic_first_post_id first_post_id,
               p.poster_id user_id,
               p.post_text raw,
               p.post_time post_time
          FROM phpbb_posts p,
               phpbb_topics t
         WHERE p.topic_id = t.topic_id
         LIMIT #{BATCH_SIZE}
        OFFSET #{offset};
      ")

      break if results.size < 1

      create_posts(results, total: total_count, offset: offset) do |m|
        skip = false
        mapped = {}

        mapped[:id] = m['id']
        mapped[:user_id] = user_id_from_imported_user_id(m['user_id']) || -1
        mapped[:raw] = decode_phpbb_post(m['raw'])
        mapped[:created_at] = Time.zone.at(m['post_time'])

        if m['id'] == m['first_post_id']
          mapped[:category] = category_from_imported_category_id(m['category_id']).try(:name)
          mapped[:title] = CGI.unescapeHTML(m['title'])
        else
          parent = topic_lookup_from_imported_post_id(m['first_post_id'])
          if parent
            mapped[:topic_id] = parent[:topic_id]
          else
            puts "Parent post #{m['first_post_id']} doesn't exist. Skipping #{m["id"]}: #{m["title"][0..40]}"
            skip = true
          end
        end

        skip ? nil : mapped
      end
    end
  end

  def import_private_messages
    puts "", "creating private messages"

    total_count = mysql_query("SELECT count(*) count from phpbb_privmsgs").first["count"]

    batches(BATCH_SIZE) do |offset|
      results = mysql_query("
        SELECT msg_id id,
               root_level,
               author_id user_id,
               message_time,
               message_subject,
               message_text
          FROM phpbb_privmsgs
      ORDER BY root_level ASC, msg_id ASC
         LIMIT #{BATCH_SIZE}
        OFFSET #{offset};
      ")

      break if results.size < 1

      create_posts(results, total: total_count, offset: offset) do |m|
        skip = false
        mapped = {}

        mapped[:id] = "pm:#{m['id']}"
        mapped[:user_id] = user_id_from_imported_user_id(m['user_id']) || -1
        mapped[:raw] = decode_phpbb_post(m['message_text'])
        mapped[:created_at] = Time.zone.at(m['message_time'])

        if m['root_level'] == 0
          mapped[:title] = CGI.unescapeHTML(m['message_subject'])
          mapped[:archetype] = Archetype.private_message

          # Find the users who are part of this private message.
          # Found from the to_address of phpbb_privmsgs, by looking at
          # all the rows with the same root_level.
          # to_address looks like this: "u_91:u_1234:u_200"
          # The "u_" prefix is discarded and the rest is a user_id.

          import_user_ids = mysql_query("
            SELECT to_address
              FROM phpbb_privmsgs
             WHERE msg_id = #{m['id']}
                OR root_level = #{m['id']}").map { |r| r['to_address'].split(':') }.flatten!.map! { |u| u[2..-1] }

          mapped[:target_usernames] = import_user_ids.map! do |import_user_id|
            import_user_id.to_s == m['user_id'].to_s ? nil : User.find_by_id(user_id_from_imported_user_id(import_user_id)).try(:username)
          end.compact.uniq

          skip = true if mapped[:target_usernames].empty? # pm with yourself?
        else
          parent = topic_lookup_from_imported_post_id("pm:#{m['root_level']}")
          if parent
            mapped[:topic_id] = parent[:topic_id]
          else
            puts "Parent post pm:#{m['root_level']} doesn't exist. Skipping #{m["id"]}: #{m["message_subject"][0..40]}"
            skip = true
          end
        end

        skip ? nil : mapped
      end
    end
  end

  def suspend_users
    puts '', "updating banned users"

    where = "ban_userid > 0 AND (ban_end = 0 OR ban_end > #{Time.zone.now.to_i})"

    banned = 0
    failed = 0
    total = mysql_query("SELECT count(*) count FROM phpbb_banlist WHERE #{where}").first['count']

    system_user = Discourse.system_user

    mysql_query("SELECT ban_userid, ban_start, ban_end, ban_give_reason FROM phpbb_banlist WHERE #{where}").each do |b|
      user = find_user_by_import_id(b['ban_userid'])
      if user
        user.suspended_at = Time.zone.at(b['ban_start'])
        user.suspended_till = b['ban_end'] > 0 ? Time.zone.at(b['ban_end']) : 200.years.from_now

        if user.save
          StaffActionLogger.new(system_user).log_user_suspend(user, b['ban_give_reason'])
          banned += 1
        else
          puts "Failed to suspend user #{user.username}. #{user.errors.try(:full_messages).try(:inspect)}"
          failed += 1
        end
      else
        puts "Not found: #{b['ban_userid']}"
        failed += 1
      end

      print_status banned + failed, total
    end
  end

  def mysql_query(sql)
    @client.query(sql, cache_rows: false)
  end

  def decode_phpbb_post(raw)
    s = raw.dup

    # :) is encoded as <!-- s:) --><img src="{SMILIES_PATH}/icon_e_smile.gif" alt=":)" title="Smile" /><!-- s:) -->
    s.gsub!(/<!-- s(\S+) -->(?:.*)<!-- s(?:\S+) -->/, '\1')

    # Some links look like this: <!-- m --><a class="postlink" href="http://www.onegameamonth.com">http://www.onegameamonth.com</a><!-- m -->
    s.gsub!(/<!-- \w --><a(?:.+)href="(\S+)"(?:.*)>(.+)<\/a><!-- \w -->/, '[\2](\1)')

    # Many phpbb bbcode tags have a hash attached to them. Examples:
    #   [url=https&#58;//google&#46;com:1qh1i7ky]click here[/url:1qh1i7ky]
    #   [quote=&quot;cybereality&quot;:b0wtlzex]Some text.[/quote:b0wtlzex]
    s.gsub!(/:(?:\w{8})\]/, ']')

    CGI.unescapeHTML(s)
  end
end

ImportScripts::PhpBB3.new.perform
