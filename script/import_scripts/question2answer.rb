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

class ImportScripts::Question2Answer < ImportScripts::Base
  BATCH_SIZE = 1000

  # CHANGE THESE BEFORE RUNNING THE IMPORTER

  DB_HOST ||= ENV['DB_HOST'] || "localhost"
  DB_NAME ||= ENV['DB_NAME']
  DB_PW ||= ENV['DB_PW']
  DB_USER ||= ENV['DB_USER']
  TIMEZONE ||= ENV['TIMEZONE'] || "America/Los_Angeles"
  TABLE_PREFIX ||= ENV['TABLE_PREFIX'] || "qa_"
  MAIN_APP_DB_NAME = "primary_db"

  puts "#{DB_USER}:#{DB_PW}@#{DB_HOST} wants #{DB_NAME}"

  def initialize
    super

    @old_username_to_new_usernames = {}

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
export DB_NAME=""
export DB_PW='password'
export DB_USER="root"
export TABLE_PREFIX="qa_"

Exiting.
EOM
      exit
  end

  def execute
    import_users
    import_categories
    import_topics
    import_posts
    import_likes

    post_process_posts
    create_permalinks
  end

  def import_users
    puts "", "importing users"

    #only import users that have posted or voted on Q2A
    user_count = mysql_query("SELECT COUNT(id) count FROM #{MAIN_APP_DB_NAME}.users u WHERE EXISTS (SELECT 1 FROM #{TABLE_PREFIX}posts p WHERE p.userid=u.id) or EXISTS (SELECT 1 FROM #{TABLE_PREFIX}uservotes u WHERE u.userid=u.id)").first["count"]
    last_user_id = -1

    batches(BATCH_SIZE) do |offset|
      users = mysql_query(<<-SQL
          SELECT u.id, u.email, first_name, last_name, u.created_at, last_sign_in_at, u.custom_field_1, u.website website, u.city city, u.state state, i.cdn_slug cdn_slug
            FROM #{MAIN_APP_DB_NAME}.users u
            LEFT JOIN #{MAIN_APP_DB_NAME}.images i
            ON i.id=u.image_id
           WHERE u.id > #{last_user_id} AND
           (EXISTS (SELECT 1 FROM #{TABLE_PREFIX}posts p WHERE p.userid=u.id) or EXISTS (SELECT 1 FROM #{TABLE_PREFIX}uservotes u WHERE u.userid=u.id))
        ORDER BY u.id
           LIMIT #{BATCH_SIZE}
      SQL
      ).to_a

      break if users.empty?

      last_user_id = users[-1]["id"]
      users.reject! { |u| @lookup.user_already_imported?(u["id"].to_i) }

      create_users(users, total: user_count, offset: offset) do |user|
        email = user["email"].presence

        username = @htmlentities.decode(user["email"]).strip.split("@").first
        avatar_url = "https://your_image_bucket/#{user['cdn_slug']}" if user['cdn_slug']
        {
          id: user["id"],
          name: "#{user['first_name']} #{user['last_name']}",
          username: username,
          website: user['website'],
          email: email,
          avatar_url: avatar_url,
          custom_fields: user["custom_field_1"] ? { user_field_1: user["custom_field_1"] } : {},
          location: user["city"] && user["state"] ? "#{user['city']}, #{user['state']}" : nil,
          created_at: user["created_at"],
          last_seen_at: user["last_sign_in_at"],
          post_create_action: proc do |u|
            @old_username_to_new_usernames[user["username"]] = u.username
          end
        }
      end
    end
  end

  def import_categories
    puts "", "importing top level categories..."

    categories = mysql_query("SELECT categoryid, parentid, title, position FROM #{TABLE_PREFIX}categories ORDER BY categoryid").to_a

    top_level_categories = categories.select { |c| c["parentid"].nil? }

    create_categories(top_level_categories) do |category|
      {
        id: category["categoryid"],
        name: @htmlentities.decode(category["title"]).strip,
        position: category["position"]
      }
    end

    puts "", "importing children categories..."

    children_categories = categories.select { |c| !c["parentid"].nil? }
    top_level_category_ids = Set.new(top_level_categories.map { |c| c["categoryid"] })

    # cut down the tree to only 2 levels of categories
    children_categories.each do |cc|
      while !top_level_category_ids.include?(cc["parentid"])
        cc["parentid"] = categories.detect { |c| c["categoryid"] == cc["parentid"] }["parentid"]
      end
    end

    create_categories(children_categories) do |category|
      {
        id: category["categoryid"],
        name: @htmlentities.decode(category["title"]).strip,
        position: category["position"],
        parent_category_id: category_id_from_imported_category_id(category["parentid"])
      }
    end
  end

  def import_topics
    puts "", "importing topics..."

    topic_count = mysql_query("SELECT COUNT(postid) count FROM #{TABLE_PREFIX}posts WHERE type in ('Q', 'Q_HIDDEN')").first["count"]

    last_topic_id = -1

    batches(BATCH_SIZE) do |offset|
      topics = mysql_query(<<-SQL
          SELECT p.postid, p.type, p.categoryid, p.closedbyid, p.userid postuserid, p.views, p.created, p.title, p.content raw
            FROM #{TABLE_PREFIX}posts p
           WHERE p.postid > #{last_topic_id}
           and p.parentid IS NULL
           and type IN ('Q', 'Q_HIDDEN')
        ORDER BY p.postid
           LIMIT #{BATCH_SIZE}
      SQL
      ).to_a

      break if topics.empty?

      last_topic_id = topics[-1]["postid"]
      topics.reject! { |t| @lookup.post_already_imported?("thread-#{t["postid"]}") }

      create_posts(topics, total: topic_count, offset: offset) do |topic|
        begin
          raw = preprocess_post_raw(topic["raw"])
        rescue => e
          puts e.message
        end

        topic_id = "thread-#{topic["postid"]}"
        t = {
          id: topic_id,
          user_id: user_id_from_imported_user_id(topic["postuserid"]) || Discourse::SYSTEM_USER_ID,
          title: @htmlentities.decode(topic["title"]).strip[0...255],
          category: category_id_from_imported_category_id(topic["categoryid"]),
          raw: raw,
          created_at: topic["created"],
          visible: topic["closedbyid"].to_i == 0 && topic["type"] != 'Q_HIDDEN',
          views: topic["views"],
        }
        t
      end

      # uncomment below lines to create permalink
      topics.each do |thread|
        topic_id = "thread-#{thread["postid"]}"
        topic = topic_lookup_from_imported_post_id(topic_id)
        if topic.present?
          title_slugified = slugify(thread["title"], false, 50) if thread["title"].present?
          url_slug = "#{thread["postid"]}/#{title_slugified}" if thread["title"].present?
          Permalink.create(url: url_slug, topic_id: topic[:topic_id].to_i) if url_slug.present? && topic[:topic_id].present?
        end
      end

    end
  end

  def slugify(title, ascii_only, max_length)
    words = title.downcase.gsub(/[^a-zA-Z0-9\s]/, '').split(" ")
    word_lengths = {}

    words.each_with_index do |word, idx|
      word_lengths[idx] = word.length
    end

    remaining = max_length
    if word_lengths.inject(0) { |sum, (_, v)| sum + v } > remaining
      word_lengths = Hash[word_lengths.sort { |x, y| y[1] <=> x[1] }]
      word_lengths.each do |idx, word_length|
        if remaining > 0
          remaining -= word_length
        else
          words[idx] = nil
        end
      end
    end
    words = words.compact.join("-")
  end

  def import_posts
    puts "", "importing posts..."

    post_count = mysql_query(<<-SQL
      SELECT COUNT(postid) count
        FROM #{TABLE_PREFIX}posts p
       WHERE p.parentid IS NOT NULL
    SQL
    ).first["count"]

    last_post_id = -1

    batches(BATCH_SIZE) do |offset|
      posts = mysql_query(<<-SQL
          SELECT p.postid, p.type, p.parentid, p.categoryid, p.closedbyid, p.userid, p.views, p.created, p.title, p.content
            FROM #{TABLE_PREFIX}posts p
           WHERE p.parentid IS NOT NULL
             AND p.postid > #{last_post_id}
             AND type in ('A')
             AND closedbyid IS NULL
        ORDER BY p.postid
           LIMIT #{BATCH_SIZE}
      SQL
      ).to_a

      break if posts.empty?
      last_post_id = posts[-1]["postid"]
      posts.reject! { |p| @lookup.post_already_imported?(p["postid"].to_i) }

      create_posts(posts, total: post_count, offset: offset) do |post|
        begin
          raw = preprocess_post_raw(post["content"])
        rescue => e
          puts e.message
        end
        next if raw.blank?
        next unless topic = topic_lookup_from_imported_post_id("thread-#{post["parentid"]}")

        p = {
          id: post["postid"],
          user_id: user_id_from_imported_user_id(post["userid"]) || Discourse::SYSTEM_USER_ID,
          topic_id: topic[:topic_id],
          raw: raw,
          created_at: post["created"],
        }
        if parent = topic_lookup_from_imported_post_id(post["parentid"])
          p[:reply_to_post_number] = parent[:post_number]
        end
        p
      end
    end
  end

  def import_likes
    puts "", "importing likes..."
    likes = mysql_query(<<-SQL
        SELECT postid, userid
        FROM #{TABLE_PREFIX}uservotes u
        WHERE u.vote=1
                        SQL
                       ).to_a
    likes.each do |like|
      post = Post.find_by(id: post_id_from_imported_post_id("thread-#{like['postid']}"))
      user = User.find_by(id: user_id_from_imported_user_id(like["userid"]))
      begin
        PostActionCreator.like(user, post) if user && post
      rescue => e
        puts "error acting on post #{e}"
      end
    end
  end

  def post_process_posts
    puts "", "Postprocessing posts..."

    current = 0
    max = Post.count

    Post.find_each do |post|
      begin
        new_raw = postprocess_post_raw(post.raw)
        if new_raw != post.raw
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
    raw = ActionView::Base.full_sanitizer.sanitize raw

    # fix whitespaces
    raw.gsub!(/(\\r)?\\n/, "\n")
    raw.gsub!("\\t", "\t")

    raw.gsub!('<br />', "\n")

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
      old_username = $1
      if @old_username_to_new_usernames.has_key?(old_username)
        old_username = @old_username_to_new_usernames[old_username]
      end
      "@#{old_username}"
    end

    # [FONT=blah] and [COLOR=blah]
    raw.gsub!(/\[FONT=.*?\](.*?)\[\/FONT\]/im, '\1')
    raw.gsub!(/\[COLOR=.*?\](.*?)\[\/COLOR\]/im, '\1')
    raw.gsub!(/\[COLOR=#.*?\](.*?)\[\/COLOR\]/im, '\1')

    raw.gsub!(/\[SIZE=.*?\](.*?)\[\/SIZE\]/im, '\1')
    raw.gsub!(/\[h=.*?\](.*?)\[\/h\]/im, '\1')

    # [CENTER]...[/CENTER]
    raw.gsub!(/\[CENTER\](.*?)\[\/CENTER\]/im, '\1')

    # [INDENT]...[/INDENT]
    raw.gsub!(/\[INDENT\](.*?)\[\/INDENT\]/im, '\1')
    raw.gsub!(/\[TABLE\](.*?)\[\/TABLE\]/im, '\1')
    raw.gsub!(/\[TR\](.*?)\[\/TR\]/im, '\1')
    raw.gsub!(/\[TD\](.*?)\[\/TD\]/im, '\1')
    raw.gsub!(/\[TD="?.*?"?\](.*?)\[\/TD\]/im, '\1')

    # [QUOTE]...[/QUOTE]
    raw.gsub!(/\[quote\](.+?)\[\/quote\]/im) { |quote|
      quote.gsub!(/\[quote\](.+?)\[\/quote\]/im) { "\n#{$1}\n" }
      quote.gsub!(/\n(.+?)/) { "\n> #{$1}" }
    }

    # [QUOTE=<username>]...[/QUOTE]
    raw.gsub!(/\[quote=([^;\]]+)\](.+?)\[\/quote\]/im) do
      old_username, quote = $1, $2
      if @old_username_to_new_usernames.has_key?(old_username)
        old_username = @old_username_to_new_usernames[old_username]
      end
      "\n[quote=\"#{old_username}\"]\n#{quote}\n[/quote]\n"
    end

    # [YOUTUBE]<id>[/YOUTUBE]
    raw.gsub!(/\[youtube\](.+?)\[\/youtube\]/i) { "\n//youtu.be/#{$1}\n" }

    # [VIDEO=youtube;<id>]...[/VIDEO]
    raw.gsub!(/\[video=youtube;([^\]]+)\].*?\[\/video\]/i) { "\n//youtu.be/#{$1}\n" }

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

    raw.strip!
    raw
  end

  def postprocess_post_raw(raw)
    # [QUOTE=<username>;<post_id>]...[/QUOTE]
    raw.gsub!(/\[quote=([^;]+);(\d+)\](.+?)\[\/quote\]/im) do
      old_username, post_id, quote = $1, $2, $3

      if @old_username_to_new_usernames.has_key?(old_username)
        old_username = @old_username_to_new_usernames[old_username]
      end

      if topic_lookup = topic_lookup_from_imported_post_id(post_id)
        post_number = topic_lookup[:post_number]
        topic_id    = topic_lookup[:topic_id]
        "\n[quote=\"#{old_username},post:#{post_number},topic:#{topic_id}\"]\n#{quote}\n[/quote]\n"
      else
        "\n[quote=\"#{old_username}\"]\n#{quote}\n[/quote]\n"
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

  def create_permalinks
    puts '', 'Creating Permalink File...', ''
    #creates permalinks for q2a category links
    Category.find_each do |category|
      ccf = category.custom_fields

      if ccf && ccf["import_id"]
        url = category.parent_category ? "#{category.parent_category.slug}/#{category.slug}" : category.slug
        Permalink.create(url: url, category_id: category.id) rescue nil
      end
    end
  end

  def parse_timestamp(timestamp)
    Time.zone.at(@tz.utc_to_local(timestamp))
  end

  def mysql_query(sql)
    @client.query(sql, cache_rows: true)
  end

end

ImportScripts::Question2Answer.new.perform
