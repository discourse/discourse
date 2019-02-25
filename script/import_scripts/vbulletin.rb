require 'mysql2'
require File.expand_path(File.dirname(__FILE__) + "/base.rb")
require 'htmlentities'
begin
  require 'php_serialize' # https://github.com/jqr/php-serialize
rescue LoadError
  puts
  puts 'php_serialize not found.'
  puts 'Add to Gemfile, like this: '
  puts
  puts "echo gem \\'php-serialize\\' >> Gemfile"
  puts "bundle install"
  exit
end

# See https://meta.discourse.org/t/importing-from-vbulletin-4/54881
# Please update there if substantive changes are made!

class ImportScripts::VBulletin < ImportScripts::Base
  BATCH_SIZE = 1000

  # CHANGE THESE BEFORE RUNNING THE IMPORTER

  DB_HOST ||= ENV['DB_HOST'] || "localhost"
  DB_NAME ||= ENV['DB_NAME'] || "vbulletin"
  DB_PW ||= ENV['DB_PW'] || ""
  DB_USER ||= ENV['DB_USER'] || "root"
  TIMEZONE ||= ENV['TIMEZONE'] || "America/Los_Angeles"
  TABLE_PREFIX ||= ENV['TABLE_PREFIX'] || "vb_"
  ATTACHMENT_DIR ||= ENV['ATTACHMENT_DIR'] || '/path/to/your/attachment/folder'

  puts "#{DB_USER}:#{DB_PW}@#{DB_HOST} wants #{DB_NAME}"

  def initialize
    @bbcode_to_md = true

    super

    @usernames = {}

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
export DB_NAME="vbulletin"
export DB_PW=""
export DB_USER="root"
export TABLE_PREFIX="vb_"
export ATTACHMENT_DIR '/path/to/your/attachment/folder'

Exiting.
EOM
      exit
  end

  def execute
    mysql_query("CREATE INDEX firstpostid_index ON #{TABLE_PREFIX}thread (firstpostid)") rescue nil

    import_groups
    import_users
    create_groups_membership
    import_categories
    import_topics
    import_posts
    import_private_messages
    import_attachments

    close_topics
    post_process_posts

    create_permalink_file
    suspend_users
  end

  def import_groups
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

  def get_username_for_old_username(old_username)
    if @usernames.has_key?(old_username)
      @usernames[old_username]
    else
      old_username
    end
  end

  def import_users
    puts "", "importing users"

    user_count = mysql_query("SELECT COUNT(userid) count FROM #{TABLE_PREFIX}user").first["count"]

    last_user_id = -1

    batches(BATCH_SIZE) do |offset|
      users = mysql_query(<<-SQL
          SELECT userid
               , username
               , homepage
               , usertitle
               , usergroupid
               , joindate
               , email
               , password
               , salt
            FROM #{TABLE_PREFIX}user
           WHERE userid > #{last_user_id}
        ORDER BY userid
           LIMIT #{BATCH_SIZE}
      SQL
      ).to_a

      break if users.empty?

      last_user_id = users[-1]["userid"]
      users.reject! { |u| @lookup.user_already_imported?(u["userid"]) }

      create_users(users, total: user_count, offset: offset) do |user|
        email = user["email"].presence || fake_email
        email = fake_email unless email[EmailValidator.email_regex]

        password = [user["password"].presence, user["salt"].presence].compact.join(":")

        username = @htmlentities.decode(user["username"]).strip

        {
          id: user["userid"],
          name: username,
          username: username,
          password: password,
          email: email,
          merge: true,
          website: user["homepage"].strip,
          title: @htmlentities.decode(user["usertitle"]).strip,
          primary_group_id: group_id_from_imported_group_id(user["usergroupid"].to_i),
          created_at: parse_timestamp(user["joindate"]),
          last_seen_at: parse_timestamp(user["lastvisit"]),
          post_create_action: proc do |u|
            import_profile_picture(user, u)
            import_profile_background(user, u)
          end
        }
      end
    end

    @usernames = UserCustomField.joins(:user).where(name: 'import_username').pluck('user_custom_fields.value', 'users.username').to_h
  end

  def create_groups_membership
    puts "", "Creating groups membership..."

    Group.find_each do |group|
      begin
        next if group.automatic
        puts "\t#{group.name}"
        next if GroupUser.where(group_id: group.id).count > 0
        user_ids_in_group = User.where(primary_group_id: group.id).pluck(:id).to_a
        next if user_ids_in_group.size == 0
        values = user_ids_in_group.map { |user_id| "(#{group.id}, #{user_id}, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)" }.join(",")

        DB.exec <<~SQL
          INSERT INTO group_users (group_id, user_id, created_at, updated_at) VALUES #{values}
        SQL

        Group.reset_counters(group.id, :group_users)
      rescue Exception => e
        puts e.message
        puts e.backtrace.join("\n")
      end
    end
  end

  def import_profile_picture(old_user, imported_user)
    query = mysql_query <<-SQL
        SELECT filedata, filename
          FROM #{TABLE_PREFIX}customavatar
         WHERE userid = #{old_user["userid"]}
      ORDER BY dateline DESC
         LIMIT 1
    SQL

    picture = query.first

    return if picture.nil?
    return if picture["filedata"].nil?

    file = Tempfile.new("profile-picture")
    file.write(picture["filedata"].encode("ASCII-8BIT").force_encoding("UTF-8"))
    file.rewind

    upload = UploadCreator.new(file, picture["filename"]).create_for(imported_user.id)

    return if !upload.persisted?

    imported_user.create_user_avatar
    imported_user.user_avatar.update(custom_upload_id: upload.id)
    imported_user.update(uploaded_avatar_id: upload.id)
  ensure
    file.close rescue nil
    file.unlind rescue nil
  end

  def import_profile_background(old_user, imported_user)
    query = mysql_query <<-SQL
        SELECT filedata, filename
          FROM #{TABLE_PREFIX}customprofilepic
         WHERE userid = #{old_user["userid"]}
      ORDER BY dateline DESC
         LIMIT 1
    SQL

    background = query.first

    return if background.nil?
    return if background["filedata"].nil?

    file = Tempfile.new("profile-background")
    file.write(background["filedata"].encode("ASCII-8BIT").force_encoding("UTF-8"))
    file.rewind

    upload = UploadCreator.new(file, background["filename"]).create_for(imported_user.id)

    return if !upload.persisted?

    imported_user.user_profile.update(profile_background: upload.url)
  ensure
    file.close rescue nil
    file.unlink rescue nil
  end

  def import_categories
    puts "", "importing top level categories..."

    categories = mysql_query("SELECT forumid, title, description, displayorder, parentid FROM #{TABLE_PREFIX}forum ORDER BY forumid").to_a

    top_level_categories = categories.select { |c| c["parentid"] == -1 }

    create_categories(top_level_categories) do |category|
      {
        id: category["forumid"],
        name: @htmlentities.decode(category["title"]).strip,
        position: category["displayorder"],
        description: @htmlentities.decode(category["description"]).strip
      }
    end

    puts "", "importing children categories..."

    children_categories = categories.select { |c| c["parentid"] != -1 }
    top_level_category_ids = Set.new(top_level_categories.map { |c| c["forumid"] })

    # cut down the tree to only 2 levels of categories
    children_categories.each do |cc|
      while !top_level_category_ids.include?(cc["parentid"])
        cc["parentid"] = categories.detect { |c| c["forumid"] == cc["parentid"] }["parentid"]
      end
    end

    create_categories(children_categories) do |category|
      {
        id: category["forumid"],
        name: @htmlentities.decode(category["title"]).strip,
        position: category["displayorder"],
        description: @htmlentities.decode(category["description"]).strip,
        parent_category_id: category_id_from_imported_category_id(category["parentid"])
      }
    end
  end

  def import_topics
    puts "", "importing topics..."

    topic_count = mysql_query("SELECT COUNT(threadid) count FROM #{TABLE_PREFIX}thread").first["count"]

    last_topic_id = -1

    batches(BATCH_SIZE) do |offset|
      topics = mysql_query(<<-SQL
          SELECT t.threadid threadid, t.title title, forumid, open, postuserid, t.dateline dateline, views, t.visible visible, sticky,
                 p.pagetext raw
            FROM #{TABLE_PREFIX}thread t
            JOIN #{TABLE_PREFIX}post p ON p.postid = t.firstpostid
           WHERE t.threadid > #{last_topic_id}
        ORDER BY t.threadid
           LIMIT #{BATCH_SIZE}
      SQL
      ).to_a

      break if topics.empty?

      last_topic_id = topics[-1]["threadid"]
      topics.reject! { |t| @lookup.post_already_imported?("thread-#{t["threadid"]}") }

      create_posts(topics, total: topic_count, offset: offset) do |topic|
        raw = preprocess_post_raw(topic["raw"]) rescue nil
        next if raw.blank?
        topic_id = "thread-#{topic["threadid"]}"
        t = {
          id: topic_id,
          user_id: user_id_from_imported_user_id(topic["postuserid"]) || Discourse::SYSTEM_USER_ID,
          title: @htmlentities.decode(topic["title"]).strip[0...255],
          category: category_id_from_imported_category_id(topic["forumid"]),
          raw: raw,
          created_at: parse_timestamp(topic["dateline"]),
          visible: topic["visible"].to_i == 1,
          views: topic["views"],
        }
        t[:pinned_at] = t[:created_at] if topic["sticky"].to_i == 1
        t
      end

      # Add the following to permalink_normalizations for this to work:
      # /forum\/.*?\/(\d*)\-.*/thread/\1

      topics.each do |thread|
        topic_id = "thread-#{thread["threadid"]}"
        topic = topic_lookup_from_imported_post_id(topic_id)
        if topic.present?
          url_slug = "thread/#{thread["threadid"]}" if thread["title"].present?
          Permalink.create(url: url_slug, topic_id: topic[:topic_id].to_i) if url_slug.present? && topic[:topic_id].present?
        end
      end

    end
  end

  def import_posts
    puts "", "importing posts..."

    post_count = mysql_query(<<-SQL
      SELECT COUNT(postid) count
        FROM #{TABLE_PREFIX}post p
        JOIN #{TABLE_PREFIX}thread t ON t.threadid = p.threadid
       WHERE t.firstpostid <> p.postid
    SQL
    ).first["count"]

    last_post_id = -1

    batches(BATCH_SIZE) do |offset|
      posts = mysql_query(<<-SQL
          SELECT p.postid, p.userid, p.threadid, p.pagetext raw, p.dateline, p.visible, p.parentid
            FROM #{TABLE_PREFIX}post p
            JOIN #{TABLE_PREFIX}thread t ON t.threadid = p.threadid
           WHERE t.firstpostid <> p.postid
             AND p.postid > #{last_post_id}
        ORDER BY p.postid
           LIMIT #{BATCH_SIZE}
      SQL
      ).to_a

      break if posts.empty?

      last_post_id = posts[-1]["postid"]
      posts.reject! { |p| @lookup.post_already_imported?(p["postid"].to_i) }

      create_posts(posts, total: post_count, offset: offset) do |post|
        raw = preprocess_post_raw(post["raw"]) rescue nil
        next if raw.blank?
        next unless topic = topic_lookup_from_imported_post_id("thread-#{post["threadid"]}")
        p = {
          id: post["postid"],
          user_id: user_id_from_imported_user_id(post["userid"]) || Discourse::SYSTEM_USER_ID,
          topic_id: topic[:topic_id],
          raw: raw,
          created_at: parse_timestamp(post["dateline"]),
          hidden: post["visible"].to_i == 0,
        }
        if parent = topic_lookup_from_imported_post_id(post["parentid"])
          p[:reply_to_post_number] = parent[:post_number]
        end
        p
      end
    end
  end

  # find the uploaded file information from the db
  def find_upload(post, attachment_id)
    sql = "SELECT a.attachmentid attachment_id, a.userid user_id, a.filedataid file_id, a.filename filename,
                  LENGTH(fd.filedata) AS dbsize, filedata, a.caption caption
             FROM #{TABLE_PREFIX}attachment a
             LEFT JOIN #{TABLE_PREFIX}filedata fd ON fd.filedataid = a.filedataid
            WHERE a.attachmentid = #{attachment_id}"
    results = mysql_query(sql)

    unless row = results.first
      puts "Couldn't find attachment record for post.id = #{post.id}, import_id = #{post.custom_fields['import_id']}"
      return
    end

    filename = File.join(ATTACHMENT_DIR, row['user_id'].to_s.split('').join('/'), "#{row['file_id']}.attach")
    real_filename = row['filename']
    real_filename.prepend SecureRandom.hex if real_filename[0] == '.'

    unless File.exists?(filename)
      if row['dbsize'].to_i == 0
        puts "Attachment file #{row['filedataid']} doesn't exist"
        return nil
      end

      tmpfile = 'attach_' + row['filedataid'].to_s
      filename = File.join('/tmp/', tmpfile)
      File.open(filename, 'wb') { |f|
        f.write(row['filedata'])
      }
    end

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

  def import_private_messages
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

  def import_attachments
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
        PostRevisor.new(post).revise!(post.user, { raw: new_raw }, bypass_bump: true, edit_reason: 'Import attachments from vBulletin')
      end

      success_count += 1
    end
  end

  def close_topics
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

  def post_process_posts
    puts "", "Postprocessing posts..."

    current = 0
    max = Post.count

    Post.find_each do |post|
      begin
        old_raw = post.raw.dup
        new_raw = postprocess_post_raw(post.raw)
        if new_raw != old_raw
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

  def preprocess_post_raw(raw)
    return "" if raw.blank?

    # decode HTML entities
    raw = @htmlentities.decode(raw)

    # fix whitespaces
    raw.gsub!(/(\\r)?\\n/, "\n")
    raw.gsub!("\\t", "\t")

    # [HTML]...[/HTML]
    raw.gsub!(/\[html\]/i, "\n```html\n")
    raw.gsub!(/\[\/html\]/i, "\n```\n")

    # [PHP]...[/PHP]
    raw.gsub!(/\[php\]/i, "\n```php\n")
    raw.gsub!(/\[\/php\]/i, "\n```\n")

    # [HIGHLIGHT="..."]
    raw.gsub!(/\[highlight="?(\w+)"?\]/i) { "\n```#{$1.downcase}\n" }

    # [CODE]...[/CODE]
    # [HIGHLIGHT]...[/HIGHLIGHT]
    raw.gsub!(/\[\/?code\]/i, "\n```\n")
    raw.gsub!(/\[\/?highlight\]/i, "\n```\n")

    # [SAMP]...[/SAMP]
    raw.gsub!(/\[\/?samp\]/i, "`")

    # replace all chevrons with HTML entities
    # NOTE: must be done
    #  - AFTER all the "code" processing
    #  - BEFORE the "quote" processing
    raw.gsub!(/`([^`]+)`/im) { "`" + $1.gsub("<", "\u2603") + "`" }
    raw.gsub!("<", "&lt;")
    raw.gsub!("\u2603", "<")

    raw.gsub!(/`([^`]+)`/im) { "`" + $1.gsub(">", "\u2603") + "`" }
    raw.gsub!(">", "&gt;")
    raw.gsub!("\u2603", ">")

    # [URL=...]...[/URL]
    raw.gsub!(/\[url="?([^"]+?)"?\](.*?)\[\/url\]/im) { "[#{$2.strip}](#{$1})" }
    raw.gsub!(/\[url="?(.+?)"?\](.+)\[\/url\]/im) { "[#{$2.strip}](#{$1})" }

    # [URL]...[/URL]
    # [MP3]...[/MP3]
    raw.gsub!(/\[\/?url\]/i, "")
    raw.gsub!(/\[\/?mp3\]/i, "")

    # [MENTION]<username>[/MENTION]
    raw.gsub!(/\[mention\](.+?)\[\/mention\]/i) do
      new_username = get_username_for_old_username($1)
      "@#{new_username}"
    end

    # [FONT=blah] and [COLOR=blah]
    raw.gsub! /\[FONT=.*?\](.*?)\[\/FONT\]/im, '\1'
    raw.gsub! /\[COLOR=.*?\](.*?)\[\/COLOR\]/im, '\1'
    raw.gsub! /\[COLOR=#.*?\](.*?)\[\/COLOR\]/im, '\1'

    raw.gsub! /\[SIZE=.*?\](.*?)\[\/SIZE\]/im, '\1'
    raw.gsub! /\[SUP\](.*?)\[\/SUP\]/im, '\1'
    raw.gsub! /\[h=.*?\](.*?)\[\/h\]/im, '\1'

    # [CENTER]...[/CENTER]
    raw.gsub! /\[CENTER\](.*?)\[\/CENTER\]/im, '\1'

    # [INDENT]...[/INDENT]
    raw.gsub! /\[INDENT\](.*?)\[\/INDENT\]/im, '\1'

    # Tables to MD
    raw.gsub!(/\[TABLE.*?\](.*?)\[\/TABLE\]/im) { |t|
      rows = $1.gsub!(/\s*\[TR\](.*?)\[\/TR\]\s*/im) { |r|
        cols = $1.gsub! /\s*\[TD.*?\](.*?)\[\/TD\]\s*/im, '|\1'
        "#{cols}|\n"
      }
      header, rest = rows.split "\n", 2
      c = header.count "|"
      sep = "|---" * (c - 1)
      "#{header}\n#{sep}|\n#{rest}\n"
    }

    # [QUOTE]...[/QUOTE]
    raw.gsub!(/\[quote\](.+?)\[\/quote\]/im) { |quote|
      quote.gsub!(/\[quote\](.+?)\[\/quote\]/im) { "\n#{$1}\n" }
      quote.gsub!(/\n(.+?)/) { "\n> #{$1}" }
    }

    # [QUOTE=<username>]...[/QUOTE]
    raw.gsub!(/\[quote=([^;\]]+)\](.+?)\[\/quote\]/im) do
      old_username, quote = $1, $2
      new_username = get_username_for_old_username(old_username)
      "\n[quote=\"#{new_username}\"]\n#{quote}\n[/quote]\n"
    end

    # [YOUTUBE]<id>[/YOUTUBE]
    raw.gsub!(/\[youtube\](.+?)\[\/youtube\]/i) { "\n//youtu.be/#{$1}\n" }

    # [VIDEO=youtube;<id>]...[/VIDEO]
    raw.gsub!(/\[video=youtube;([^\]]+)\].*?\[\/video\]/i) { "\n//youtu.be/#{$1}\n" }

    # Fix uppercase B U and I tags
    raw.gsub!(/(\[\/?[BUI]\])/i) { $1.downcase }

    # More Additions ....

    # [spoiler=Some hidden stuff]SPOILER HERE!![/spoiler]
    raw.gsub!(/\[spoiler="?(.+?)"?\](.+?)\[\/spoiler\]/im) { "\n#{$1}\n[spoiler]#{$2}[/spoiler]\n" }

    # [IMG][IMG]http://i63.tinypic.com/akga3r.jpg[/IMG][/IMG]
    raw.gsub!(/\[IMG\]\[IMG\](.+?)\[\/IMG\]\[\/IMG\]/i) { "[IMG]#{$1}[/IMG]" }

    # convert list tags to ul and list=1 tags to ol
    # (basically, we're only missing list=a here...)
    # (https://meta.discourse.org/t/phpbb-3-importer-old/17397)
    raw.gsub!(/\[list\](.*?)\[\/list\]/im, '[ul]\1[/ul]')
    raw.gsub!(/\[list=1\](.*?)\[\/list\]/im, '[ol]\1[/ol]')
    raw.gsub!(/\[list\](.*?)\[\/list:u\]/im, '[ul]\1[/ul]')
    raw.gsub!(/\[list=1\](.*?)\[\/list:o\]/im, '[ol]\1[/ol]')
    # convert *-tags to li-tags so bbcode-to-md can do its magic on phpBB's lists:
    raw.gsub!(/\[\*\]\n/, '')
    raw.gsub!(/\[\*\](.*?)\[\/\*:m\]/, '[li]\1[/li]')
    raw.gsub!(/\[\*\](.*?)\n/, '[li]\1[/li]')
    raw.gsub!(/\[\*=1\]/, '')

    raw
  end

  def postprocess_post_raw(raw)
    # [QUOTE=<username>;<post_id>]...[/QUOTE]
    raw.gsub!(/\[quote=([^;]+);(\d+)\](.+?)\[\/quote\]/im) do
      old_username, post_id, quote = $1, $2, $3

      new_username = get_username_for_old_username(old_username)

      # There is a bug here when the first post in a topic is quoted.
      # The first post in a topic does not have an post_custom_field referring to the post number,
      # but it refers to thread-XXX instead, so this lookup fails miserably then.
      # Fixing this would imply rewriting that logic completely.

      if topic_lookup = topic_lookup_from_imported_post_id(post_id)
        post_number = topic_lookup[:post_number]
        topic_id    = topic_lookup[:topic_id]
        "\n[quote=\"#{new_username},post:#{post_number},topic:#{topic_id}\"]\n#{quote}\n[/quote]\n"
      else
        "\n[quote=\"#{new_username}\"]\n#{quote}\n[/quote]\n"
      end
    end

    # remove attachments
    raw.gsub!(/\[attach[^\]]*\]\d+\[\/attach\]/i, "")

    # [THREAD]<thread_id>[/THREAD]
    # ==> http://my.discourse.org/t/slug/<topic_id>
    raw.gsub!(/\[thread\](\d+)\[\/thread\]/i) do
      thread_id = $1
      if topic_lookup = topic_lookup_from_imported_post_id("thread-#{thread_id}")
        topic_lookup[:url]
      else
        $&
      end
    end

    # [THREAD=<thread_id>]...[/THREAD]
    # ==> [...](http://my.discourse.org/t/slug/<topic_id>)
    raw.gsub!(/\[thread=(\d+)\](.+?)\[\/thread\]/i) do
      thread_id, link = $1, $2
      if topic_lookup = topic_lookup_from_imported_post_id("thread-#{thread_id}")
        url = topic_lookup[:url]
        "[#{link}](#{url})"
      else
        $&
      end
    end

    # [POST]<post_id>[/POST]
    # ==> http://my.discourse.org/t/slug/<topic_id>/<post_number>
    raw.gsub!(/\[post\](\d+)\[\/post\]/i) do
      post_id = $1
      if topic_lookup = topic_lookup_from_imported_post_id(post_id)
        topic_lookup[:url]
      else
        $&
      end
    end

    # [POST=<post_id>]...[/POST]
    # ==> [...](http://my.discourse.org/t/<topic_slug>/<topic_id>/<post_number>)
    raw.gsub!(/\[post=(\d+)\](.+?)\[\/post\]/i) do
      post_id, link = $1, $2
      if topic_lookup = topic_lookup_from_imported_post_id(post_id)
        url = topic_lookup[:url]
        "[#{link}](#{url})"
      else
        $&
      end
    end

    raw
  end

  def create_permalink_file
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

  def suspend_users
    puts '', "updating banned users"

    banned = 0
    failed = 0
    total = mysql_query("SELECT count(*) count FROM #{TABLE_PREFIX}userban").first['count']

    system_user = Discourse.system_user

    mysql_query("SELECT userid, bandate FROM #{TABLE_PREFIX}userban").each do |b|
      user = User.find_by_id(user_id_from_imported_user_id(b['userid']))
      if user
        user.suspended_at = parse_timestamp(user["bandate"])
        user.suspended_till = 200.years.from_now

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

ImportScripts::VBulletin.new.perform
