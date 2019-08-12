# frozen_string_literal: true

require_relative '../base'
require_relative './redis'
require_relative './mongo'

class ImportScripts::NodeBB < ImportScripts::Base
  # CHANGE THESE BEFORE RUNNING THE IMPORTER
  # ATTACHMENT_DIR needs to be absolute, not relative path
  ATTACHMENT_DIR = '/Users/orlando/www/orlando/NodeBB/public/uploads'
  BATCH_SIZE = 2000

  def initialize
    super

    # adapter = NodeBB::Mongo
    # @client = adapter.new('mongodb://127.0.0.1:27017/nodebb')

    adapter = NodeBB::Redis
    @client = adapter.new(
      host: "localhost",
      port: "6379",
      db: 14
    )

    load_merged_posts
  end

  def load_merged_posts
    puts 'loading merged posts with topics...'

    # we keep here the posts that were merged
    # as topics
    #
    # { post_id: discourse_post_id }
    @merged_posts_map = {}

    PostCustomField.where(name: 'import_merged_post_id').pluck(:post_id, :value).each do |post_id, import_id|
      post = Post.find(post_id)
      topic_id = post.topic_id
      nodebb_post_id = post.custom_fields['import_merged_post_id']

      @merged_posts_map[nodebb_post_id] = topic_id
    end
  end

  def execute
    import_groups
    import_categories
    import_users
    add_users_to_groups
    import_topics
    import_posts
    import_attachments
    post_process_posts
  end

  def import_groups
    puts '', 'importing groups'

    groups = @client.groups
    total_count = groups.count
    progress_count = 0
    start_time = Time.now

    create_groups(groups) do |group|
      {
        id: group["name"],
        name: group["slug"]
      }
    end
  end

  def import_categories
    puts "", "importing top level categories..."

    category_map = @client.categories
    category_ids = category_map.keys
    categories = category_map.values

    top_level_categories = categories.select { |c| c["parentCid"] == "0" && c["disabled"] != "1" }

    create_categories(top_level_categories) do |category|
      {
        id: category["cid"],
        name: category["name"],
        position: category["order"],
        description: category["description"],
      }
    end

    puts "", "importing child categories..."

    children_categories = categories.select { |c| c["parentCid"] != "0" && c["disabled"] != "1" }
    top_level_category_ids = Set.new(top_level_categories.map { |c| c["cid"] })

    # cut down the tree to only 2 levels of categories
    children_categories.each do |cc|
      while !top_level_category_ids.include?(cc["parentCid"])
        cc["parentCid"] = categories.detect { |c| c["cid"] == cc["parentCid"] }["parentCid"]
      end
    end

    create_categories(children_categories) do |category|
      {
        id: category["cid"],
        name: category["name"],
        position: category["order"],
        description: category["description"],
        parent_category_id: category_id_from_imported_category_id(category["parentCid"])
      }
    end

    categories.each do |source_category|
      cid = category_id_from_imported_category_id(source_category['cid'])
      Permalink.create(url: "/category/#{source_category['slug']}", category_id: cid) rescue nil
    end

  end

  def import_users
    puts "", "importing users"

    users = @client.users
    user_count = users.count

    # we use this group to grant admin to users
    admin_group = @client.group("administrators")

    create_users(users, total: user_count) do |user|
      username = user["username"]
      email = user["email"]

      # skip users without username
      next unless username

      # fake email for users without email
      email = fake_email if email.blank?

      # use user.suspended to handle banned users
      if user["banned"] == "1"
        suspended_at = Time.now
        suspended_till = Time.now + 100.years
      end

      {
        id: user["uid"],
        name: user["fullname"],
        username: username,
        email: email,
        admin: admin_group["member_ids"].include?(user["uid"]),
        website: user["website"],
        location: user["location"],
        suspended_at: suspended_at,
        suspended_till: suspended_till,
        primary_group_id: group_id_from_imported_group_id(user["groupTitle"]),
        created_at: user["joindate"],
        bio_raw: user["aboutme"],
        active: true,
        custom_fields: {
          import_pass: user["password"]
        },
        post_create_action: proc do |u|
          import_profile_picture(user, u)
          import_profile_background(user, u)
        end
      }
    end
  end

  def import_profile_picture(old_user, imported_user)
    picture = old_user["picture"]

    return if picture.blank?

    # URI.scheme returns nil for internal URLs
    uri = URI.parse(picture)
    is_external = uri.scheme

    if is_external
      # download external image
      begin
        string_io = open(picture, read_timeout: 5)
      rescue Net::ReadTimeout
        puts "timeout downloading avatar for user #{imported_user.id}"
        return nil
      end

      # continue if download failed
      return unless string_io

      # try to get filename from headers
      if string_io.meta["content-disposition"]
        filename = string_io.meta["content-disposition"].match(/filename=(\"?)(.+)\1/)[2]
      end

      # try to get it from path
      filename = File.basename(picture) unless filename

      # can't determine filename, skip upload
      if !filename
        puts "Can't determine filename, skipping avatar upload for user #{imported_user.id}"
        return
      end

      # write tmp file
      file = Tempfile.new(filename, encoding: 'ascii-8bit')
      file.write string_io.read
      file.rewind

      upload = UploadCreator.new(file, filename).create_for(imported_user.id)
    else
      # remove "/assets/uploads/" and "/uploads" from attachment
      picture = picture.gsub("/assets/uploads", "")
      picture = picture.gsub("/uploads", "")
      filepath = File.join(ATTACHMENT_DIR, picture)
      filename = File.basename(picture)

      unless File.exists?(filepath)
        puts "Avatar file doesn't exist: #{filepath}"
        return nil
      end

      upload = create_upload(imported_user.id, filepath, filename)
    end

    return if !upload.persisted?

    imported_user.create_user_avatar
    imported_user.user_avatar.update(custom_upload_id: upload.id)
    imported_user.update(uploaded_avatar_id: upload.id)
  ensure
    string_io.close rescue nil
    file.close rescue nil
    file.unlind rescue nil
  end

  def import_profile_background(old_user, imported_user)
    picture = old_user["cover:url"]

    return if picture.blank?

    # URI returns nil for invalid URLs
    uri = URI.parse(picture)
    is_external = uri.scheme

    if is_external
      begin
        string_io = open(picture, read_timeout: 5)
      rescue Net::ReadTimeout
        return nil
      end

      if string_io.meta["content-disposition"]
        filename = string_io.meta["content-disposition"].match(/filename=(\"?)(.+)\1/)[2]
      end

      filename = File.basename(picture) unless filename

      # can't determine filename, skip upload
      if !filename
        puts "Can't determine filename, skipping background upload for user #{imported_user.id}"
        return
      end

      # write tmp file
      file = Tempfile.new(filename, encoding: 'ascii-8bit')
      file.write string_io.read
      file.rewind

      upload = UploadCreator.new(file, filename).create_for(imported_user.id)
    else
      # remove "/assets/uploads/" and "/uploads" from attachment
      picture = picture.gsub("/assets/uploads", "")
      picture = picture.gsub("/uploads", "")
      filepath = File.join(ATTACHMENT_DIR, picture)
      filename = File.basename(picture)

      unless File.exists?(filepath)
        puts "Background file doesn't exist: #{filepath}"
        return nil
      end

      upload = create_upload(imported_user.id, filepath, filename)
    end

    return if !upload.persisted?

    imported_user.user_profile.upload_profile_background(upload)
  ensure
    string_io.close rescue nil
    file.close rescue nil
    file.unlink rescue nil
  end

  def add_users_to_groups
    puts "", "adding users to groups..."

    groups = @client.groups
    total_count = groups.count
    progress_count = 0
    start_time = Time.now

    @client.groups.each do |group|
      dgroup = find_group_by_import_id(group["name"])

      # do thing if we migrated this group already
      next if dgroup.custom_fields['import_users_added']

      group_member_ids = group["member_ids"].map { |uid| user_id_from_imported_user_id(uid) }
      group_owner_ids = group["owner_ids"].map { |uid| user_id_from_imported_user_id(uid) }

      # add members
      dgroup.bulk_add(group_member_ids)

      # reload group
      dgroup.reload

      # add owners
      owners = User.find(group_owner_ids)
      owners.each { |owner| dgroup.add_owner(owner) }

      dgroup.custom_fields['import_users_added'] = true
      dgroup.save

      progress_count += 1
      print_status(progress_count, total_count, start_time)
    end
  end

  def import_topics
    puts "", "importing topics..."

    topic_count = @client.topic_count

    batches(BATCH_SIZE) do |offset|
      topics = @client.topics(offset, BATCH_SIZE)

      break if topics.size < 1

      create_posts(topics, total: topic_count, offset: offset) do |topic|
        # skip if is deleted
        if topic["deleted"] == "1"
          puts "Topic with id #{topic["tid"]} was deleted, skipping"
          next
        end

        topic_id = "t#{topic["tid"]}"
        raw = topic["mainpost"]["content"]

        data = {
          id: topic_id,
          user_id: user_id_from_imported_user_id(topic["uid"]) || Discourse::SYSTEM_USER_ID,
          title: topic["title"],
          category: category_id_from_imported_category_id(topic["cid"]),
          raw: raw,
          created_at: topic["timestamp"],
          views: topic["viewcount"],
          closed: topic["locked"] == "1",
          post_create_action: proc do |p|
            # keep track of this to use in import_posts
            p.custom_fields["import_merged_post_id"] = topic["mainPid"]
            p.save
            @merged_posts_map[topic["mainPid"]] = p.id
          end
        }

        data[:pinned_at] = data[:created_at] if topic["pinned"] == "1"

        data
      end

      topics.each do |import_topic|
        topic = topic_lookup_from_imported_post_id("t#{import_topic["tid"]}")
        Permalink.create(url: "/topic/#{import_topic['slug']}", topic_id: topic[:topic_id]) rescue nil
      end
    end
  end

  def import_posts
    puts "", "importing posts..."

    post_count = @client.post_count

    batches(BATCH_SIZE) do |offset|
      posts = @client.posts(offset, BATCH_SIZE)

      break if posts.size < 1

      create_posts(posts, total: post_count, offset: offset) do |post|
        # skip if it's merged_post
        next if @merged_posts_map[post["pid"]]

        # skip if it's deleted
        next if post["deleted"] == "1"

        raw = post["content"]
        post_id = "p#{post["pid"]}"

        next if raw.blank?
        topic = topic_lookup_from_imported_post_id("t#{post["tid"]}")

        unless topic
          puts "Topic with id #{post["tid"]} not found, skipping"
          next
        end

        data = {
          id: post_id,
          user_id: user_id_from_imported_user_id(post["uid"]) || Discourse::SYSTEM_USER_ID,
          topic_id: topic[:topic_id],
          raw: raw,
          created_at: post["timestamp"],
          post_create_action: proc do |p|
            post["upvoted_by"].each do |upvoter_id|
              user = User.new
              user.id = user_id_from_imported_user_id(upvoter_id) || Discourse::SYSTEM_USER_ID
              PostActionCreator.like(user, p)
            end
          end
        }

        if post['toPid']
          # Look reply to topic
          parent_id = topic_lookup_from_imported_post_id("t#{post['toPid']}").try(:[], :post_number)

          # Look reply post if topic is missing
          parent_id ||= topic_lookup_from_imported_post_id("p#{post['toPid']}").try(:[], :post_number)

          if parent_id
            data[:reply_to_post_number] = parent_id
          else
            puts "Post with id #{post["toPid"]} not found for reply"
          end
        end

        data
      end
    end
  end

  def post_process_posts
    puts "", "Postprocessing posts..."

    current = 0
    max = Post.count
    start_time = Time.now

    Post.find_each do |post|
      begin
        next if post.custom_fields['import_post_processing']

        new_raw = postprocess_post(post)
        if new_raw != post.raw
          post.raw = new_raw
          post.custom_fields['import_post_processing'] = true
          post.save
        end
      ensure
        print_status(current += 1, max, start_time)
      end
    end
  end

  def import_attachments
    puts '', 'importing attachments...'

    current = 0
    max = Post.count
    start_time = Time.now

    Post.find_each do |post|
      current += 1
      print_status(current, max, start_time)

      new_raw = post.raw.dup
      new_raw.gsub!(/\[(.*)\]\((\/assets\/uploads\/files\/.*)\)/) do
        image_md = Regexp.last_match[0]
        text, filepath = $1, $2
        filepath = filepath.gsub("/assets/uploads", ATTACHMENT_DIR)

        # if file exists
        # upload attachment and return html for it
        if File.exists?(filepath)
          filename = File.basename(filepath)
          upload = create_upload(post.user_id, filepath, filename)

          html_for_upload(upload, filename)
        else
          puts "File with path #{filepath} not found for post #{post.id}, upload will be broken"
          image_md
        end
      end

      if new_raw != post.raw
        PostRevisor.new(post).revise!(post.user, { raw: new_raw }, bypass_bump: true, edit_reason: 'Import attachments from NodeBB')
      end
    end
  end

  def postprocess_post(post)
    raw = post.raw

    # [link to post](/post/:id)
    raw = raw.gsub(/\[(.*)\]\(\/post\/(\d+).*\)/) do
      text, post_id = $1, $2

      if topic_lookup = topic_lookup_from_imported_post_id("p#{post_id}")
        url = topic_lookup[:url]
        "[#{text}](#{url})"
      else
        "/404"
      end
    end

    # [link to topic](/topic/:id)
    raw = raw.gsub(/\[(.*)\]\(\/topic\/(\d+).*\)/) do
      text, topic_id = $1, $2

      if topic_lookup = topic_lookup_from_imported_post_id("t#{topic_id}")
        url = topic_lookup[:url]
        "[#{text}](#{url})"
      else
        "/404"
      end
    end

    raw
  end
end

ImportScripts::NodeBB.new.perform
