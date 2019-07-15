# frozen_string_literal: true

require "mysql2"

require File.expand_path(File.dirname(__FILE__) + "/base.rb")

# Call it like this:
#   RAILS_ENV=production bundle exec ruby script/import_scripts/xenforo.rb
class ImportScripts::XenForo < ImportScripts::Base

  XENFORO_DB = "xenforo_db"
  TABLE_PREFIX = "xf_"
  BATCH_SIZE = 1000
  ATTACHMENT_DIR = '/tmp/attachments'

  def initialize
    super
    @client = Mysql2::Client.new(
      host: "localhost",
      username: "root",
      password: "pa$$word",
      database: XENFORO_DB
    )

    @category_mappings = {}
    @prefix_as_category = false
  end

  def execute
    import_users
    import_categories
    import_posts
  end

  def import_users
    puts '', "creating users"

    total_count = mysql_query("SELECT count(*) count FROM #{TABLE_PREFIX}user WHERE user_state = 'valid' AND is_banned = 0;").first['count']

    batches(BATCH_SIZE) do |offset|
      results = mysql_query(
        "SELECT user_id id, username, email, custom_title title, register_date created_at,
                last_activity last_visit_time, user_group_id, is_moderator, is_admin, is_staff
         FROM #{TABLE_PREFIX}user
         WHERE user_state = 'valid' AND is_banned = 0
         LIMIT #{BATCH_SIZE}
         OFFSET #{offset};")

      break if results.size < 1

      next if all_records_exist? :users, results.map { |u| u["id"].to_i }

      create_users(results, total: total_count, offset: offset) do |user|
        next if user['username'].blank?
        { id: user['id'],
          email: user['email'],
          username: user['username'],
          title: user['title'],
          created_at: Time.zone.at(user['created_at']),
          last_seen_at: Time.zone.at(user['last_visit_time']),
          moderator: user['is_moderator'] == 1 || user['is_staff'] == 1,
          admin: user['is_admin'] == 1 }
      end
    end
  end

  def import_categories
    puts "", "importing categories..."

    categories = mysql_query("
        SELECT node_id id,
               title,
               description,
               parent_node_id,
               display_order
          FROM #{TABLE_PREFIX}node
      ORDER BY parent_node_id, display_order
      ").to_a

    top_level_categories = categories.select { |c| c["parent_node_id"] == 0 }

    create_categories(top_level_categories) do |c|
      {
        id: c['id'],
        name: c['title'],
        description: c['description'],
        position: c['display_order']
      }
    end

    top_level_category_ids = Set.new(top_level_categories.map { |c| c["id"] })

    subcategories = categories.select { |c| top_level_category_ids.include?(c["parent_node_id"]) }

    create_categories(subcategories) do |c|
      {
        id: c['id'],
        name: c['title'],
        description: c['description'],
        position: c['display_order'],
        parent_category_id: category_id_from_imported_category_id(c['parent_node_id'])
      }
    end

    subcategory_ids = Set.new(subcategories.map { |c| c['id'] })

    # deeper categories need to be tags
    categories.each do |c|
      next if c['parent_node_id'] == 0
      next if top_level_category_ids.include?(c['id'])
      next if subcategory_ids.include?(c['id'])

      # Find a subcategory for topics in this category
      parent = c
      while !parent.nil? && !subcategory_ids.include?(parent['id'])
        parent = categories.find { |subcat| subcat['id'] == parent['parent_node_id'] }
      end

      if parent
        tag_name = DiscourseTagging.clean_tag(c['title'])
        @category_mappings[c['id']] = {
          category_id: category_id_from_imported_category_id(parent['id']),
          tag: Tag.find_by_name(tag_name) || Tag.create(name: tag_name)
        }
      else
        puts '', "Couldn't find a category for #{c['id']} '#{c['title']}'!"
      end
    end
  end

  # This method is an alternative to import_categories.
  # It uses prefixes instead of nodes.
  def import_categories_from_thread_prefixes
    puts "", "importing categories..."

    categories = mysql_query("
                              SELECT prefix_id id
                              FROM #{TABLE_PREFIX}thread_prefix
                              ORDER BY prefix_id ASC
                            ").to_a

    create_categories(categories) do |category|
      {
        id: category["id"],
        name: "Category-#{category["id"]}"
      }
    end

    @prefix_as_category = true
  end

  def import_posts
    puts "", "creating topics and posts"

    total_count = mysql_query("SELECT count(*) count from #{TABLE_PREFIX}post").first["count"]

    posts_sql = "
        SELECT p.post_id id,
               t.thread_id topic_id,
               #{@prefix_as_category ? 't.prefix_id' : 't.node_id'} category_id,
               t.title title,
               t.first_post_id first_post_id,
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
      next if all_records_exist? :posts, results.map { |p| p['id'] }

      create_posts(results, total: total_count, offset: offset) do |m|
        skip = false
        mapped = {}

        mapped[:id] = m['id']
        mapped[:user_id] = user_id_from_imported_user_id(m['user_id']) || -1
        mapped[:raw] = process_xenforo_post(m['raw'], m['id'])
        mapped[:created_at] = Time.zone.at(m['created_at'])

        if m['id'] == m['first_post_id']
          if m['category_id'].to_i == 0 || m['category_id'].nil?
            mapped[:category] = SiteSetting.uncategorized_category_id
          else
            mapped[:category] = category_id_from_imported_category_id(m['category_id'].to_i) ||
              @category_mappings[m['category_id']].try(:[], :category_id)
          end
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

    # Apply tags
    batches(BATCH_SIZE) do |offset|
      results = mysql_query("#{posts_sql} OFFSET #{offset};").to_a
      break if results.size < 1

      results.each do |m|
        next unless m['id'] == m['first_post_id'] && m['category_id'].to_i > 0
        next unless tag = @category_mappings[m['category_id']].try(:[], :tag)
        next unless topic_mapping = topic_lookup_from_imported_post_id(m['id'])

        topic = Topic.find_by_id(topic_mapping[:topic_id])

        topic.tags = [tag] if topic
      end
    end

  end

  def process_xenforo_post(raw, import_id)
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
    #Fix for the error: xenforo.rb: 160: in `gsub!': invalid byte sequence in UTF-8 (ArgumentError)
    if ! s.valid_encoding?
      s = s.encode("UTF-16be", invalid: :replace, replace: "?").encode('UTF-8')
    end

    # Work around it for now:
    s.gsub!(/\[http(s)?:\/\/(www\.)?/, '[')

    # [QUOTE]...[/QUOTE]
    s.gsub!(/\[quote\](.+?)\[\/quote\]/im) { "\n> #{$1}\n" }

    # Nested Quotes
    s.gsub!(/(\[\/?QUOTE.*?\])/mi) { |q| "\n#{q}\n" }

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
    s.gsub!(/\[url="?(.+?)"?\](.+)\[\/url\]/i) { "[#{$2}](#{$1})" }

    # [IMG]...[/IMG]
    s.gsub!(/\[\/?img\]/i, "")

    # convert list tags to ul and list=1 tags to ol
    # (basically, we're only missing list=a here...)
    s.gsub!(/\[list\](.*?)\[\/list:u\]/m, '[ul]\1[/ul]')
    s.gsub!(/\[list=1\](.*?)\[\/list:o\]/m, '[ol]\1[/ol]')
    # convert *-tags to li-tags so bbcode-to-md can do its magic on phpBB's lists:
    s.gsub!(/\[\*\](.*?)\[\/\*:m\]/, '[li]\1[/li]')

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

    if Dir.exist? ATTACHMENT_DIR
      s = process_xf_attachments(:gallery, s)
      s = process_xf_attachments(:attachment, s)
    end

    s
  end

  def process_xf_attachments(xf_type, s)
    ids = Set.new
    ids.merge(s.scan(get_xf_regexp(xf_type)).map { |x| x[0].to_i })
    ids.each do |id|
      next unless id
      sql = get_xf_sql(xf_type, id).squish!
      results = mysql_query(sql)
      if results.size < 1
        # Strip attachment
        s.gsub!(get_xf_regexp(xf_type, id), '')
        STDERR.puts "#{xf_type.capitalize} id #{id} not found in source database. Stripping."
        next
      end
      original_filename = results.first['filename']
      result = results.first
      upload = import_xf_attachment(result['data_id'], result['file_hash'], result['user_id'], original_filename)
      next unless upload
      if upload.present? && upload.persisted?
        s.gsub!(get_xf_regexp(xf_type, id), @uploader.html_for_upload(upload, original_filename))
      else
        STDERR.puts "Could not find upload: #{upload.id}. Skipping attachment id #{id}"
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
      Regexp.new(/\[ATTACH(?>=\w+)?\]#{id ? id : '(\d+)'}\[\/ATTACH\]/i)
    end
  end

  def get_xf_sql(type, id)
    case type
    when :gallery
      <<-SQL
		SELECT m.media_id, m.media_title, a.attachment_id, a.data_id, d.filename, d.file_hash,d.user_id
		FROM xengallery_media as m
		INNER JOIN #{TABLE_PREFIX}attachment a on m.attachment_id = a.attachment_id
		INNER JOIN #{TABLE_PREFIX}attachment_data d on a.data_id = d.data_id
		WHERE media_id = #{id}
      SQL
    when :attachment
      <<-SQL
		SELECT a.attachment_id, a.data_id, d.filename, d.file_hash, d.user_id
		FROM #{TABLE_PREFIX}attachment AS a
		INNER JOIN #{TABLE_PREFIX}attachment_data d ON a.data_id = d.data_id
		WHERE attachment_id = #{id}
      SQL
    end
  end

  def mysql_query(sql)
    @client.query(sql, cache_rows: false)
  end
end

ImportScripts::XenForo.new.perform
