require "mysql2"

require File.expand_path(File.dirname(__FILE__) + "/base.rb")

class ImportScripts::Phorum < ImportScripts::Base

  PHORUM_DB = "piwik"
  TABLE_PREFIX = "pw_"
  BATCH_SIZE = 1000

  def initialize
    super

    @client = Mysql2::Client.new(
      host: "localhost",
      username: "root",
      password: "pa$$word",
      database: PHORUM_DB
    )
  end

  def execute
    import_users
    import_categories
    import_posts
  end

  def import_users
    puts '', "creating users"

    total_count = mysql_query("SELECT count(*) count FROM #{TABLE_PREFIX}users;").first['count']

    batches(BATCH_SIZE) do |offset|
      results = mysql_query(
        "SELECT user_id id, username, email, real_name name, date_added created_at,
                date_last_active last_seen_at, admin
         FROM #{TABLE_PREFIX}users
         WHERE #{TABLE_PREFIX}users.active = 1
         LIMIT #{BATCH_SIZE}
         OFFSET #{offset};")

      break if results.size < 1

      create_users(results, total: total_count, offset: offset) do |user|
        next if user['username'].blank?
        { id: user['id'],
          email: user['email'],
          username: user['username'],
          name: user['name'],
          created_at: Time.zone.at(user['created_at']),
          last_seen_at: Time.zone.at(user['last_seen_at']),
          admin: user['admin'] == 1 }
      end
    end
  end

  def import_categories
    puts "", "importing categories..."

    categories = mysql_query("
                              SELECT forum_id id, name, description, active
                              FROM #{TABLE_PREFIX}forums
                              ORDER BY forum_id ASC
                            ").to_a

    create_categories(categories) do |category|
      next if category['active'] == 0
      {
        id: category['id'],
        name: category["name"],
        description: category["description"]
      }
    end

    # uncomment below lines to create permalink
    # categories.each do |category|
    #   Permalink.create(url: "list.php?#{category['id']}", category_id: category_id_from_imported_category_id(category['id'].to_i))
    # end
  end

  def import_posts
    puts "", "creating topics and posts"

    total_count = mysql_query("SELECT count(*) count from #{TABLE_PREFIX}messages").first["count"]

    batches(BATCH_SIZE) do |offset|
      results = mysql_query("
        SELECT m.message_id id,
               m.parent_id,
               m.forum_id category_id,
               m.subject title,
               m.user_id user_id,
               m.body raw,
               m.closed closed,
               m.datestamp created_at
        FROM #{TABLE_PREFIX}messages m
        ORDER BY m.datestamp
        LIMIT #{BATCH_SIZE}
        OFFSET #{offset};
      ").to_a

      break if results.size < 1

      create_posts(results, total: total_count, offset: offset) do |m|
        skip = false
        mapped = {}

        mapped[:id] = m['id']
        mapped[:user_id] = user_id_from_imported_user_id(m['user_id']) || -1
        mapped[:raw] = process_raw_post(m['raw'], m['id'])
        mapped[:created_at] = Time.zone.at(m['created_at'])

        if m['parent_id'] == 0
          mapped[:category] = category_id_from_imported_category_id(m['category_id'].to_i)
          mapped[:title] = CGI.unescapeHTML(m['title'])
        else
          parent = topic_lookup_from_imported_post_id(m['parent_id'])
          if parent
            mapped[:topic_id] = parent[:topic_id]
          else
            puts "Parent post #{m['parent_id']} doesn't exist. Skipping #{m["id"]}: #{m["title"][0..40]}"
            skip = true
          end
        end

        skip ? nil : mapped
      end

      # uncomment below lines to create permalink
      # results.each do |post|
      #   if post['parent_id'] == 0
      #     topic = topic_lookup_from_imported_post_id(post['id'].to_i)
      #     Permalink.create(url: "read.php?#{post['category_id']},#{post['id']}", topic_id: topic[:topic_id].to_i)
      #   end
      # end
    end

  end

  def process_raw_post(raw, import_id)
    s = raw.dup

    # :) is encoded as <!-- s:) --><img src="{SMILIES_PATH}/icon_e_smile.gif" alt=":)" title="Smile" /><!-- s:) -->
    s.gsub!(/<!-- s(\S+) --><img (?:[^>]+) \/><!-- s(?:\S+) -->/, '\1')

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

    # [QUOTE]...[/QUOTE]
    s.gsub!(/\[quote\](.+?)\[\/quote\]/im) { "\n> #{$1}\n" }

    # [URL=...]...[/URL]
    s.gsub!(/\[url="?(.+?)"?\](.+)\[\/url\]/i) { "[#{$2}](#{$1})" }

    # [IMG]...[/IMG]
    s.gsub!(/\[\/?img\]/i, "")

    # convert list tags to ul and list=1 tags to ol
    # (basically, we're only missing list=a here...)
    s.gsub!(/\[list\](.*?)\[\/list\]/m, '[ul]\1[/ul]')
    s.gsub!(/\[list=1\](.*?)\[\/list\]/m, '[ol]\1[/ol]')
    # convert *-tags to li-tags so bbcode-to-md can do its magic on phpBB's lists:
    s.gsub!(/\[\*\](.*?)\n/, '[li]\1[/li]')

    # [CODE]...[/CODE]
    s.gsub!(/\[\/?code\]/i, "\n```\n")
    # [HIGHLIGHT]...[/HIGHLIGHT]
    s.gsub!(/\[\/?highlight\]/i, "\n```\n")

    # [YOUTUBE]<id>[/YOUTUBE]
    s.gsub!(/\[youtube\](.+?)\[\/youtube\]/i) { "\nhttps://www.youtube.com/watch?v=#{$1}\n" }

    # [youtube=425,350]id[/youtube]
    s.gsub!(/\[youtube="?(.+?)"?\](.+)\[\/youtube\]/i) { "\nhttps://www.youtube.com/watch?v=#{$2}\n" }

    # [MEDIA=youtube]id[/MEDIA]
    s.gsub!(/\[MEDIA=youtube\](.+?)\[\/MEDIA\]/i) { "\nhttps://www.youtube.com/watch?v=#{$1}\n" }

    # [ame="youtube_link"]title[/ame]
    s.gsub!(/\[ame="?(.+?)"?\](.+)\[\/ame\]/i) { "\n#{$1}\n" }

    # [VIDEO=youtube;<id>]...[/VIDEO]
    s.gsub!(/\[video=youtube;([^\]]+)\].*?\[\/video\]/i) { "\nhttps://www.youtube.com/watch?v=#{$1}\n" }

    # [USER=706]@username[/USER]
    s.gsub!(/\[user="?(.+?)"?\](.+)\[\/user\]/i) { $2 }

    # Remove the color tag
    s.gsub!(/\[color=[#a-z0-9]+\]/i, "")
    s.gsub!(/\[\/color\]/i, "")

    s.gsub!(/\[hr\]/i, "<hr>")

    s
  end

  def mysql_query(sql)
    @client.query(sql, cache_rows: false)
  end
end

ImportScripts::Phorum.new.perform
