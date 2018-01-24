require "mysql2"
require File.expand_path(File.dirname(__FILE__) + "/base.rb")
require 'htmlentities'

class ImportScripts::VanillaSQL < ImportScripts::Base

  VANILLA_DB = "vanilla_mysql"
  TABLE_PREFIX = "GDN_"
  ATTACHMENTS_BASE_DIR = nil # "/absolute/path/to/attachments" set the absolute path if you have attachments
  BATCH_SIZE = 1000
  CONVERT_HTML = true

  def initialize
    super
    @htmlentities = HTMLEntities.new
    @client = Mysql2::Client.new(
      host: "localhost",
      username: "root",
      password: "pa$$word",
      database: VANILLA_DB
    )

    @import_tags = false
    begin
      r = @client.query("select count(*) count from #{TABLE_PREFIX}Tag where countdiscussions > 0")
      @import_tags = true if r.first["count"].to_i > 0
    rescue => e
      puts "Tags won't be imported. #{e.message}"
    end
  end

  def execute
    if @import_tags
      SiteSetting.tagging_enabled = true
      SiteSetting.max_tags_per_topic = 10
    end

    import_users
    import_avatars
    import_categories
    import_topics
    import_posts

    update_tl0

    create_permalinks
  end

  def import_users
    puts '', "creating users"

    @user_is_deleted = false
    @last_deleted_username = nil
    username = nil
    @last_user_id = -1
    total_count = mysql_query("SELECT count(*) count FROM #{TABLE_PREFIX}User;").first['count']

    batches(BATCH_SIZE) do |offset|
      results = mysql_query(
        "SELECT UserID, Name, Title, Location, About, Email,
                DateInserted, DateLastActive, InsertIPAddress, Admin
         FROM #{TABLE_PREFIX}User
         WHERE UserID > #{@last_user_id}
         ORDER BY UserID ASC
         LIMIT #{BATCH_SIZE};")

      break if results.size < 1
      @last_user_id = results.to_a.last['UserID']
      next if all_records_exist? :users, results.map { |u| u['UserID'].to_i }

      create_users(results, total: total_count, offset: offset) do |user|
        next if user['Email'].blank?
        next if user['Name'].blank?
        next if @lookup.user_id_from_imported_user_id(user['UserID'])
        if user['Name'] == '[Deleted User]'
          # EVERY deleted user record in Vanilla has the same username: [Deleted User]
          # Save our UserNameSuggester some pain:
          @user_is_deleted = true
          username = @last_deleted_username || user['Name']
        else
          @user_is_deleted = false
          username = user['Name']
        end

        { id: user['UserID'],
          email: user['Email'],
          username: username,
          name: user['Name'],
          created_at: user['DateInserted'] == nil ? 0 : Time.zone.at(user['DateInserted']),
          bio_raw: user['About'],
          registration_ip_address: user['InsertIPAddress'],
          last_seen_at: user['DateLastActive'] == nil ? 0 : Time.zone.at(user['DateLastActive']),
          location: user['Location'],
          admin: user['Admin'] == 1,
          post_create_action: proc do |newuser|
            if @user_is_deleted
              @last_deleted_username = newuser.username
            end
          end }
      end
    end
  end

  def import_avatars
    if ATTACHMENTS_BASE_DIR && File.exists?(ATTACHMENTS_BASE_DIR)
      puts "", "importing user avatars"

      User.find_each do |u|
        next unless u.custom_fields["import_id"]

        r = mysql_query("SELECT photo FROM #{TABLE_PREFIX}User WHERE UserID = #{u.custom_fields['import_id']};").first
        next if r.nil?
        photo = r["photo"]
        next unless photo.present?

        # Possible encoded values:
        # 1. cf://uploads/userpics/820/Y0AFUQYYM6QN.jpg
        # 2. ~cf/userpics2/cf566487133f1f538e02da96f9a16b18.jpg
        # 3. ~cf/userpics/txkt8kw1wozn.jpg

        photo_real_filename = nil
        parts = photo.squeeze("/").split("/")
        if parts[0] == "cf:"
          photo_path = "#{ATTACHMENTS_BASE_DIR}/#{parts[2..-2].join('/')}".squeeze("/")
        elsif parts[0] == "~cf"
          photo_path = "#{ATTACHMENTS_BASE_DIR}/#{parts[1..-2].join('/')}".squeeze("/")
        else
          puts "UNKNOWN FORMAT: #{photo}"
          next
        end

        if !File.exists?(photo_path)
          puts "Path to avatar file not found! Skipping. #{photo_path}"
          next
        end

        photo_real_filename = find_photo_file(photo_path, parts.last)
        if photo_real_filename.nil?
          puts "Couldn't find file for #{photo}. Skipping."
          next
        end

        print "."

        upload = create_upload(u.id, photo_real_filename, File.basename(photo_real_filename))
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
    end
  end

  def find_photo_file(path, base_filename)
    base_guess = base_filename.dup
    full_guess = File.join(path, base_guess) # often an exact match exists

    return full_guess if File.exists?(full_guess)

    # Otherwise, the file exists but with a prefix:
    # The p prefix seems to be the full file, so try to find that one first.
    ['p', 't', 'n'].each do |prefix|
      full_guess = File.join(path, "#{prefix}#{base_guess}")
      return full_guess if File.exists?(full_guess)
    end

    # Didn't find it.
    nil
  end

  def import_categories
    puts "", "importing categories..."

    categories = mysql_query("
                              SELECT CategoryID, Name, Description
                              FROM #{TABLE_PREFIX}Category
                              ORDER BY CategoryID ASC
                            ").to_a

    create_categories(categories) do |category|
      {
        id: category['CategoryID'],
        name: CGI.unescapeHTML(category['Name']),
        description: CGI.unescapeHTML(category['Description'])
      }
    end
  end

  def import_topics
    puts "", "importing topics..."

    tag_names_sql = "select t.name as tag_name from GDN_Tag t, GDN_TagDiscussion td where t.tagid = td.tagid and td.discussionid = {discussionid} and t.name != '';"

    total_count = mysql_query("SELECT count(*) count FROM #{TABLE_PREFIX}Discussion;").first['count']

    @last_topic_id = -1

    batches(BATCH_SIZE) do |offset|
      discussions = mysql_query(
        "SELECT DiscussionID, CategoryID, Name, Body,
                DateInserted, InsertUserID
         FROM #{TABLE_PREFIX}Discussion
         WHERE DiscussionID > #{@last_topic_id}
         ORDER BY DiscussionID ASC
         LIMIT #{BATCH_SIZE};")

      break if discussions.size < 1
      @last_topic_id = discussions.to_a.last['DiscussionID']
      next if all_records_exist? :posts, discussions.map { |t| "discussion#" + t['DiscussionID'].to_s }

      create_posts(discussions, total: total_count, offset: offset) do |discussion|
        {
          id: "discussion#" + discussion['DiscussionID'].to_s,
          user_id: user_id_from_imported_user_id(discussion['InsertUserID']) || Discourse::SYSTEM_USER_ID,
          title: discussion['Name'],
          category: category_id_from_imported_category_id(discussion['CategoryID']),
          raw: clean_up(discussion['Body']),
          created_at: Time.zone.at(discussion['DateInserted']),
          post_create_action: proc do |post|
            if @import_tags
              tag_names = @client.query(tag_names_sql.gsub('{discussionid}', discussion['DiscussionID'].to_s)).map { |row| row['tag_name'] }
              DiscourseTagging.tag_topic_by_names(post.topic, staff_guardian, tag_names)
            end
          end
        }
      end
    end
  end

  def import_posts
    puts "", "importing posts..."

    total_count = mysql_query("SELECT count(*) count FROM #{TABLE_PREFIX}Comment;").first['count']
    @last_post_id = -1
    batches(BATCH_SIZE) do |offset|
      comments = mysql_query(
        "SELECT CommentID, DiscussionID, Body,
                DateInserted, InsertUserID
         FROM #{TABLE_PREFIX}Comment
         WHERE CommentID > #{@last_post_id}
         ORDER BY CommentID ASC
         LIMIT #{BATCH_SIZE};")

      break if comments.size < 1
      @last_post_id = comments.to_a.last['CommentID']
      next if all_records_exist? :posts, comments.map { |comment| "comment#" + comment['CommentID'].to_s }

      create_posts(comments, total: total_count, offset: offset) do |comment|
        next unless t = topic_lookup_from_imported_post_id("discussion#" + comment['DiscussionID'].to_s)
        next if comment['Body'].blank?
        {
          id: "comment#" + comment['CommentID'].to_s,
          user_id: user_id_from_imported_user_id(comment['InsertUserID']) || Discourse::SYSTEM_USER_ID,
          topic_id: t[:topic_id],
          raw: clean_up(comment['Body']),
          created_at: Time.zone.at(comment['DateInserted'])
        }
      end
    end
  end

  def clean_up(raw)
    return "" if raw.blank?

    # decode HTML entities
    raw = @htmlentities.decode(raw)

    # fix whitespaces
    raw = raw.gsub(/(\\r)?\\n/, "\n")
      .gsub("\\t", "\t")

    # [HTML]...[/HTML]
    raw = raw.gsub(/\[html\]/i, "\n```html\n")
      .gsub(/\[\/html\]/i, "\n```\n")

    # [PHP]...[/PHP]
    raw = raw.gsub(/\[php\]/i, "\n```php\n")
      .gsub(/\[\/php\]/i, "\n```\n")

    # [HIGHLIGHT="..."]
    raw = raw.gsub(/\[highlight="?(\w+)"?\]/i) { "\n```#{$1.downcase}\n" }

    # [CODE]...[/CODE]
    # [HIGHLIGHT]...[/HIGHLIGHT]
    raw = raw.gsub(/\[\/?code\]/i, "\n```\n")
      .gsub(/\[\/?highlight\]/i, "\n```\n")

    # [SAMP]...[/SAMP]
    raw.gsub!(/\[\/?samp\]/i, "`")

    unless CONVERT_HTML
      # replace all chevrons with HTML entities
      # NOTE: must be done
      #  - AFTER all the "code" processing
      #  - BEFORE the "quote" processing
      raw = raw.gsub(/`([^`]+)`/im) { "`" + $1.gsub("<", "\u2603") + "`" }
        .gsub("<", "&lt;")
        .gsub("\u2603", "<")

      raw = raw.gsub(/`([^`]+)`/im) { "`" + $1.gsub(">", "\u2603") + "`" }
        .gsub(">", "&gt;")
        .gsub("\u2603", ">")
    end

    # [URL=...]...[/URL]
    raw.gsub!(/\[url="?(.+?)"?\](.+)\[\/url\]/i) { "[#{$2}](#{$1})" }

    # [IMG]...[/IMG]
    raw.gsub!(/\[\/?img\]/i, "")

    # [URL]...[/URL]
    # [MP3]...[/MP3]
    raw = raw.gsub(/\[\/?url\]/i, "")
      .gsub(/\[\/?mp3\]/i, "")

    # [QUOTE]...[/QUOTE]
    raw.gsub!(/\[quote\](.+?)\[\/quote\]/im) { "\n> #{$1}\n" }

    # [YOUTUBE]<id>[/YOUTUBE]
    raw.gsub!(/\[youtube\](.+?)\[\/youtube\]/i) { "\nhttps://www.youtube.com/watch?v=#{$1}\n" }

    # [youtube=425,350]id[/youtube]
    raw.gsub!(/\[youtube="?(.+?)"?\](.+)\[\/youtube\]/i) { "\nhttps://www.youtube.com/watch?v=#{$2}\n" }

    # [MEDIA=youtube]id[/MEDIA]
    raw.gsub!(/\[MEDIA=youtube\](.+?)\[\/MEDIA\]/i) { "\nhttps://www.youtube.com/watch?v=#{$1}\n" }

    # [VIDEO=youtube;<id>]...[/VIDEO]
    raw.gsub!(/\[video=youtube;([^\]]+)\].*?\[\/video\]/i) { "\nhttps://www.youtube.com/watch?v=#{$1}\n" }

    # Convert image bbcode
    raw.gsub!(/\[img=(\d+),(\d+)\]([^\]]*)\[\/img\]/i, '<img width="\1" height="\2" src="\3">')

    # Remove the color tag
    raw.gsub!(/\[color=[#a-z0-9]+\]/i, "")
    raw.gsub!(/\[\/color\]/i, "")

    # remove attachments
    raw.gsub!(/\[attach[^\]]*\]\d+\[\/attach\]/i, "")

    # sanitize img tags
    # This regexp removes everything between the first and last img tag. The .* is too much.
    # If it's needed, it needs to be fixed.
    # raw.gsub!(/\<img.*src\="([^\"]+)\".*\>/i) {"\n<img src='#{$1}'>\n"}

    raw
  end

  def staff_guardian
    @_staff_guardian ||= Guardian.new(Discourse.system_user)
  end

  def mysql_query(sql)
    @client.query(sql)
    # @client.query(sql, cache_rows: false) #segfault: cache_rows: false causes segmentation fault
  end

  def create_permalinks
    puts '', 'Creating redirects...', ''

    User.find_each do |u|
      ucf = u.custom_fields
      if ucf && ucf["import_id"] && ucf["import_username"]
        Permalink.create(url: "profile/#{ucf['import_id']}/#{ucf['import_username']}", external_url: "/users/#{u.username}") rescue nil
        print '.'
      end
    end

    Post.find_each do |post|
      pcf = post.custom_fields
      if pcf && pcf["import_id"]
        topic = post.topic
        id = pcf["import_id"].split('#').last
        if post.post_number == 1
          slug = Slug.for(topic.title) # probably matches what vanilla would do...
          Permalink.create(url: "discussion/#{id}/#{slug}", topic_id: topic.id) rescue nil
        else
          Permalink.create(url: "discussion/comment/#{id}", post_id: post.id) rescue nil
        end
        print '.'
      end
    end
  end

end

ImportScripts::VanillaSQL.new.perform
