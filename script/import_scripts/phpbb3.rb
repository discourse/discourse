require File.expand_path(File.dirname(__FILE__) + "/../../config/environment")
require File.expand_path(File.dirname(__FILE__) + "/base.rb")

require "mysql2"


class ImportScripts::PhpBB3 < ImportScripts::Base

  include ActionView::Helpers::NumberHelper

  PHPBB_DB   = "phpbb"
  BATCH_SIZE = 1000

  ORIGINAL_SITE_PREFIX = "oldsite.example.com/forums" # without http(s)://
  NEW_SITE_PREFIX      = "http://discourse.example.com"  # with http:// or https://

  # Set ATTACHMENTS_BASE_DIR to the base directory where attachment files are found.
  # If nil, [attachment] tags won't be processed.
  # Edit AUTHORIZED_EXTENSIONS as needed.
  ATTACHMENTS_BASE_DIR = nil
  AUTHORIZED_EXTENSIONS = ['jpg', 'jpeg', 'png', 'gif', 'zip', 'rar']

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
    import_attachments unless ATTACHMENTS_BASE_DIR.nil?
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
      SELECT forum_id id, parent_id, left(forum_name, 50) name, forum_desc description
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
      ORDER BY id
         LIMIT #{BATCH_SIZE}
        OFFSET #{offset};
      ")

      break if results.size < 1

      create_posts(results, total: total_count, offset: offset) do |m|
        skip = false
        mapped = {}

        mapped[:id] = m['id']
        mapped[:user_id] = user_id_from_imported_user_id(m['user_id']) || -1
        mapped[:raw] = process_phpbb_post(m['raw'], m['id'])
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
        mapped[:raw] = process_phpbb_post(m['message_text'], m['id'])
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

  def process_phpbb_post(raw, import_id)
    s = raw.dup

    # :) is encoded as <!-- s:) --><img src="{SMILIES_PATH}/icon_e_smile.gif" alt=":)" title="Smile" /><!-- s:) -->
    s.gsub!(/<!-- s(\S+) -->(?:.*)<!-- s(?:\S+) -->/, '\1')

    # Internal forum links of this form: <!-- l --><a class="postlink-local" href="https://example.com/forums/viewtopic.php?f=26&amp;t=3412">viewtopic.php?f=26&amp;t=3412</a><!-- l -->
    s.gsub!(/<!-- l --><a(?:.+)href="(?:\S+)"(?:.*)>viewtopic(?:.*)t=(\d+)<\/a><!-- l -->/) do |phpbb_link|
      replace_internal_link(phpbb_link, $1, import_id)
    end

    # Some links look like this: <!-- m --><a class="postlink" href="http://www.onegameamonth.com">http://www.onegameamonth.com</a><!-- m -->
    s.gsub!(/<!-- \w --><a(?:.+)href="(\S+)"(?:.*)>(.+)<\/a><!-- \w -->/, '[\2](\1)')

    # Many phpbb bbcode tags have a hash attached to them. Examples:
    #   [url=https&#58;//google&#46;com:1qh1i7ky]click here[/url:1qh1i7ky]
    #   [quote=&quot;cybereality&quot;:b0wtlzex]Some text.[/quote:b0wtlzex]
    s.gsub!(/:(?:\w{8})\]/, ']')

    s = CGI.unescapeHTML(s)

    # phpBB shortens link text like this, which breaks our markdown processing:
    #   [http://answers.yahoo.com/question/index ... 223AAkkPli](http://answers.yahoo.com/question/index?qid=20070920134223AAkkPli)
    #
    # Work around it for now:
    s.gsub!(/\[http(s)?:\/\/(www\.)?/, '[')

    # Replace internal forum links that aren't in the <!-- l --> format
    s.gsub!(internal_url_regexp) do |phpbb_link|
      replace_internal_link(phpbb_link, $1, import_id)
    end

    s
  end

  def replace_internal_link(phpbb_link, import_topic_id, from_import_post_id)
    results = mysql_query("select topic_first_post_id from phpbb_topics where topic_id = #{import_topic_id}")

    return phpbb_link unless results.size > 0

    linked_topic_id = results.first['topic_first_post_id']
    lookup = topic_lookup_from_imported_post_id(linked_topic_id)

    return phpbb_link unless lookup

    t = Topic.find_by_id(lookup[:topic_id])
    if t
      "#{NEW_SITE_PREFIX}/t/#{t.slug}/#{t.id}"
    else
      phpbb_link
    end
  end

  def internal_url_regexp
    @internal_url_regexp ||= Regexp.new("http(?:s)?://#{ORIGINAL_SITE_PREFIX.gsub('.', '\.')}/viewtopic\\.php?(?:\\S*)t=(\\d+)")
  end

  # This step is done separately because it can take multiple attempts to get right (because of
  # missing files, wrong paths, authorized extensions, etc.).
  def import_attachments
    setting = AUTHORIZED_EXTENSIONS.join('|')
    SiteSetting.authorized_extensions = setting if setting != SiteSetting.authorized_extensions

    r = /\[attachment=[\d]+\]<\!-- [\w]+ --\>([\S]+)<\!-- [\w]+ --\>\[\/attachment\]/

    user = Discourse.system_user

    current_count = 0
    total_count = Post.count
    success_count = 0
    fail_count = 0

    puts '', "Importing attachments...", ''

    Post.find_each do |post|
      current_count += 1
      print_status current_count, total_count

      new_raw = post.raw.dup
      new_raw.gsub!(r) do |s|
        matches = r.match(s)
        real_filename = matches[1]

        sql = "SELECT physical_filename,
                      mimetype
                 FROM phpbb_attachments
                WHERE post_msg_id = #{post.custom_fields['import_id']}
                  AND real_filename = '#{real_filename}';"

        begin
          results = mysql_query(sql)
        rescue Mysql2::Error => e
          puts "SQL Error"
          puts e.message
          puts sql
          fail_count += 1
          next s
        end

        row = results.first
        if !row
          puts "Couldn't find phpbb_attachments record for post.id = #{post.id}, import_id = #{post.custom_fields['import_id']}, real_filename = #{real_filename}"
          fail_count += 1
          next s
        end

        filename = File.join(ATTACHMENTS_BASE_DIR, row['physical_filename'])
        if !File.exists?(filename)
          puts "Attachment file doesn't exist: #{filename}"
          fail_count += 1
          next s
        end

        upload = create_upload(user.id, filename, real_filename)

        if upload.nil? || !upload.valid?
          puts "Upload not valid :("
          puts upload.errors.inspect if upload
          fail_count += 1
          next s
        end

        success_count += 1

        puts "SUCCESS: #{upload.url}, #{post.url}"

        if FileHelper.is_image?(upload.url)
          %Q[<img src="#{upload.url}" width="#{[upload.width, 640].compact.min}" height="#{[upload.height,480].compact.min}"><br/>]
        else
          "<a class='attachment' href='#{upload.url}'>#{real_filename}</a> (#{number_to_human_size(upload.filesize)})"
        end
      end

      if new_raw != post.raw
        PostRevisor.new(post).revise!(post.user, new_raw, {bypass_bump: true, edit_reason: 'Migrate from PHPBB3'})
      end
    end

    puts '', ''
    puts "succeeded: #{success_count}"
    puts "   failed: #{fail_count}" if fail_count > 0
    puts ''
  end

  def mysql_query(sql)
    @client.query(sql, cache_rows: false)
  end
end

ImportScripts::PhpBB3.new.perform
