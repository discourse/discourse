# frozen_string_literal: true

require "mysql2"

begin
  require "php_serialize" # https://github.com/jqr/php-serialize
rescue LoadError
  puts
  puts "php_serialize not found."
  puts "Add to Gemfile, like this: "
  puts
  puts "echo gem \\'php-serialize\\' >> Gemfile"
  puts "bundle install"
  exit
end

require File.expand_path(File.dirname(__FILE__) + "/base.rb")

# Call it like this:
#   RAILS_ENV=production bundle exec ruby script/import_scripts/xenforo.rb
class ImportScripts::XenForo < ImportScripts::Base
  XENFORO_DB = "xenforo_db"
  TABLE_PREFIX = "xf_"
  BATCH_SIZE = 1000
  ATTACHMENT_DIR = "/tmp/attachments"

  def initialize
    super
    @client =
      Mysql2::Client.new(
        host: "localhost",
        username: "root",
        password: "pa$$word",
        database: XENFORO_DB,
      )

    @category_mappings = {}
    @prefix_as_category = false
  end

  def execute
    import_users
    import_categories
    import_posts
    import_private_messages
    import_likes
  end

  def import_avatar(id, imported_user)
    filename = File.join(AVATAR_DIR, "l", (id / 1000).to_s, "#{id}.jpg")
    return nil unless File.exist?(filename)
    upload = create_upload(imported_user.id, filename, "avatar_#{id}")
    return if !upload.persisted?
    imported_user.create_user_avatar
    imported_user.user_avatar.update(custom_upload_id: upload.id)
    imported_user.update(uploaded_avatar_id: upload.id)
  end

  def import_users
    puts "", "creating users"

    total_count =
      mysql_query(
        "SELECT count(*) count FROM #{TABLE_PREFIX}user WHERE user_state = 'valid' AND is_banned = 0;",
      ).first[
        "count"
      ]

    batches(BATCH_SIZE) do |offset|
      results =
        mysql_query(
          "SELECT user_id id, username, email, custom_title title, register_date created_at,
                last_activity last_visit_time, user_group_id, is_moderator, is_admin, is_staff
         FROM #{TABLE_PREFIX}user
         WHERE user_state = 'valid' AND is_banned = 0
         LIMIT #{BATCH_SIZE}
         OFFSET #{offset};",
        )

      break if results.size < 1

      next if all_records_exist? :users, results.map { |u| u["id"].to_i }

      create_users(results, total: total_count, offset: offset) do |user|
        next if user["username"].blank?
        {
          id: user["id"],
          email: user["email"],
          username: user["username"],
          title: user["title"],
          created_at: Time.zone.at(user["created_at"]),
          last_seen_at: Time.zone.at(user["last_visit_time"]),
          moderator: user["is_moderator"] == 1 || user["is_staff"] == 1,
          admin: user["is_admin"] == 1,
          post_create_action: proc { |u| import_avatar(user["id"], u) },
        }
      end
    end
  end

  def import_categories
    puts "", "importing categories..."

    categories =
      mysql_query(
        "
        SELECT node_id id,
               title,
               description,
               parent_node_id,
               node_name,
               display_order
          FROM #{TABLE_PREFIX}node
      ORDER BY parent_node_id, display_order
      ",
      ).to_a

    top_level_categories = categories.select { |c| c["parent_node_id"] == 0 }

    create_categories(top_level_categories) do |c|
      {
        id: c["id"],
        name: c["title"],
        description: c["description"],
        position: c["display_order"],
        post_create_action:
          proc do |category|
            url = "board/#{c["node_name"]}"
            Permalink.find_or_create_by(url: url, category_id: category.id)
          end,
      }
    end

    top_level_category_ids = Set.new(top_level_categories.map { |c| c["id"] })

    subcategories = categories.select { |c| top_level_category_ids.include?(c["parent_node_id"]) }

    create_categories(subcategories) do |c|
      {
        id: c["id"],
        name: c["title"],
        description: c["description"],
        position: c["display_order"],
        parent_category_id: category_id_from_imported_category_id(c["parent_node_id"]),
        post_create_action:
          proc do |category|
            url = "board/#{c["node_name"]}"
            Permalink.find_or_create_by(url: url, category_id: category.id)
          end,
      }
    end

    subcategory_ids = Set.new(subcategories.map { |c| c["id"] })

    # deeper categories need to be tags
    categories.each do |c|
      next if c["parent_node_id"] == 0
      next if top_level_category_ids.include?(c["id"])
      next if subcategory_ids.include?(c["id"])

      # Find a subcategory for topics in this category
      parent = c
      while !parent.nil? && !subcategory_ids.include?(parent["id"])
        parent = categories.find { |subcat| subcat["id"] == parent["parent_node_id"] }
      end

      if parent
        tag_name = DiscourseTagging.clean_tag(c["title"])
        @category_mappings[c["id"]] = {
          category_id: category_id_from_imported_category_id(parent["id"]),
          tag: Tag.find_by_name(tag_name) || Tag.create(name: tag_name),
        }
      else
        puts "", "Couldn't find a category for #{c["id"]} '#{c["title"]}'!"
      end
    end
  end

  # This method is an alternative to import_categories.
  # It uses prefixes instead of nodes.
  def import_categories_from_thread_prefixes
    puts "", "importing categories..."

    categories =
      mysql_query(
        "
                              SELECT prefix_id id
                              FROM #{TABLE_PREFIX}thread_prefix
                              ORDER BY prefix_id ASC
                            ",
      ).to_a

    create_categories(categories) do |category|
      { id: category["id"], name: "Category-#{category["id"]}" }
    end

    @prefix_as_category = true
  end

  def import_likes
    puts "", "importing likes"
    total_count =
      mysql_query(
        "SELECT COUNT(*) AS count FROM #{TABLE_PREFIX}liked_content WHERE content_type = 'post'",
      ).first[
        "count"
      ]
    batches(BATCH_SIZE) do |offset|
      results =
        mysql_query(
          "SELECT like_id, content_id, like_user_id, like_date
         FROM #{TABLE_PREFIX}liked_content
         WHERE content_type = 'post'
         ORDER BY like_id
         LIMIT #{BATCH_SIZE}
         OFFSET #{offset};",
        )
      break if results.size < 1
      create_likes(results, total: total_count, offset: offset) do |row|
        {
          post_id: row["content_id"],
          user_id: row["like_user_id"],
          created_at: Time.zone.at(row["like_date"]),
        }
      end
    end
  end

  def import_posts
    puts "", "creating topics and posts"

    total_count = mysql_query("SELECT count(*) count from #{TABLE_PREFIX}post").first["count"]

    posts_sql =
      "
        SELECT p.post_id id,
               t.thread_id topic_id,
               #{@prefix_as_category ? "t.prefix_id" : "t.node_id"} category_id,
               t.title title,
               t.first_post_id first_post_id,
               t.view_count,
               p.user_id user_id,
               p.message raw,
               p.post_date created_at
        FROM #{TABLE_PREFIX}post p,
             #{TABLE_PREFIX}thread t
        WHERE p.thread_id = t.thread_id
        AND p.message_state = 'visible'
        AND t.discussion_state = 'visible'
        ORDER BY p.post_date
        LIMIT #{BATCH_SIZE}" # needs OFFSET

    batches(BATCH_SIZE) do |offset|
      results = mysql_query("#{posts_sql} OFFSET #{offset};").to_a

      break if results.size < 1
      next if all_records_exist? :posts, results.map { |p| p["id"] }

      create_posts(results, total: total_count, offset: offset) do |m|
        skip = false
        mapped = {}

        mapped[:id] = m["id"]
        mapped[:user_id] = user_id_from_imported_user_id(m["user_id"]) || -1
        mapped[:raw] = process_xenforo_post(m["raw"], m["id"])
        mapped[:created_at] = Time.zone.at(m["created_at"])

        if m["id"] == m["first_post_id"]
          if m["category_id"].to_i == 0 || m["category_id"].nil?
            mapped[:category] = SiteSetting.uncategorized_category_id
          else
            mapped[:category] = category_id_from_imported_category_id(m["category_id"].to_i) ||
              @category_mappings[m["category_id"]].try(:[], :category_id)
          end
          mapped[:title] = CGI.unescapeHTML(m["title"])
          mapped[:views] = m["view_count"]
          mapped[:post_create_action] = proc do |pp|
            Permalink.find_or_create_by(url: "threads/#{m["topic_id"]}", topic_id: pp.topic_id)
          end
        else
          parent = topic_lookup_from_imported_post_id(m["first_post_id"])
          if parent
            mapped[:topic_id] = parent[:topic_id]
          else
            puts "Parent post #{m["first_post_id"]} doesn't exist. Skipping #{m["id"]}: #{m["title"][0..40]}"
            skip = true
          end
        end

        skip ? nil : mapped
      end
    end

    # Apply tags
    batches(BATCH_SIZE) do |offset|
      results = mysql_query("#{posts_sql} OFFSET #{offset};").to_a
      break if results.size < 1

      results.each do |m|
        next unless m["id"] == m["first_post_id"] && m["category_id"].to_i > 0
        next unless tag = @category_mappings[m["category_id"]].try(:[], :tag)
        next unless topic_mapping = topic_lookup_from_imported_post_id(m["id"])

        topic = Topic.find_by_id(topic_mapping[:topic_id])

        topic.tags = [tag] if topic
      end
    end
  end

  def import_private_messages
    puts "", "importing private messages..."
    post_count = mysql_query("SELECT COUNT(*) count FROM xf_conversation_message").first["count"]
    batches(BATCH_SIZE) do |offset|
      posts = mysql_query <<-SQL
        SELECT c.conversation_id, c.recipients, c.title, m.message, m.user_id, m.message_date, m.message_id, IF(c.first_message_id != m.message_id, c.first_message_id, 0) as topic_id
        FROM xf_conversation_master c
        LEFT JOIN xf_conversation_message m ON m.conversation_id = c.conversation_id
        ORDER BY c.conversation_id, m.message_id
        LIMIT #{BATCH_SIZE}
        OFFSET #{offset}
      SQL
      break if posts.size < 1
      next if all_records_exist? :posts, posts.map { |post| "pm_#{post["message_id"]}" }
      create_posts(posts, total: post_count, offset: offset) do |post|
        user_id = user_id_from_imported_user_id(post["user_id"]) || Discourse::SYSTEM_USER_ID
        title = post["title"]
        message_id = "pm_#{post["message_id"]}"
        raw = process_xenforo_post(post["message"], 0)
        if raw.present?
          msg = {
            id: message_id,
            user_id: user_id,
            raw: raw,
            created_at: Time.zone.at(post["message_date"].to_i),
            import_mode: true,
          }
          if post["topic_id"] <= 0
            topic_id = post["topic_id"]
            if t = topic_lookup_from_imported_post_id("pm_#{topic_id}")
              msg[:topic_id] = t[:topic_id]
            else
              puts "Topic ID #{topic_id} not found, skipping post #{post["message_id"]} from #{post["user_id"]}"
              next
            end
          else
            msg[:title] = post["title"]
            msg[:archetype] = Archetype.private_message
            to_user_array = PHP.unserialize(post["recipients"])
            if to_user_array.size > 0
              discourse_user_ids = to_user_array.keys.map { |id| user_id_from_imported_user_id(id) }
              usernames = User.where(id: [discourse_user_ids]).pluck(:username)
              msg[:target_usernames] = usernames.join(",")
            end
          end
          msg
        else
          puts "Empty message, skipping post #{post["message_id"]}"
          next
        end
      end
    end
  end

  def process_xenforo_post(raw, import_id)
    s = raw.dup

    # :) is encoded as <!-- s:) --><img src="{SMILIES_PATH}/icon_e_smile.gif" alt=":)" title="Smile" /><!-- s:) -->
    s.gsub!(%r{<!-- s(\S+) --><img (?:[^>]+) /><!-- s(?:\S+) -->}, '\1')

    # Some links look like this: <!-- m --><a class="postlink" href="http://www.onegameamonth.com">http://www.onegameamonth.com</a><!-- m -->
    s.gsub!(%r{<!-- \w --><a(?:.+)href="(\S+)"(?:.*)>(.+)</a><!-- \w -->}, '[\2](\1)')

    # Many phpbb bbcode tags have a hash attached to them. Examples:
    #   [url=https&#58;//google&#46;com:1qh1i7ky]click here[/url:1qh1i7ky]
    #   [quote=&quot;cybereality&quot;:b0wtlzex]Some text.[/quote:b0wtlzex]
    s.gsub!(/:(?:\w{8})\]/, "]")

    # Remove mybb video tags.
    s.gsub!(%r{(^\[video=.*?\])|(\[/video\]$)}, "")

    s = CGI.unescapeHTML(s)

    # phpBB shortens link text like this, which breaks our markdown processing:
    #   [http://answers.yahoo.com/question/index ... 223AAkkPli](http://answers.yahoo.com/question/index?qid=20070920134223AAkkPli)
    #
    #Fix for the error: xenforo.rb: 160: in `gsub!': invalid byte sequence in UTF-8 (ArgumentError)
    s = s.encode("UTF-16be", invalid: :replace, replace: "?").encode("UTF-8") if !s.valid_encoding?

    # Work around it for now:
    s.gsub!(%r{\[http(s)?://(www\.)?}, "[")

    # [QUOTE]...[/QUOTE]
    s.gsub!(%r{\[quote\](.+?)\[/quote\]}im) { "\n> #{$1}\n" }

    # Nested Quotes
    s.gsub!(%r{(\[/?QUOTE.*?\])}mi) { |q| "\n#{q}\n" }

    # [QUOTE="username, post: 28662, member: 1283"]
    s.gsub!(/\[quote="(\w+), post: (\d*), member: (\d*)"\]/i) do
      username, imported_post_id, _imported_user_id = $1, $2, $3

      topic_mapping = topic_lookup_from_imported_post_id(imported_post_id)

      if topic_mapping
        "\n[quote=\"#{username}, post:#{topic_mapping[:post_number]}, topic:#{topic_mapping[:topic_id]}\"]\n"
      else
        "\n[quote=\"#{username}\"]\n"
      end
    end

    # [URL=...]...[/URL]
    s.gsub!(%r{\[url="?(.+?)"?\](.+?)\[/url\]}i) { "[#{$2}](#{$1})" }

    # [URL]...[/URL]
    s.gsub!(%r{\[url\](.+?)\[/url\]}i) { " #{$1} " }

    # [IMG]...[/IMG]
    s.gsub!(%r{\[/?img\]}i, "")

    # convert list tags to ul and list=1 tags to ol
    # (basically, we're only missing list=a here...)
    s.gsub!(%r{\[list\](.*?)\[/list\]}im, '[ul]\1[/ul]')
    s.gsub!(%r{\[list=1\](.*?)\[/list\]}im, '[ol]\1[/ol]')
    s.gsub!(%r{\[list\](.*?)\[/list:u\]}im, '[ul]\1[/ul]')
    s.gsub!(%r{\[list=1\](.*?)\[/list:o\]}im, '[ol]\1[/ol]')

    # convert *-tags to li-tags so bbcode-to-md can do its magic on phpBB's lists:
    s.gsub!(/\[\*\]\n/, "")
    s.gsub!(%r{\[\*\](.*?)\[/\*:m\]}, '[li]\1[/li]')
    s.gsub!(/\[\*\](.*?)\n/, '[li]\1[/li]')
    s.gsub!(/\[\*=1\]/, "")

    # [YOUTUBE]<id>[/YOUTUBE]
    s.gsub!(%r{\[youtube\](.+?)\[/youtube\]}i) { "\nhttps://www.youtube.com/watch?v=#{$1}\n" }

    # [youtube=425,350]id[/youtube]
    s.gsub!(%r{\[youtube="?(.+?)"?\](.+?)\[/youtube\]}i) do
      "\nhttps://www.youtube.com/watch?v=#{$2}\n"
    end

    # [MEDIA=youtube]id[/MEDIA]
    s.gsub!(%r{\[MEDIA=youtube\](.+?)\[/MEDIA\]}i) { "\nhttps://www.youtube.com/watch?v=#{$1}\n" }

    # [ame="youtube_link"]title[/ame]
    s.gsub!(%r{\[ame="?(.+?)"?\](.+?)\[/ame\]}i) { "\n#{$1}\n" }

    # [VIDEO=youtube;<id>]...[/VIDEO]
    s.gsub!(%r{\[video=youtube;([^\]]+)\].*?\[/video\]}i) do
      "\nhttps://www.youtube.com/watch?v=#{$1}\n"
    end

    # [USER=706]@username[/USER]
    s.gsub!(%r{\[user="?(.+?)"?\](.+?)\[/user\]}i) { $2 }

    # Remove the color tag
    s.gsub!(/\[color=[#a-z0-9]+\]/i, "")
    s.gsub!(%r{\[/color\]}i, "")

    if Dir.exist? ATTACHMENT_DIR
      s = process_xf_attachments(:gallery, s, import_id)
      s = process_xf_attachments(:attachment, s, import_id)
    end

    s
  end

  def process_xf_attachments(xf_type, s, import_id)
    ids = Set.new
    ids.merge(s.scan(get_xf_regexp(xf_type)).map { |x| x[0].to_i })

    # not all attachments have an [ATTACH=] tag so we need to get the other ID's from the xf_attachment table
    if xf_type == :attachment && import_id > 0
      sql =
        "SELECT attachment_id FROM #{TABLE_PREFIX}attachment WHERE content_id=#{import_id} and content_type='post';"
      ids.merge(mysql_query(sql).to_a.map { |v| v["attachment_id"].to_i })
    end

    ids.each do |id|
      next unless id
      sql = get_xf_sql(xf_type, id).dup.squish!
      results = mysql_query(sql)
      if results.size < 1
        # Strip attachment
        s.gsub!(get_xf_regexp(xf_type, id), "")
        STDERR.puts "#{xf_type.capitalize} id #{id} not found in source database. Stripping."
        next
      end
      original_filename = results.first["filename"]
      result = results.first
      upload =
        import_xf_attachment(
          result["data_id"],
          result["file_hash"],
          result["user_id"],
          original_filename,
        )
      if upload && upload.present? && upload.persisted?
        html = @uploader.html_for_upload(upload, original_filename)
        s = s + "\n\n#{html}\n\n" unless s.gsub!(get_xf_regexp(xf_type, id), html)
      else
        STDERR.puts "Could not process upload: #{original_filename}. Skipping attachment id #{id}"
      end
    end
    s
  end

  def import_xf_attachment(data_id, file_hash, owner_id, original_filename)
    current_filename = "#{data_id}-#{file_hash}.data"
    path = Pathname.new(ATTACHMENT_DIR + "/#{data_id / 1000}/#{current_filename}")
    new_path = path.dirname + original_filename
    upload = nil
    if File.exist? path
      FileUtils.cp path, new_path
      upload = @uploader.create_upload owner_id, new_path, original_filename
      FileUtils.rm new_path
    else
      STDERR.puts "Could not find file #{path}. Skipping attachment id #{data_id}"
    end
    upload
  end

  def get_xf_regexp(type, id = nil)
    case type
    when :gallery
      Regexp.new(/\[GALLERY=media,\s#{id ? id : '(\d+)'}\].+?\]/i)
    when :attachment
      Regexp.new(%r{\[ATTACH(?>=\w+)?\]#{id ? id : '(\d+)'}\[/ATTACH\]}i)
    end
  end

  def get_xf_sql(type, id)
    case type
    when :gallery
      <<-SQL
        SELECT m.media_id, m.media_title, a.attachment_id, a.data_id, d.filename, d.file_hash, d.user_id
        FROM xengallery_media AS m
        INNER JOIN #{TABLE_PREFIX}attachment a ON (m.attachment_id = a.attachment_id AND a.content_type = 'xengallery_media')
        INNER JOIN #{TABLE_PREFIX}attachment_data d ON a.data_id = d.data_id
        WHERE media_id = #{id}
      SQL
    when :attachment
      <<-SQL
        SELECT a.attachment_id, a.data_id, d.filename, d.file_hash, d.user_id
        FROM #{TABLE_PREFIX}attachment AS a
        INNER JOIN #{TABLE_PREFIX}attachment_data d ON a.data_id = d.data_id
        WHERE attachment_id = #{id}
        AND content_type = 'post'
      SQL
    end
  end

  def mysql_query(sql)
    @client.query(sql, cache_rows: false)
  end
end

ImportScripts::XenForo.new.perform
