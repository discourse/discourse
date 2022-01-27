# frozen_string_literal: true

# AnswerHub Importer
#
# Based on having access to a mysql dump.
# Pass in the ENV variables listed below before running the script.

require_relative 'base'
require 'mysql2'
require 'open-uri'

class ImportScripts::AnswerHub < ImportScripts::Base

  DB_NAME ||= ENV['DB_NAME'] || "answerhub"
  DB_PASS ||= ENV['DB_PASS'] || "answerhub"
  DB_USER ||= ENV['DB_USER'] || "answerhub"
  TABLE_PREFIX ||= ENV['TABLE_PREFIX'] || "network1"
  BATCH_SIZE ||= ENV['BATCH_SIZE'].to_i || 1000
  ATTACHMENT_DIR = ENV['ATTACHMENT_DIR'] || ''
  PROCESS_UPLOADS = ENV['PROCESS_UPLOADS'].to_i || 0
  ANSWERHUB_DOMAIN = ENV['ANSWERHUB_DOMAIN']
  AVATAR_DIR = ENV['AVATAR_DIR'] || ""
  SITE_ID = ENV['SITE_ID'].to_i || 0
  CATEGORY_MAP_FROM = ENV['CATEGORY_MAP_FROM'].to_i || 0
  CATEGORY_MAP_TO = ENV['CATEGORY_MAP_TO'].to_i || 0
  SCRAPE_AVATARS = ENV['SCRAPE_AVATARS'].to_i || 0

  def initialize
    super
    @client = Mysql2::Client.new(
      host: "localhost",
      username: DB_USER,
      password: DB_PASS,
      database: DB_NAME
    )
    @skip_updates = true
    SiteSetting.tagging_enabled = true
    SiteSetting.max_tags_per_topic = 10
  end

  def execute
    puts "Now starting the AnswerHub Import"
    puts "DB Name: #{DB_NAME}"
    puts "Table Prefix: #{TABLE_PREFIX}"
    puts
    import_users
    import_categories
    import_topics
    import_posts
    import_groups
    add_users_to_groups
    add_moderators
    add_admins
    import_avatars
    create_permalinks
  end

  def import_users
    puts '', "creating users"

    query =
      "SELECT count(*) count
       FROM #{TABLE_PREFIX}_authoritables
       WHERE c_type = 'user'
       AND c_active = 1
       AND c_system <> 1;"
    total_count = @client.query(query).first['count']
    puts "Total count: #{total_count}"
    @last_user_id = -1

    batches(BATCH_SIZE) do |offset|
      query = "SELECT c_id, c_creation_date, c_name, c_primaryEmail, c_last_seen, c_description
      FROM #{TABLE_PREFIX}_authoritables
      WHERE c_type = 'user'
      AND c_active = 1
      AND c_system <> 1
      AND c_id > #{@last_user_id}
      LIMIT #{BATCH_SIZE};"

      results = @client.query(query)
      break if results.size < 1
      @last_user_id = results.to_a.last['c_id']

      create_users(results, total: total_count, offset: offset) do |user|
        # puts user['c_id'].to_s + ' ' + user['c_name']
        next if @lookup.user_id_from_imported_user_id(user['c_id'])
        { id: user['c_id'],
          email: "#{SecureRandom.hex}@invalid.invalid",
          username: user['c_name'],
          created_at: user['c_creation_date'],
          bio_raw: user['c_description'],
          last_seen_at: user['c_last_seen'],
        }
      end
    end
  end

  def import_categories
    puts "", "importing categories..."

    # Import parent categories first
    query = "SELECT c_id, c_name, c_plug, c_parent
    FROM containers
    WHERE c_type = 'space'
    AND c_active = 1
    AND c_parent = 7 OR c_parent IS NULL"
    results = @client.query(query)

    create_categories(results) do |c|
      {
        id: c['c_id'],
        name: c['c_name'],
        parent_category_id: check_parent_id(c['c_parent']),
      }
    end

    # Import sub-categories
    query = "SELECT c_id, c_name, c_plug, c_parent
    FROM containers
    WHERE c_type = 'space'
    AND c_active = 1
    AND c_parent != 7 AND c_parent IS NOT NULL"
    results = @client.query(query)

    create_categories(results) do |c|
      # puts c.inspect
      {
        id: c['c_id'],
        name: c['c_name'],
        parent_category_id: category_id_from_imported_category_id(check_parent_id(c['c_parent'])),
      }
    end
  end

  def import_topics
    puts "", "importing topics..."

    count_query =
      "SELECT count(*) count
       FROM #{TABLE_PREFIX}_nodes
       WHERE c_visibility <> 'deleted'
       AND (c_type = 'question'
         OR c_type = 'kbentry');"
    total_count = @client.query(count_query).first['count']

    @last_topic_id = -1

    batches(BATCH_SIZE) do |offset|
      # Let's start with just question types
      query =
        "SELECT *
         FROM #{TABLE_PREFIX}_nodes
         WHERE c_id > #{@last_topic_id}
         AND c_visibility <> 'deleted'
         AND (c_type = 'question'
           OR c_type = 'kbentry')
         ORDER BY c_id ASC
         LIMIT #{BATCH_SIZE};"
      topics = @client.query(query)

      break if topics.size < 1
      @last_topic_id = topics.to_a.last['c_id']

      create_posts(topics, total: total_count, offset: offset) do |t|
        user_id = user_id_from_imported_user_id(t['c_author']) || Discourse::SYSTEM_USER_ID
        body = process_mentions(t['c_body'])
        if PROCESS_UPLOADS == 1
          body = process_uploads(body, user_id)
        end
        markdown_body = HtmlToMarkdown.new(body).to_markdown
        {
          id: t['c_id'],
          user_id: user_id,
          title: t['c_title'],
          category: category_id_from_imported_category_id(t['c_primaryContainer']),
          raw: markdown_body,
          created_at: t['c_creation_date'],
          post_create_action: proc do |post|
            tag_names = t['c_topic_names'].split(',')
            DiscourseTagging.tag_topic_by_names(post.topic, staff_guardian, tag_names)
          end
        }
      end
    end
  end

  def import_posts
    puts "", "importing posts..."

    count_query =
      "SELECT count(*) count
       FROM #{TABLE_PREFIX}_nodes
       WHERE c_visibility <> 'deleted'
       AND (c_type = 'answer'
         OR c_type = 'comment'
         OR c_type = 'kbentry');"
    total_count = @client.query(count_query).first['count']

    @last_post_id = -1

    batches(BATCH_SIZE) do |offset|
      query =
        "SELECT *
         FROM #{TABLE_PREFIX}_nodes
         WHERE c_id > #{@last_post_id}
         AND c_visibility <> 'deleted'
         AND (c_type = 'answer'
           OR c_type = 'comment'
           OR c_type = 'kbentry')
         ORDER BY c_id ASC
         LIMIT #{BATCH_SIZE};"
      posts = @client.query(query)
      next if all_records_exist? :posts, posts.map { |p| p['c_id'] }

      break if posts.size < 1
      @last_post_id = posts.to_a.last['c_id']

      create_posts(posts, total: total_count, offset: offset) do |p|
        t = topic_lookup_from_imported_post_id(p['c_originalParent'])
        next unless t

        reply_to_post_id = post_id_from_imported_post_id(p['c_parent'])
        reply_to_post = reply_to_post_id.present? ? Post.find(reply_to_post_id) : nil
        reply_to_post_number = reply_to_post.present? ? reply_to_post.post_number : nil

        user_id = user_id_from_imported_user_id(p['c_author']) || Discourse::SYSTEM_USER_ID

        body = process_mentions(p['c_body'])
        if PROCESS_UPLOADS == 1
          body = process_uploads(body, user_id)
        end

        markdown_body = HtmlToMarkdown.new(body).to_markdown
        {
          id: p['c_id'],
          user_id: user_id,
          topic_id: t[:topic_id],
          reply_to_post_number: reply_to_post_number,
          raw: markdown_body,
          created_at: p['c_creation_date'],
          post_create_action: proc do |post_info|
            begin
              if p['c_type'] == 'answer' && p['c_marked'] == 1
                post = Post.find(post_info[:id])
                if post
                  user_id = user_id_from_imported_user_id(p['c_author']) || Discourse::SYSTEM_USER_ID
                  current_user = User.find(user_id)
                  solved = DiscourseSolved.accept_answer!(post, current_user)
                  # puts "SOLVED: #{solved}"
                end
              end
            rescue ActiveRecord::RecordInvalid
              puts "SOLVED: Skipped post_id: #{post.id} because invalid"
            end
          end
        }
      end
    end
  end

  def import_groups
    puts "", "importing groups..."

    query =
      "SELECT c_id, c_name
       FROM network6_authoritables
       WHERE c_type='group'
       AND c_id > 6;" # Ignore Anonymous, Users, Moderators, etc.
    groups = @client.query(query)

    create_groups(groups) do |group|
      {
        id: group["c_id"],
        name: group["c_name"],
        visibility_level: 1
      }
    end
  end

  def add_users_to_groups
    puts "", "adding users to groups..."

    query =
      "SELECT c_id, c_name
       FROM network6_authoritables
       WHERE c_type='group'
       AND c_id > 6;" # Ignore Anonymous, Users, Moderators, etc.
    groups = @client.query(query)

    members_query =
      "SELECT *
       FROM network6_authoritable_groups;"
    group_members = @client.query(members_query)

    total_count = groups.count
    progress_count = 0
    start_time = Time.now

    group_members.map
    groups.each do |group|
      dgroup = find_group_by_import_id(group['c_id'])

      next if dgroup.custom_fields['import_users_added']

      group_member_ids = group_members.map { |m| user_id_from_imported_user_id(m["c_members"]) if m["c_groups"] == group['c_id'] }.compact

      # add members
      dgroup.bulk_add(group_member_ids)

      # reload group
      dgroup.reload

      dgroup.custom_fields['import_users_added'] = true
      dgroup.save

      progress_count += 1
      print_status(progress_count, total_count, start_time)
    end
  end

  def add_moderators
    puts "", "adding moderators..."

    query =
      "SELECT *
       FROM network6_authoritable_groups
       WHERE c_groups = 4;"
    moderators = @client.query(query)

    moderator_ids = moderators.map { |m| user_id_from_imported_user_id(m["c_members"]) }.compact

    moderator_ids.each do |id|
      user = User.find(id)
      user.grant_moderation!
    end
  end

  def add_admins
    puts "", "adding admins..."

    query =
      "SELECT *
       FROM network6_authoritable_groups
       WHERE c_groups = 5 OR c_groups = 6;" # Super Users, Network Administrators
    admins = @client.query(query)

    admin_ids = admins.map { |a| user_id_from_imported_user_id(a["c_members"]) }.compact

    admin_ids.each do |id|
      user = User.find(id)
      user.grant_admin!
    end
  end

  def import_avatars
    puts "", "importing user avatars"
    query =
      "SELECT *
       FROM network6_user_preferences
       WHERE c_key = 'avatarImage'"
    avatars = @client.query(query)

    avatars.each do |a|
      begin
        user_id = user_id_from_imported_user_id(a['c_user'])
        user = User.find(user_id)
        if user
          filename = "avatar-#{user_id}.png"
          path = File.join(AVATAR_DIR, filename)
          next if !File.exist?(path)

          # Scrape Avatars - Avatars are saved in the db, but it might be easier to just scrape them
          if SCRAPE_AVATARS == 1
            File.open(path, 'wb') { |f|
              f << open("https://#{ANSWERHUB_DOMAIN}/forums/users/#{a['c_user']}/photo/view.html?s=240").read
            }
          end

          upload = @uploader.create_upload(user.id, path, filename)

          if upload.persisted?
            user.import_mode = false
            user.create_user_avatar
            user.import_mode = true
            user.user_avatar.update(custom_upload_id: upload.id)
            user.update(uploaded_avatar_id: upload.id)
          else
            Rails.logger.error("Could not persist avatar for user #{user.username}")
          end
        end
      rescue ActiveRecord::RecordNotFound
        puts "Could not find User for user_id: #{a['c_user']}"
      end
    end
  end

  def process_uploads(body, user_id)
    if body.match(/<img src="\/forums\/storage\/attachments\/[\w-]*.[a-z]{3,4}">/)
      # There could be multiple images in a post
      images = body.scan(/<img src="\/forums\/storage\/attachments\/[\w-]*.[a-z]{3,4}">/)

      images.each do |image|
        filepath = File.basename(image).split('"')[0]
        filepath = File.join(ATTACHMENT_DIR, filepath)

        if File.exist?(filepath)
          filename = File.basename(filepath)
          upload = create_upload(user_id, filepath, filename)
          image_html = html_for_upload(upload, filename)
          original_image_html = '<img src="/forums/storage/attachments/' + filename + '">'
          body.sub!(original_image_html, image_html)
        end
      end
    end
    # Non-images
    if body.match(/<a href="\/forums\/storage\/attachments\/[\w-]*.[a-z]{3,4}">/)
      # There could be multiple files in a post
      files = body.scan(/<a href="\/forums\/storage\/attachments\/[\w-]*.[a-z]{3,4}">/)

      files.each do |file|
        filepath = File.basename(file).split('"')[0]
        filepath = File.join(ATTACHMENT_DIR, filepath)

        if File.exist?(filepath)
          filename = File.basename(filepath)
          upload = create_upload(user_id, filepath, filename)
          file_html = html_for_upload(upload, filename)
          original_file_html = '<a href="/forums/storage/attachments/' + filename + '">'
          body.sub!(original_file_html, file_html)
        end
      end
    end

    body
  end

  def process_mentions(body)
    raw = body.dup

    # https://example.forum.com/forums/users/1469/XYZ_Rob.html
    raw.gsub!(/(https:\/\/example.forum.com\/forums\/users\/\d+\/[\w_%-.]*.html)/) do
      legacy_url = $1
      import_user_id = legacy_url.match(/https:\/\/example.forum.com\/forums\/users\/(\d+)\/[\w_%-.]*.html/).captures

      user = @lookup.find_user_by_import_id(import_user_id[0])
      if user.present?
        # puts "/users/#{user.username}"
        "/users/#{user.username}"
      else
        # puts legacy_url
        legacy_url
      end
    end

    # /forums/users/395/petrocket.html
    raw.gsub!(/(\/forums\/users\/\d+\/[\w_%-.]*.html)/) do
      legacy_url = $1
      import_user_id = legacy_url.match(/\/forums\/users\/(\d+)\/[\w_%-.]*.html/).captures

      # puts raw
      user = @lookup.find_user_by_import_id(import_user_id[0])
      if user.present?
        # puts "/users/#{user.username}"
        "/users/#{user.username}"
      else
        # puts legacy_url
        legacy_url
      end
    end

    raw
  end

  def create_permalinks
    puts '', 'Creating redirects...', ''

    # https://example.forum.com/forums/questions/2005/missing-file.html
    Topic.find_each do |topic|
      pcf = topic.first_post.custom_fields
      if pcf && pcf["import_id"]
        id = pcf["import_id"]
        slug = Slug.for(topic.title)
        Permalink.create(url: "questions/#{id}/#{slug}.html", topic_id: topic.id) rescue nil
        print '.'
      end
    end
  end

  def staff_guardian
    @_staff_guardian ||= Guardian.new(Discourse.system_user)
  end

  # Some category parent id's need to be adjusted
  def check_parent_id(id)
    return nil if SITE_ID > 0 && id == SITE_ID
    return CATEGORY_MAP_TO if CATEGORY_MAP_FROM > 0 && id == CATEGORY_MAP_FROM
    id
  end

end

ImportScripts::AnswerHub.new.perform
