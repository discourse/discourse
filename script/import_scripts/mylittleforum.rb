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
export IMAGE_BASE="http://www.example.com/forum/"
export BASE="forum/"
=end


class ImportScripts::MylittleforumSQL < ImportScripts::Base

  DB_HOST ||= ENV['DB_HOST'] || "localhost"
  DB_NAME ||= ENV['DB_NAME'] || "mylittleforum"
  DB_PW ||= ENV['DB_PW'] || ""
  DB_USER ||= ENV['DB_USER'] || "root"
  TABLE_PREFIX ||= ENV['TABLE_PREFIX'] || "forum_"
  IMPORT_AFTER ||= ENV['IMPORT_AFTER'] || "1970-01-01"
  IMAGE_BASE ||= ENV['IMAGE_BASE'] || ""
  BASE ||= ENV['BASE'] || "forum/"
  BATCH_SIZE = 1000
  CONVERT_HTML = true


  def initialize

    print_warning("Importing data after #{IMPORT_AFTER}")

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
                 order by UserID ASC
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
          created_at: user['DateInserted'] == nil ? 0 : Time.zone.at(user['DateInserted']),
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

    total_count = mysql_query("SELECT count(*) count FROM #{TABLE_PREFIX}entries
                               WHERE time > '#{IMPORT_AFTER}'
                               AND pid = 0;").first['count']

    print_warning ("IMPORT_AFTER: #{IMPORT_AFTER}, COUNT: #{total_count}")

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

      create_posts(discussions, total: total_count, offset: offset) do |discussion|
        youtube = discussion['youtube'].to_s.gsub(/.*(https?:\/\/\S+)\\".*/i) { "#{$1}"}
        raw = clean_up(discussion['Body'] + "\n#{youtube}\n")
        {
          id: "discussion#" + discussion['DiscussionID'].to_s,
          user_id: user_id_from_imported_user_id(discussion['InsertUserID']) || Discourse::SYSTEM_USER_ID,
          title: discussion['Name'],
          category: category_id_from_imported_category_id(discussion['CategoryID']),
          raw: raw,
          created_at: Time.zone.at(discussion['DateInserted']),
        }
      end
    end
  end

  def import_posts
    puts "", "importing posts..."

    total_count = mysql_query("SELECT count(*) count FROM #{TABLE_PREFIX}entries WHERE pid > 0 AND time > '{IMPORT_AFTER}';").first['count']

    batches(BATCH_SIZE) do |offset|
      comments = mysql_query(
        "SELECT id as CommentID,
                pid as DiscussionID,
                text as Body,
                time as DateInserted,
                youtube_link as youtube,
                user_id as InsertUserID
         FROM #{TABLE_PREFIX}entries
         WHERE pid > 0
	 AND time > '#{IMPORT_AFTER}'
         ORDER BY time ASC
         LIMIT #{BATCH_SIZE}
         OFFSET #{offset};")

      break if comments.size < 1
      next if all_records_exist? :posts, comments.map {|comment| "comment#" + comment['CommentID'].to_s}

      create_posts(comments, total: total_count, offset: offset) do |comment|
        next unless t = topic_lookup_from_imported_post_id("discussion#" + comment['DiscussionID'].to_s)
        next if comment['Body'].blank?
        youtube = comment['youtube'].to_s.gsub(/.*(https?:\/\/\S+)\\".*/i) { "#{$1}"}
        raw = clean_up(comment['Body'] + "\n#{youtube}\n")
        {
          id: "comment#" + comment['CommentID'].to_s,
          user_id: user_id_from_imported_user_id(comment['InsertUserID']) || Discourse::SYSTEM_USER_ID,
          topic_id: t[:topic_id],
          raw: clean_up(raw),
          created_at: Time.zone.at(comment['DateInserted'])
        }
      end
    end
  end

  def clean_up(raw)
    return "" if raw.blank?

    # decode HTML entities
    raw = @htmlentities.decode(raw)

    # don't \ quotes
    raw = raw.gsub('\\"','"')

    raw = raw.gsub(/\[b\]/i, "<strong>")
    raw = raw.gsub(/\[\/b\]/i, "</strong>")

    raw = raw.gsub(/\[i\]/i, "<em>")
    raw = raw.gsub(/\[\/i\]/i, "</em>")

    raw = raw.gsub(/\[u\]/i, "<em>")
    raw = raw.gsub(/\[\/u\]/i, "</em>")

    raw = raw.gsub(/\[url\](\S+)\[\/url\]/i) { "#{$1}"}
    raw = raw.gsub(/\[link\](\S+)\[\/link\]/i) { "#{$1}"}

    # URL & LINK with text
    raw = raw.gsub(/\[url=(\S+?)\](.*?)\[\/url\]/i) { "<a href=\"#{$1}\">#{$2}</a>"}
    raw = raw.gsub(/\[link=(\S+?)\](.*?)\[\/link\]/i) { "<a href=\"#{$1}\">#{$2}</a>"}

    # remote images
    raw = raw.gsub(/\[img\](https?:.+?)\[\/img\]/i) { "<img src=\"#{$1}\">" }
    raw = raw.gsub(/\[img=(https?.+?)\](.+?)\[\/img\]/i) { "<img src=\"#{$1}\" alt=\"#{$2}\">" }
    # local images
    raw = raw.gsub(/\[img\](.+?)\[\/img\]/i) { "<img src=\"#{IMAGE_BASE}#{$1}\">" }
    raw = raw.gsub(/\[img=(.+?)\](https?.+?)\[\/img\]/i) { "<img src=\"#{IMAGE_BASE}#{$1}\" alt=\"#{$2}\">" }

    # Convert image bbcode
    raw.gsub!(/\[img=(\d+),(\d+)\]([^\]]*)\[\/img\]/i, '<img width="\1" height="\2" src="\3">')

    # CODE (not tested)
    raw = raw.gsub(/\[code\](\S+)\[\/code\]/i) { "```\n#{$1}\n```"}
    raw = raw.gsub(/\[pre\](\S+)\[\/pre\]/i) { "```\n#{$1}\n```"}


    ### FROM VANILLA:

    # fix whitespaces
    raw = raw.gsub(/(\\r)?\\n/, "\n")
             .gsub("\\t", "\t")

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

    # Remove the color tag
    raw.gsub!(/\[color=[#a-z0-9]+\]/i, "")
    raw.gsub!(/\[\/color\]/i, "")
    ### END VANILLA:

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
        Permalink.create( url: "#{BASE}/user-id-#{ucf['import_id']}.html", external_url: "/users/#{u.username}" ) rescue nil
        print '.'
      end
    end

    Topic.find_each do |topic|
      id = topic_lookup_from_imported_post_id(topic.id)
      Permalink.create( url: "#{BASE}/forum_entry-id-#{id}", topic_id: topic.id ) rescue nil
        print '.'
    end

    Category.find_each do |cat|
      id = category_id_from_imported_category_id(cat.id)
      Permalink.create( url: "#{BASE}/forum_category--#{id}.html", category_id: id ) rescue nil
      print '.'
    end
  end

  def print_warning(message)
    $stderr.puts "#{message}"
  end



end


ImportScripts::MylittleforumSQL.new.perform
