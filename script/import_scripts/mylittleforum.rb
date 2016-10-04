require "mysql2"
require File.expand_path(File.dirname(__FILE__) + "/base.rb")
require 'htmlentities'


# Before running this script, paste these lines into your shell,
# then use arrow keys to edit the values
=begin
export DB_HOST="localhost"
export DB_NAME="mylittleforum"
export DB_PW=""
export DB_USER="root"
export TABLE_PREFIX="forum_"
export IMPORT_AFTER="1970-01-01"
=end


class ImportScripts::MylittleforumSQL < ImportScripts::Base

  DB_HOST ||= ENV['DB_HOST'] || "localhost"
  DB_NAME ||= ENV['DB_name'] || "mylittleforum"
  DB_PW ||= ENV['DB_PW'] || ""
  DB_USER ||= ENV['DB_USER'] || "root"
  TABLE_PREFIX ||= ENV['TABLE_PREFIX'] = "forum_"
  IMPORT_AFTER ||= ENV['IMPORT_AFTER'] = "1970-01-01"

  BATCH_SIZE = 1000
  CONVERT_HTML = true


  def initialize
    super
    @htmlentities = HTMLEntities.new
    @client = Mysql2::Client.new(
      host: DB_HOST,
      username: DB_USER,
      password: DB_PW,
      database: DB_NAME
    )
  end

  def execute
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

    username = nil

    total_count = mysql_query("SELECT count(*) count FROM #{TABLE_PREFIX}userdata WHERE last_login > '#{IMPORT_AFTER}';").first['count']

    batches(BATCH_SIZE) do |offset|
      results = mysql_query("
             SELECT user_id as UserID, user_name as username,
                user_real_name as Name,
                user_email as Email,
                user_hp as website,
                user_place as Location,
                profile as bio_raw,
                last_login as DateLastActive,
                user_ip as InsertIPAddress,
                user_pw as password,
                logins as days_visited, # user_stats
                registered as DateInserted,
                user_pw as password,
                user_type
             FROM #{TABLE_PREFIX}userdata
		 WHERE last_login > '#{IMPORT_AFTER}'
                 order by UserID ASC;
                 LIMIT #{BATCH_SIZE}
                 OFFSET #{offset};")

      break if results.size < 1

      next if all_records_exist? :users, results.map {|u| u['UserID'].to_i}

      create_users(results, total: total_count, offset: offset) do |user|
        next if user['Email'].blank?
        next if user['Name'].blank?
        next if @lookup.user_id_from_imported_user_id(user['UserID'])

        username = fix_username(user['username'])

        { id: user['UserID'],
          email: user['Email'],
          username: username,
          name: user['Name'],
          created_at: user['DateInserted'] == nil ? 0 : Time.parse(user['DateInserted']),
          bio_raw: user['bio_raw'],
          registration_ip_address: user['InsertIPAddress'],
          website: user['user_hp'],
          password: user['password'],
          last_seen_at: user['DateLastActive'] == nil ? 0 : Time.zone.at(user['DateLastActive']),
          location: user['Location'],
          admin: user['user_type'] == "admin",
          moderator: user['user_type'] == "mod",
        }
      end
    end
  end

  def fix_username(username)
    username.gsub!(/[ +!\/,*()?]/,"_") # can't have these
    username.gsub!(/&/,"_and_") # no &
    username.gsub!(/@/,"_at_") # no @
    username.gsub!(/#/,"_hash_") # no &
    username.gsub!(/\'/,"") # seriously?
    username.gsub!(/_+/,"_") # could result in dupes, but wtf?
    username.gsub!(/_$/,"") # could result in dupes, but wtf?
    username
  end

  def import_categories
    puts "", "importing categories..."

    categories = mysql_query("
                              SELECT id as CategoryID,
                              category as Name,
                              description as Description
                              FROM #{TABLE_PREFIX}categories
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

    total_count = mysql_query("SELECT count(*) count FROM #{TABLE_PREFIX}entries where time > '{IMPORT_AFTER} and pid = 0';").first['count']

    batches(BATCH_SIZE) do |offset|
      discussions = mysql_query(
        "SELECT id as DiscussionID,
                category as CategoryID,
                subject as Name,
                text as Body,
                time as DateInserted,
                youtube_link as youtube,
                user_id as InsertUserID
         FROM #{TABLE_PREFIX}entries
         WHERE pid = 0
	 AND time > '#{IMPORT_AFTER}'
         ORDER BY time ASC
         LIMIT #{BATCH_SIZE}
         OFFSET #{offset};")

      break if discussions.size < 1
      next if all_records_exist? :posts, discussions.map {|t| "discussion#" + t['DiscussionID'].to_s}

      youtube = discussion['youtube'].gsub(/.*(https?:\/\/\S+)\\".*/i) { "#{$1}"}
      raw = clean_up(discussion['Body'] + "\n#{youtube}\n")
      create_posts(discussions, total: total_count, offset: offset) do |discussion|
        {
          id: "discussion#" + discussion['DiscussionID'].to_s,
          user_id: user_id_from_imported_user_id(discussion['InsertUserID']) || Discourse::SYSTEM_USER_ID,
          title: discussion['Name'],
          category: category_id_from_imported_category_id(discussion['CategoryID']),
          raw: raw,
          created_at: Time.parse(discussion['DateInserted']),
        }
      end
    end
  end

  def import_posts
    puts "", "importing posts..."

    total_count = mysql_query("SELECT count(*) count FROM #{TABLE_PREFIX}Comment;").first['count']

    batches(BATCH_SIZE) do |offset|
      comments = mysql_query(
        "SELECT CommentID, DiscussionID, Body,
                DateInserted, InsertUserID
         FROM #{TABLE_PREFIX}Comment
         ORDER BY CommentID ASC
         LIMIT #{BATCH_SIZE}
         OFFSET #{offset};")

      break if comments.size < 1
      next if all_records_exist? :posts, comments.map {|comment| "comment#" + comment['CommentID'].to_s}

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

    raw = raw.gsub(/\[b\]/i, "<strong>")
    raw = raw.gsub(/\[\/b\]/i, "</strong>")

    raw = raw.gsub(/\[i\]/i, "<em>")
    raw = raw.gsub(/\[\/i\]/i, "</em>")

    raw = raw.gsub(/\[u\]/i, "<em>")
    raw = raw.gsub(/\[\/u\]/i, "</em>")

    raw = raw.gsub(/\[url\](\S+)\[\/url\]/i) { "#{$1}"}
    raw = raw.gsub(/\[link\](\S+)\[\/link\]/i) { "#{$1}"}

    # URL= is broken
    raw = raw.gsub(/\[url=(\S+?)\]\[\/url\]/i) { "#{$1}"}

    raw =
    ### FROM VANILLA:

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
        Permalink.create( url: "profile/#{ucf['import_id']}/#{ucf['import_username']}", external_url: "/users/#{u.username}" ) rescue nil
        print '.'
      end
    end

    Post.find_each do |post|
      pcf = post.custom_fields
      if pcf && pcf["import_id"]
        topic = post.topic
        id = pcf["import_id"].split('#').last
        if post.post_number == 1
          slug = Slug.for(topic.title) # probably matches what mylittleforum would do...
          Permalink.create( url: "discussion/#{id}/#{slug}", topic_id: topic.id ) rescue nil
        else
          Permalink.create( url: "discussion/comment/#{id}", post_id: post.id ) rescue nil
        end
        print '.'
      end
    end
  end

end


ImportScripts::MylittleforumSQL.new.perform
