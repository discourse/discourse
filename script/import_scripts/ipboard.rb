# coding: utf-8
require "mysql2"
require File.expand_path(File.dirname(__FILE__) + "/base.rb")
require 'htmlentities'
begin
  require 'reverse_markdown' # https://github.com/jqr/php-serialize
rescue LoadError
  puts
  puts 'reverse_markdown not found.'
  puts 'Add to Gemfile, like this: '
  puts
  puts "echo gem \\'reverse_markdown\\' >> Gemfile"
  puts "bundle install"
  exit
end

# Before running this script, paste these lines into your shell,
# then use arrow keys to edit the values
=begin
export DB_HOST="localhost"
export DB_NAME="ipboard"
export DB_PW="ipboard"
export DB_USER="ipboard"
export TABLE_PREFIX="ipb_"
export IMPORT_AFTER="1970-01-01"
export UPLOADS="http://example.com/uploads"
export URL="http://example.com/"
export AVATARS_DIR="/imports/avatars/"
export USERDIR="user"
=end

class ImportScripts::IpboardSQL < ImportScripts::Base

  DB_HOST ||= ENV['DB_HOST'] || "localhost"
  DB_NAME ||= ENV['DB_NAME'] || "ipboard"
  DB_PW ||= ENV['DB_PW'] || "ipboard"
  DB_USER ||= ENV['DB_USER'] || "ipboard"
  TABLE_PREFIX ||= ENV['TABLE_PREFIX'] || "ipb_"
  IMPORT_AFTER ||= ENV['IMPORT_AFTER'] || "1970-01-01"
  UPLOADS ||= ENV['UPLOADS'] || "http://UPLOADS+LOCATION+IS+NOT+SET/uploads"
  USERDIR ||= ENV['USERDIR'] || "user"
  URL ||= ENV['URL'] || "https://forum.example.com"
  AVATARS_DIR ||= ENV['AVATARS_DIR'] || '/home/pfaffman/data/example.com/avatars/'
  BATCH_SIZE = 1000
  ID_FIRST = true
  QUIET = true
  DEBUG = false
  GALLERY_CAT_ID = 1234567
  GALLERY_CAT_NAME = 'galeria'
  EMO_DIR ||= ENV['EMO_DIR'] || "default"
  OLD_FORMAT = false
  if OLD_FORMAT
    MEMBERS_TABLE = "#{TABLE_PREFIX}core_members"
    FORUMS_TABLE =  "#{TABLE_PREFIX}forums_forums"
    POSTS_TABLE = "#{TABLE_PREFIX}forums_posts"
    TOPICS_TABLE = "#{TABLE_PREFIX}forums_topics"
  else
    MEMBERS_TABLE = "#{TABLE_PREFIX}members"
    FORUMS_TABLE = "#{TABLE_PREFIX}forums"
    POSTS_TABLE = "#{TABLE_PREFIX}posts"
    TOPICS_TABLE = "#{TABLE_PREFIX}topics"
    GROUPS_TABLE = "#{TABLE_PREFIX}groups"
    PROFILE_TABLE = "#{TABLE_PREFIX}profile_portal"
    ATTACHMENT_TABLE = "#{TABLE_PREFIX}attachments"
  end

  # TODO: replace ipb_ with TABLE_PREFIX

  #################
  # Site settings #
  #################
  # don't send any emails
  SiteSetting.disable_emails = "non-staff"
  # don't send digests (so you can enable email without users noticing)
  SiteSetting.disable_digest_emails = true
  # keep site and users private
  SiteSetting.login_required = true
  SiteSetting.hide_user_profiles_from_public = true
  # if site is made available, don't let it get indexed
  SiteSetting.allow_index_in_robots_txt = false
  # don't notify users when images in their posts get downloaded
  SiteSetting.disable_edit_notifications = true
  #  SiteSetting.force_hostname='forum.dev1dev.com'
  SiteSetting.title = "IPB Import"

  if ID_FIRST
    # TODO figure this out
    puts "WARNING: permalink_normalizations not set!!!"
    sleep 1
  #raw = "[ORIGINAL POST](#{URL}/topic/#{id}-#{slug})\n\n" + raw
  #SiteSetting.permalink_normalizations='/topic/(.*t)\?.*/\1'
  else
    # remove stuff after a "?" and work for urls that end in .html
    SiteSetting.permalink_normalizations = '/(.*t)[?.].*/\1'
    #raw = "[ORIGINAL POST](#{URL}/#{slug}-#{id}t)\n\n" + raw
  end

  def initialize
    if IMPORT_AFTER > "1970-01-01"
      print_warning("Importing data after #{IMPORT_AFTER}")
    end

    super
    @htmlentities = HTMLEntities.new
    begin
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
Cannot log in to database.

Hostname: #{DB_HOST}
Username: #{DB_USER}
Password: #{DB_PW}
database: #{DB_NAME}

You should set these variables:

export DB_HOST="localhost"
export DB_NAME="ipboard"
export DB_PW="ipboard"
export DB_USER="ipboard"
export TABLE_PREFIX="ipb_"
export IMPORT_AFTER="1970-01-01"
export URL="http://example.com"
export UPLOADS=
export USERDIR="user"

Exiting.
EOM
      exit
    end
  end

  def execute
    import_users
    import_categories
    import_topics
    import_posts
    import_private_messages

    # not supported import_image_categories
    # NOT SUPPORTED import_gallery_topics
    update_tl0
    create_permalinks

  end

  def import_users
    puts '', "creating users"

    total_count = mysql_query("SELECT count(*) count FROM #{MEMBERS_TABLE}
         WHERE last_activity > UNIX_TIMESTAMP(STR_TO_DATE('#{IMPORT_AFTER}', '%Y-%m-%d'));").first['count']

    batches(BATCH_SIZE) do |offset|
      #notes: no location, url,
      results = mysql_query("
             SELECT member_id id,
                name username,
                member_group_id usergroup,
                email,
                pp_thumb_photo avatar_url,
#                pp_main_photo avatar_url,
#                avatar_location avatar_url,
# TODO consider joining ibf_profile_portal.avatar_location and avatar_type
                FROM_UNIXTIME(joined) created_at,
                FROM_UNIXTIME(last_activity) last_seen_at,
                ip_address registration_ip_address,
                member_banned banned,
                bday_year, bday_month, bday_day,
                g_title member_type,
                last_visit last_seen_at
     	        FROM #{MEMBERS_TABLE}, #{PROFILE_TABLE}, #{GROUPS_TABLE}
       	        WHERE last_activity > UNIX_TIMESTAMP(STR_TO_DATE('#{IMPORT_AFTER}', '%Y-%m-%d'))
                AND member_id=pp_member_id
                AND member_group_id = g_id
                order by member_id ASC
                LIMIT #{BATCH_SIZE}
                OFFSET #{offset};")

      break if results.size < 1

      next if all_records_exist? :users, results.map { |u| u['id'].to_i }

      create_users(results, total: total_count, offset: offset) do |user|
        next if user['email'].blank?
        next if user['username'].blank?
        next if @lookup.user_id_from_imported_user_id(user['id'])

        birthday = Date.parse("#{user['bday_year']}-#{user['bday_month']}-#{user['bday_day']}") rescue nil
        # TODO: what about timezones?
        next if user['id'] == 0
        { id: user['id'],
          email: user['email'],
          username: user['username'],
          avatar_url: user['avatar_url'],
          title: user['member_type'],
          created_at: user['created_at'] == nil ? 0 : Time.zone.at(user['created_at']),
          # bio_raw: user['bio_raw'],
          registration_ip_address: user['registration_ip_address'],
          # birthday: birthday,
          last_seen_at: user['last_seen_at'] == nil ? 0 : Time.zone.at(user['last_seen_at']),
          admin: /^Admin/.match(user['member_type']) ? true : false,
          moderator: /^MOD/.match(user['member_type']) ? true : false,
          post_create_action: proc do |newuser|
            if user['avatar_url'] && user['avatar_url'].length > 0
              photo_path = AVATARS_DIR + user['avatar_url']
              if File.exists?(photo_path)
                begin
                  upload = create_upload(newuser.id, photo_path, File.basename(photo_path))
                  if upload && upload.persisted?
                    newuser.import_mode = false
                    newuser.create_user_avatar
                    newuser.import_mode = true
                    newuser.user_avatar.update(custom_upload_id: upload.id)
                    newuser.update(uploaded_avatar_id: upload.id)
                  else
                    puts "Error: Upload did not persist for #{photo_path}!"
                  end
                rescue SystemCallError => err
                  puts "Could not import avatar #{photo_path}: #{err.message}"
                end
              else
                puts "avatar file not found at #{photo_path}"
              end
            end
            if user['banned'] != 0
              suspend_user(newuser)
            end
          end
        }
      end
    end
  end

  def suspend_user(user)
    user.suspended_at = Time.now
    user.suspended_till = 200.years.from_now
    ban_reason = 'Account deactivated by administrator'

    user_option = user.user_option
    user_option.email_digests = false
    user_option.email_private_messages = false
    user_option.email_direct = false
    user_option.email_always = false
    user_option.save!

    if user.save
      StaffActionLogger.new(Discourse.system_user).log_user_suspend(user, ban_reason)
    else
      puts "Failed to suspend user #{user.username}. #{user.errors.try(:full_messages).try(:inspect)}"
    end
  end

  def file_full_path(relpath)
    File.join JSON_FILES_DIR, relpath.split("?").first
  end

  def import_image_categories
    puts "", "importing image categories..."

    categories = mysql_query("
                  SELECT category_id id,
                         category_name_seo name,
	                 category_parent_id as parent_id
                  FROM #{TABLE_PREFIX}gallery_categories
                  ORDER BY id ASC
                            ").to_a

    category_names = mysql_query("
                  SELECT DISTINCT word_key, word_default title
                  FROM #{TABLE_PREFIX}core_sys_lang_words where word_app='gallery'
                  AND word_key REGEXP 'gallery_category_[0-9]+$'
                  ORDER BY word_key ASC
                            ").to_a

    cat_map = {}
    puts "Creating gallery_cat_map"
    category_names.each do |name|
      title = name['title']
      word_key = name['word_key']
      puts "Processing #{word_key}: #{title}"
      id = word_key.gsub('gallery_category_', '')
      next if cat_map[id]
      cat_map[id] = cat_map.has_value?(title) ? title + " " + id : title
      puts "#{id} => #{cat_map[id]}"
    end

    params = { id: GALLERY_CAT_ID,
               name: GALLERY_CAT_NAME }
    create_category(params, params[:id])

    create_categories(categories) do |category|
      id = (category['id']).to_s
      name = CGI.unescapeHTML(cat_map[id])
      {
        id: id + 'gal',
        name: name,
        parent_category_id: @lookup.category_id_from_imported_category_id(GALLERY_CAT_ID),
        color: random_category_color
      }
    end
  end

  def import_categories
    puts "", "importing categories..."

    categories = mysql_query("
                  SELECT id,
                         name name,
	                 parent_id as parent_id
                  FROM #{FORUMS_TABLE}
                  ORDER BY parent_id ASC
                            ").to_a

    top_level_categories = categories.select { |c| c["parent.id"] == -1 }

    create_categories(top_level_categories) do |category|
      id = category['id'].to_s
      name = category['name']
      {
        id: id,
        name: name,
      }
    end

    children_categories = categories.select { |c| c["parent.id"] != -1 }
    create_categories(children_categories) do |category|
      id = category['id'].to_s
      name = category['name']
      {
        id: id,
        name: name,
        parent_category_id: @lookup.category_id_from_imported_category_id(category['parent_id']),
        color: random_category_color
      }
    end
  end

  def import_topics
    puts "", "importing topics..."

    total_count = mysql_query("SELECT count(*) count FROM #{POSTS_TABLE}
       	        WHERE post_date > UNIX_TIMESTAMP(STR_TO_DATE('#{IMPORT_AFTER}', '%Y-%m-%d'))
                AND new_topic=1;")
      .first['count']

    batches(BATCH_SIZE) do |offset|
      discussions = mysql_query(<<-SQL
            SELECT #{TOPICS_TABLE}.tid tid,
               #{TOPICS_TABLE}.forum_id category,
               #{POSTS_TABLE}.pid pid,
               #{TOPICS_TABLE}.title title,
               #{TOPICS_TABLE}.pinned pinned,
               #{POSTS_TABLE}.post raw,
               #{TOPICS_TABLE}.title_seo as slug,
               FROM_UNIXTIME(#{POSTS_TABLE}.post_date) created_at,
               #{POSTS_TABLE}.author_id user_id
            FROM #{POSTS_TABLE}, #{TOPICS_TABLE}
            WHERE #{POSTS_TABLE}.topic_id = #{TOPICS_TABLE}.tid
            AND #{POSTS_TABLE}.new_topic = 1
            AND #{POSTS_TABLE}.post_date > UNIX_TIMESTAMP(STR_TO_DATE('#{IMPORT_AFTER}', '%Y-%m-%d'))
            ORDER BY #{POSTS_TABLE}.post_date ASC
            LIMIT #{BATCH_SIZE}
            OFFSET #{offset}
            SQL
                               )

      break if discussions.size < 1
      next if all_records_exist? :posts, discussions.map { |t| "discussion#" + t['tid'].to_s }

      create_posts(discussions, total: total_count, offset: offset) do |discussion|
        slug = discussion['slug']
        id = discussion['tid']
        raw = clean_up(discussion['raw'])
        {
          id: "discussion#" + discussion['tid'].to_s,
          user_id: user_id_from_imported_user_id(discussion['user_id']) || Discourse::SYSTEM_USER_ID,
          title: CGI.unescapeHTML(discussion['title']),
          category: category_id_from_imported_category_id(discussion['category'].to_s),
          raw: raw,
          pinned_at: discussion['pinned'].to_i == 1 ? Time.zone.at(discussion['created_at']) : nil,
          created_at: Time.zone.at(discussion['created_at']),
        }
      end
    end
  end

  def array_from_members_string(invited_members = 'a:3:{i:0;i:22629;i:1;i:21837;i:2;i:22234;}')
    out = []
    count_regex = /a:(\d)+:/
    count = count_regex.match(invited_members)[1]
    rest = invited_members.sub(count_regex, "")
    i_regex = /i:\d+;i:(\d+);/
    while m = i_regex.match(rest)
      i = m[1]
      rest.sub!(i_regex, "")
      puts "i: #{i}, #{rest}"
      out += [ i.to_i ]
    end
    out
  end

  def import_private_messages
    puts "", "importing private messages..."

    topic_count = mysql_query("SELECT COUNT(msg_id) count FROM #{TABLE_PREFIX}message_posts").first["count"]

    last_private_message_topic_id = -1

    batches(BATCH_SIZE) do |offset|
      private_messages = mysql_query(<<-SQL
          SELECT msg_id pmtextid,
                 msg_topic_id topic_id,
                 msg_author_id fromuserid,
                 mt_title title,
                 msg_post message,
                 mt_invited_members touserarray,
                 mt_to_member_id to_user_id,
                 msg_is_first_post first_post,
                 msg_date dateline
            FROM #{TABLE_PREFIX}message_topics, #{TABLE_PREFIX}message_posts
           WHERE msg_topic_id = mt_id
             AND msg_date > UNIX_TIMESTAMP(STR_TO_DATE('#{IMPORT_AFTER}', '%Y-%m-%d'))
        ORDER BY msg_topic_id, msg_id
           LIMIT #{BATCH_SIZE}
          OFFSET #{offset}
      SQL
                                    )

      puts "Processing #{private_messages.count} messages"
      break if private_messages.count < 1
      puts "Processing . . . "
      private_messages = private_messages.reject { |pm| @lookup.post_already_imported?("pm-#{pm['pmtextid']}") }

      title_username_of_pm_first_post = {}

      create_posts(private_messages, total: topic_count, offset: offset) do |m|
        skip = false
        mapped = {}

        mapped[:id] = "pm-#{m['pmtextid']}"
        mapped[:user_id] = user_id_from_imported_user_id(m['fromuserid']) || Discourse::SYSTEM_USER_ID
        mapped[:raw] = clean_up(m['message']) rescue nil
        mapped[:created_at] = Time.zone.at(m['dateline'])
        title = @htmlentities.decode(m['title']).strip[0...255]
        topic_id = nil

        next if mapped[:raw].blank?

        # users who are part of this private message.
        target_usernames = []
        target_userids = []
        begin
          to_user_array = [ m['to_user_id'] ] + array_from_members_string(m['touserarray'])
        rescue
          puts "#{m['pmtextid']} -- #{m['touserarray']}"
          skip = true
        end

        begin
          to_user_array.each do |to_user|
            user_id = user_id_from_imported_user_id(to_user)
            username = User.find_by(id: user_id).try(:username)
            target_userids << user_id || Discourse::SYSTEM_USER_ID
            target_usernames << username if username
            if user_id
              puts "Found user: #{to_user} -- #{user_id} -- #{username}"
            else
              puts "Can't find user: #{to_user}"
            end
          end
        rescue
          puts "skipping pm-#{m['pmtextid']} `to_user_array` is broken -- #{to_user_array.inspect}"
          skip = true
        end

        participants = target_userids
        participants << mapped[:user_id]
        begin
          participants.sort!
        rescue
          puts "one of the participant's id is nil -- #{participants.inspect}"
        end

        if last_private_message_topic_id != m['topic_id']
          last_private_message_topic_id = m['topic_id']
          puts "New message: #{m['topic_id']}: #{title} from #{m['fromuserid']} (#{mapped[:user_id]})" unless QUIET
          # topic post message
          topic_id = m['topic_id']
          mapped[:title] = title
          mapped[:archetype] = Archetype.private_message
          mapped[:target_usernames] = target_usernames.join(',')
          if mapped[:target_usernames].size < 1 # pm with yourself?
            # skip = true
            mapped[:target_usernames] = "system"
            puts "pm-#{m['pmtextid']} has no target (#{m['touserarray']})"
          end
        else # reply
          topic_id = topic_lookup_from_imported_post_id("pm-#{topic_id}")
          if !topic_id
            skip = true
          end
          mapped[:topic_id] = topic_id
          puts "Reply message #{topic_id}: #{m['topic_id']}: from #{m['fromuserid']} (#{mapped[:user_id]})"  unless QUIET
        end
        #        puts "#{target_usernames} -- #{mapped[:target_usernames]}"
        #        puts "Adding #{mapped}"
        skip ? nil : mapped
        #        puts "#{'-'*50}> added"
      end
    end
  end

  def import_gallery_topics
    # pfaffman: I'm not clear whether this is an IPBoard thing or from some other system
    puts "", "importing gallery albums..."

    gallery_count = 0
    total_count = mysql_query("SELECT count(*) count FROM #{TABLE_PREFIX}gallery_images
                ;")
      .first['count']

    # NOTE: for imports with huge numbers of galleries, this needs to use limits

    batches(BATCH_SIZE) do |offset|
      # galleries = mysql_query(<<-SQL

      #       SELECT #{TABLE_PREFIX}gallery_albums.album_id tid,
      #           #{TABLE_PREFIX}gallery_albums.album_category_id category,
      #           #{TABLE_PREFIX}gallery_albums.album_owner_id user_id,
      #           #{TABLE_PREFIX}gallery_albums.album_name title,
      #           #{TABLE_PREFIX}gallery_albums.album_description raw,
      #           #{TABLE_PREFIX}gallery_albums.album_type,
      #            FROM_UNIXTIME(#{TABLE_PREFIX}gallery_albums.album_last_img_date) created_at
      #       FROM #{TABLE_PREFIX}gallery_albums
      #       ORDER BY #{TABLE_PREFIX}gallery_albums.album_id ASC

      #       SQL
      #                        )

      images = mysql_query(<<-SQL

            SELECT #{TABLE_PREFIX}gallery_albums.album_id tid,
                #{TABLE_PREFIX}gallery_albums.album_category_id category,
                #{TABLE_PREFIX}gallery_albums.album_owner_id user_id,
                #{TABLE_PREFIX}gallery_albums.album_name title,
                #{TABLE_PREFIX}gallery_albums.album_description raw,
                #{TABLE_PREFIX}gallery_albums.album_type,
                #{TABLE_PREFIX}gallery_images.image_caption caption,
                #{TABLE_PREFIX}gallery_images.image_description description,
                #{TABLE_PREFIX}gallery_images.image_masked_file_name masked,
                #{TABLE_PREFIX}gallery_images.image_id image_id,
                #{TABLE_PREFIX}gallery_images.image_medium_file_name medium,
                #{TABLE_PREFIX}gallery_images.image_original_file_name orig,
                 FROM_UNIXTIME(#{TABLE_PREFIX}gallery_albums.album_last_img_date) created_at,
                #{TABLE_PREFIX}gallery_images.image_file_name filename
                FROM #{TABLE_PREFIX}gallery_albums, #{TABLE_PREFIX}gallery_images
                WHERE  #{TABLE_PREFIX}gallery_images.image_album_id=#{TABLE_PREFIX}gallery_albums.album_id
            ORDER BY #{TABLE_PREFIX}gallery_albums.album_id, image_date DESC
            LIMIT #{BATCH_SIZE}
            OFFSET #{offset};

            SQL

                          )

      break if images.size < 1
      next if all_records_exist? :posts, images.map { |t| "gallery#" + t['tid'].to_s + t['image_id'].to_s }

      last_id = images.first['tid']
      raw = "Gallery ID: #{last_id}\n" + clean_up(images.first['raw'])
      raw += "#{clean_up(images.first['description'])}\n"
      last_gallery = images.first.dup
      create_posts(images, total: total_count, offset: offset) do |gallery|
        id = gallery['tid'].to_i
        #puts "ID: #{id}, last_id: #{last_id}, image: #{gallery['image_id']}"
        if id == last_id
          raw += "### #{gallery['caption']}\n"
          raw += "#{UPLOADS}/#{gallery['orig']}\n"
          last_gallery = gallery.dup
          next
        else
          insert_raw = raw.dup
          last_id = gallery['tid']
          if DEBUG
            raw = "Gallery ID: #{last_id}\n" + clean_up(gallery['raw'])
            raw += "Cat: #{last_gallery['category'].to_s} - #{category_id_from_imported_category_id(last_gallery['category'].to_s + 'gal')}"
          end
          raw += "#{clean_up(images.first['description'])}\n"
          raw += "### #{gallery['caption']}\n"
          if DEBUG
            raw += "User #{gallery['user_id']}, image_id: #{gallery['image_id']}\n"
          end
          raw += "#{UPLOADS}/#{gallery['orig']}\n"
          gallery_count += 1
          puts "#{gallery_count}--Cat: #{last_gallery['category'].to_s} ==> #{category_id_from_imported_category_id(last_gallery['category'].to_s + 'gal')}" unless QUIET
          {
            id: "gallery#" + last_gallery['tid'].to_s + last_gallery['image_id'].to_s,
            user_id: user_id_from_imported_user_id(last_gallery['user_id']) || Discourse::SYSTEM_USER_ID,
            title: CGI.unescapeHTML(last_gallery['title']),
            category: category_id_from_imported_category_id(last_gallery['category'].to_s + 'gal'),
            raw: insert_raw,
          }
        end
      end
    end
  end

  # TODO: use this to figure out to pin posts
  def map_first_post(row, mapped)
    mapped[:category] = @lookup.category_id_from_imported_category_id(row[:forum_id])
    mapped[:title] = CGI.unescapeHTML(row[:topic_title]).strip[0...255]
    mapped[:pinned_at] = mapped[:created_at] unless row[:topic_type] == Constants::POST_NORMAL
    mapped[:pinned_globally] = row[:topic_type] == Constants::POST_GLOBAL
    mapped[:post_create_action] = proc do |post|
      @permalink_importer.create_for_topic(post.topic, row[:topic_id])
    end

    mapped
  end

  def import_comments
    puts "", "importing gallery comments..."

    total_count = mysql_query("SELECT count(*) count FROM #{TABLE_PREFIX}gallery_comments;")
      .first['count']

    batches(BATCH_SIZE) do |offset|
      comments = mysql_query(<<-SQL

            SELECT #{TABLE_PREFIX}gallery_comments.tid tid,
               #{TABLE_PREFIX}gallery_topics.forum_id category,
               #{TABLE_PREFIX}gallery_posts.pid pid,
               #{TABLE_PREFIX}gallery_topics.title title,
               #{TABLE_PREFIX}gallery_posts.post raw,
               FROM_UNIXTIME(#{TABLE_PREFIX}gallery_posts.post_date) created_at,
               #{TABLE_PREFIX}gallery_posts.author_id user_id
            FROM #{TABLE_PREFIX}gallery_posts, #{TABLE_PREFIX}gallery_topics
            WHERE #{TABLE_PREFIX}gallery_posts.topic_id = #{TABLE_PREFIX}gallery_topics.tid
            AND #{TABLE_PREFIX}gallery_posts.new_topic = 0
            AND #{TABLE_PREFIX}gallery_posts.post_date > UNIX_TIMESTAMP(STR_TO_DATE('#{IMPORT_AFTER}', '%Y-%m-%d'))
            ORDER BY #{TABLE_PREFIX}gallery_posts.post_date ASC
            LIMIT #{BATCH_SIZE}
            OFFSET #{offset}

            SQL
                            )

      break if comments.size < 1
      next if all_records_exist? :posts, comments.map { |comment| "comment#" + comment['pid'].to_s }

      create_posts(comments, total: total_count, offset: offset) do |comment|
        next unless t = topic_lookup_from_imported_post_id("discussion#" + comment['tid'].to_s)
        next if comment['raw'].blank?
        {
          id: "comment#" + comment['pid'].to_s,
          user_id: user_id_from_imported_user_id(comment['user_id']) || Discourse::SYSTEM_USER_ID,
          topic_id: t[:topic_id],
          raw: clean_up(comment['raw']),
          created_at: Time.zone.at(comment['created_at'])
        }
      end
    end
  end

  def import_posts
    puts "", "importing posts..."

    total_count = mysql_query("SELECT count(*) count FROM #{POSTS_TABLE}
       	        WHERE post_date > UNIX_TIMESTAMP(STR_TO_DATE('#{IMPORT_AFTER}', '%Y-%m-%d'))
                AND new_topic=0;")
      .first['count']

    batches(BATCH_SIZE) do |offset|
      comments = mysql_query(<<-SQL
            SELECT #{TOPICS_TABLE}.tid tid,
               #{TOPICS_TABLE}.forum_id category,
               #{POSTS_TABLE}.pid pid,
               #{TOPICS_TABLE}.title title,
               #{POSTS_TABLE}.post raw,
               FROM_UNIXTIME(#{POSTS_TABLE}.post_date) created_at,
               #{POSTS_TABLE}.author_id user_id
            FROM #{POSTS_TABLE}, #{TOPICS_TABLE}
            WHERE #{POSTS_TABLE}.topic_id = #{TOPICS_TABLE}.tid
            AND #{POSTS_TABLE}.new_topic = 0
            AND #{POSTS_TABLE}.post_date > UNIX_TIMESTAMP(STR_TO_DATE('#{IMPORT_AFTER}', '%Y-%m-%d'))
            ORDER BY #{POSTS_TABLE}.post_date ASC
            LIMIT #{BATCH_SIZE}
            OFFSET #{offset}
            SQL
                            )

      break if comments.size < 1
      next if all_records_exist? :posts, comments.map { |comment| "comment#" + comment['pid'].to_s }

      create_posts(comments, total: total_count, offset: offset) do |comment|
        next unless t = topic_lookup_from_imported_post_id("discussion#" + comment['tid'].to_s)
        next if comment['raw'].blank?
        {
          id: "comment#" + comment['pid'].to_s,
          user_id: user_id_from_imported_user_id(comment['user_id']) || Discourse::SYSTEM_USER_ID,
          topic_id: t[:topic_id],
          raw: clean_up(comment['raw']),
          created_at: Time.zone.at(comment['created_at'])
        }
      end
    end
  end

  def nokogiri_fix_blockquotes(raw)
    # this makes proper quotes with user/topic/post references.
    # I'm not clear if it is for just some bizarre imported data, or it might ever be useful
    # It should be integrated into the Nokogiri section of clean_up, though.
    @doc = Nokogiri::XML("<html>" + raw + "</html>")

    # handle <blockquote>s with links to original post
    @doc.css('blockquote[class=ipsQuote]').each do |b|
      # puts "\n#{'#'*50}\n#{b}\n\nCONTENT: #{b['data-ipsquote-contentid']}"
      # b.options = Nokogiri::XML::ParseOptions::STRICT
      imported_post_id = b['data-ipsquote-contentcommentid'].to_s
      content_type = b['data-ipsquote-contenttype'].to_s
      content_class = b['data-ipsquote-contentclass'].to_s
      content_id = b['data-ipsquote-contentid'].to_s || b['data-cid'].to_s
      topic_lookup = topic_lookup_from_imported_post_id("comment#" + imported_post_id)
      post_lookup = topic_lookup_from_imported_post_id("discussion#" + content_id)
      post = topic_lookup ? topic_lookup[:post_number] : nil
      topic = topic_lookup ? topic_lookup[:topic_id] : nil
      post ||= post_lookup ? post_lookup[:post_number] : nil
      topic ||= post_lookup ? post_lookup[:topic_id] : nil

      # TODO: consider: <blockquote class="ipsStyle_spoiler" data-ipsspoiler="">
      # consider: <pre class="ipsCode prettyprint">
      # TODO make sure it's the imported username
      # TODO: do _s still get \-escaped?
      ips_username = b['data-ipsquote-username'] || b['data-author']
      username = ips_username
      new_text = ""
      if DEBUG
        # new_text += "post: #{imported_post_id} --> #{post_lookup} --> |#{post}|<br>\n"
        # new_text += "topic: #{content_id} --> #{topic_lookup} --> |#{topic}|<br>\n"
        # new_text += "user: #{ips_username} --> |#{username}|<br>\n"
        # new_text += "class: #{content_class}<br>\n"
        # new_text += "type: #{content_type}<br>\n"
        if content_class.length > 0 && content_class != "forums_Topic"
          new_text += "UNEXPECTED CONTENT CLASS! #{content_class}<br>\n"
        end
        if content_type.length > 0 && content_type != "forums"
          new_text += "UNEXPECTED CONTENT TYPE! #{content_type}<br>\n"
        end
        # puts "#{'-'*20} and NOWWWWW!!!! \n #{new_text}"
      end
      if post && topic && username
        quote = "\n[quote=\"#{username}, post:#{post}, topic: #{topic}\"]\n\n"
      else
        if username && username.length > 1
          quote = "\n[quote=\"#{username}\"]\n\n"
        else
          quote = "\n[quote]\n"
        end
        # new_doc = Nokogiri::XML("<div>#{new_text}</div>")
      end
      puts "QUOTE: #{quote}"
      sleep 1
      b.content = quote + b.content + "\n[/quote]\n"
      b.name = 'div'
    end

    raw = @doc.to_html
  end

  def clean_up(raw)
    return "" if raw.blank?

    raw.gsub!(/<#EMO_DIR#>/, EMO_DIR)
    # TODO what about uploads?
    # raw.gsub!(/<fileStore.core_Attachment>/,UPLOADS)
    raw.gsub!(/<br>/, "\n\n")
    raw.gsub!(/<br \/>/, "\n\n")
    raw.gsub!(/<p>&nbsp;<\/p>/, "\n\n")
    raw.gsub!(/\[hr\]/, "\n***\n")
    raw.gsub!(/&#39;/, "'")
    raw.gsub!(/\[url="(.+?)"\]http.+?\[\/url\]/, "\\1\n")
    raw.gsub!(/\[media\](.+?)\[\/media\]/, "\n\\1\n\n")
    raw.gsub!(/\[\/quote\]/, "\n[/quote]\n")
    raw.gsub!(/date=\'(.+?)\'/, '')
    raw.gsub!(/timestamp=\'(.+?)\' /, '')

    quote_regex = /\[quote name=\'(.+?)\'\s+post=\'(\d+?)\'\s*\]/
    while quote = quote_regex.match(raw)
      # get IPB post number and find Discourse post and topic number
      puts "----------------------------------------\nName: #{quote[1]}, post: #{quote[2]}" unless QUIET
      imported_post_id = quote[2].to_s
      topic_lookup = topic_lookup_from_imported_post_id("comment#" + imported_post_id)
      post_lookup = topic_lookup_from_imported_post_id("discussion#" + imported_post_id)
      puts "topic_lookup: #{topic_lookup}, post: #{post_lookup}" unless QUIET
      post_num = topic_lookup ? topic_lookup[:post_number] : nil
      topic_num = topic_lookup ? topic_lookup[:topic_id] : nil
      post_num ||= post_lookup ? post_lookup[:post_number] : nil
      topic_num ||= post_lookup ? post_lookup[:topic_id] : nil

      # Fix or leave bogus username?
      username = find_user_by_import_id(quote[1]) || quote[1]
      puts "username: #{username}, post_id: #{post_num}, topic_id: #{topic_num}" unless QUIET
      puts "Before fixing a quote: #{raw}\n**************************************** " unless QUIET
      post_string = post_num ? ", post:#{post_num}" : ""
      topic_string = topic_num ? ", topic:#{topic_num}" : ""
      raw.gsub!(quote_regex, "\n[quote=\"#{username}#{post_string}#{topic_string}\"]\n\n")
      puts "AFTER!!!!!!!!!!!!1: #{raw}" unless QUIET
      sleep 1
      raw
    end

    attach_regex = /\[attachment=(\d+?):.+\]/
    while attach = attach_regex.match(raw)
      attach_id = attach[1]
      attachments =
        mysql_query("SELECT attach_location as loc,
                            attach_file as filename
                     FROM #{ATTACHMENT_TABLE}
                     WHERE attach_id=#{attach_id}")
      if attachments.count < 1
        puts "Attachment #{attach_id} not found."
        attach_string = "Attachment #{attach_id} not found."
      else
        attach_string = "#{attach_id}\n\n![#{attachments.first['filename']}](#{UPLOADS}/#{attachments.first['loc']})\n"
      end
      raw.gsub!(attach_regex, attach_string)
    end

    raw
  end

  def random_category_color
    colors = SiteSetting.category_colors.split('|')
    colors[rand(colors.count)]
  end

  def old_clean_up(raw)
    # This was for a forum that appeared to have lots of customization's.
    # IT did a good job of handling quotes and whatnot, but I don't know
    # what version if IPBoard it was for.
    return "" if raw.blank?

    raw.gsub!(/<___base_url___>/, URL)
    raw.gsub!(/<fileStore.core_Emoticons>/, UPLOADS)
    raw.gsub!(/<fileStore.core_Attachment>/, UPLOADS)
    raw.gsub!(/<br>/, "\n")

    @doc = Nokogiri::XML("<html>" + raw + "</html>")

    # handle <blockquote>s with links to original post
    @doc.css('blockquote[class=ipsQuote]').each do |b|
      imported_post_id = b['data-ipsquote-contentcommentid'].to_s
      content_type = b['data-ipsquote-contenttype'].to_s
      content_class = b['data-ipsquote-contentclass'].to_s
      content_id = b['data-ipsquote-contentid'].to_s || b['data-cid'].to_s
      topic_lookup = topic_lookup_from_imported_post_id("comment#" + imported_post_id)
      post_lookup = topic_lookup_from_imported_post_id("discussion#" + content_id)
      post = topic_lookup ? topic_lookup[:post_number] : nil
      topic = topic_lookup ? topic_lookup[:topic_id] : nil
      post ||= post_lookup ? post_lookup[:post_number] : nil
      topic ||= post_lookup ? post_lookup[:topic_id] : nil

      # TODO: consider: <blockquote class="ipsStyle_spoiler" data-ipsspoiler="">
      # consider: <pre class="ipsCode prettyprint">
      ips_username = b['data-ipsquote-username'] || b['data-author']
      username = ips_username
      new_text = ""
      if DEBUG
        if content_class.length > 0 && content_class != "forums_Topic"
          new_text += "UNEXPECTED CONTENT CLASS! #{content_class}<br>\n"
        end
        if content_type.length > 0 && content_type != "forums"
          new_text += "UNEXPECTED CONTENT TYPE! #{content_type}<br>\n"
        end
      end
      if post && topic && username
        quote = "[quote=\"#{username}, post:#{post}, topic: #{topic}\"]\n\n"
      else
        if username && username.length > 1
          quote = "[quote=\"#{username}\"]\n\n"
        else
          quote = "[quote]\n"
        end
      end
      b.content = quote + b.content + "\n[/quote]\n"
      b.name = 'div'
    end

    @doc.css('object param embed').each do |embed|
      embed.replace("\n#{embed['src']}\n")
    end

    # handle <iframe data-embedcontent>s with links to original post
    # no examples in recent import
    @doc.css('iframe[data-embedcontent]').each do |d|
      d.to_s.match(/\-([0-9]+)t/)
      imported_post_id = $1
      if imported_post_id
        puts "Searching for #{imported_post_id}" unless QUIET
        topic_lookup = topic_lookup_from_imported_post_id("discussion#" + imported_post_id)
        topic = topic_lookup ? topic_lookup[:topic_id] : nil
        if topic
          url = URL + "/t/#{topic}"
          d.to_s.match(/comment=([0-9]+)&/)
          content_id = $1 || "-1"
          if content_id
            post_lookup = topic_lookup_from_imported_post_id("comment#" + content_id)
            post = topic_lookup ? topic_lookup[:post_number] : 1
            url += "/#{post}"
          end
          d.content = url
        end
      end
      d.name = 'div'
    end

    @doc.css('div[class=ipsQuote_citation]').each do |d|
      d.remove
    end

    raw = @doc.to_html

    # let ReverseMarkdown handle the rest
    raw = ReverseMarkdown.convert raw

    # remove tabs at start of line to avoid everything being a <pre>
    raw = raw.gsub(/^\t+/, "")

    # un \-escape _s in usernames in [quote]s
    raw.gsub!(/^\[quote=.+?_.*$/) do |match|
      match = match.gsub('\_', '_')
      match
    end
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

    # TODO: permalink normalizations: /(.*t)\?.*/\1

    puts '', 'Users...', ''
    User.find_each do |u|
      ucf = u.custom_fields
      if ucf && ucf["import_id"] && ucf["import_username"]
        username = URI.escape(ucf["import_username"])
        Permalink.create(url: "#{USERDIR}/#{ucf['import_id']}-#{username}", external_url: "/users/#{u.username}") rescue nil
        print '.'
      end
    end

    puts '', 'Posts...', ''
    Post.find_each do |post|
      pcf = post.custom_fields
      if pcf && pcf["import_id"]
        if post.post_number == 1
          topic = post.topic
          id = pcf["import_id"].split('#').last
          slug = topic.slug
          if ID_FIRST
            Permalink.create(url: "topic/#{id}-#{slug}", topic_id: topic.id) rescue nil
            unless QUIET
              print_warning("#{URL}topic/#{id}-#{slug} --> http://localhost:3000/topic/#{id}-#{slug}")
            end
          else
            Permalink.create(url: "#{slug}-#{id}t", topic_id: topic.id) rescue nil
            unless QUIET
              print_warning("#{URL}/#{slug}-#{id}t --> http://localhost:3000/t/#{topic.id}")
            end
          end
        else # don't think we can do posts
          # Permalink.create( url: "#{BASE}/forum_entry-id-#{id}.html", post_id: post.id ) rescue nil
          # unless QUIET
          #   print_warning("forum_entry-id-#{id}.html --> http://localhost:3000/t/#{topic.id}/#{post.id}")
          # end
        end
        print '.'
      end
    end

    puts '', 'Categories...', ''
    Category.find_each do |cat|
      ccf = cat.custom_fields
      next unless id = ccf["import_id"]
      slug = cat['slug']
      unless QUIET
        print_warning("/forum/#{URL}-#{slug}-#{id} --> /c/#{slug}")
      end
      Permalink.create(url: "/forum/#{id}-#{slug}", category_id: cat.id) rescue nil
      print '.'
    end
  end

  def print_warning(message)
    $stderr.puts "#{message}"
  end

end

ImportScripts::IpboardSQL.new.perform
