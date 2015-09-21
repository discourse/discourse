# custom importer for www.t-nation.com, feel free to borrow ideas

require 'mysql2'
require File.expand_path(File.dirname(__FILE__) + "/base.rb")

class ImportScripts::Tnation < ImportScripts::Base

  BATCH_SIZE = 1000

  # List of user custom fields that will be imported
  USER_CUSTOM_FIELDS = %w{WEIGHT HEIGHT}

  # Posts older than this date will *not* be imported
  THRESHOLD_DATE = 6.months.ago

  # Ordered list of category ids that will be imported
  MIGRATED_CATEGORY_IDS = [
    # Biotest Forums
    255, # Micro-PA Users
    236, # Biotest Supplement Advice
     23, # Supplements and Nutrition
     84, # Velocity Diet Support
    219, # Velocity Diet Recipes
    207, # Before / After Photos
    206, # Diet Logs
    # Training (87?, 61?)
     83, # Training Logs
    208, # Christian Thibaudeau Coaching
    250, # Jim Wendler 5/3/1 Coaching
    234, # Bigger Stronger Leaner
     39, # Bodybuilding
     29, # Powerlifting
    229, # Figure Athletes
     81, # Powerful Women
     64, # Over 35 Lifter
     62, # Beginners
     82, # Combat
    212, # Conditioning
    210, # Olympic Lifting
    211, # Strongman
    216, # Injuries and Rehab
    # Off Topic
      3, # Get a Life
     32, # Politics and World Issues
      6, # Rate My Physique Photos
    # Pharma
    217, # T Replacement
     40, # Steroids
  ]

  MIGRATED_CATEGORY_IDS_SQL = MIGRATED_CATEGORY_IDS.join(",")

  PARENT_CATEGORIES = ["Biotest Forums", "Training", "Off Topic", "Pharma"]

  PARENT_CATEGORY_ID = {
    # Biotest Forums
    255 => "biotest-forums",
    236 => "biotest-forums",
     23 => "biotest-forums",
     84 => "biotest-forums",
    219 => "biotest-forums",
    207 => "biotest-forums",
    206 => "biotest-forums",
    # Training
     83 => "training",
    208 => "training",
    250 => "training",
    234 => "training",
     39 => "training",
     29 => "training",
    229 => "training",
     81 => "training",
     64 => "training",
     62 => "training",
     82 => "training",
    212 => "training",
    210 => "training",
    211 => "training",
    216 => "training",
    # Off Topic
      3 => "off-topic",
     32 => "off-topic",
      6 => "off-topic",
    # Pharma
    217 => "pharma",
     40 => "pharma",
  }

  HIGHLIGHTED_CATEGORY_IDS = [255, 236, 23, 83, 208, 39].to_set

  def initialize
    super

    # load existing topics
    @topic_to_first_post_id = {}
    PostCustomField.where(name: 'import_topic_mapping').uniq.pluck(:value).each do |m|
      map = MultiJson.load(m)
      @topic_to_first_post_id[map[0]] = map[1]
    end

    # custom site settings
    SiteSetting.title = "T Nation Forums"
    SiteSetting.top_menu = "categories|latest|top|unread"

    SiteSetting.category_colors = "C03|A03"
    SiteSetting.limit_suggested_to_category = true
    SiteSetting.fixed_category_positions = true
    SiteSetting.show_subcategory_list = true
    SiteSetting.allow_uncategorized_topics = false
    SiteSetting.uncategorized_description = nil

    SiteSetting.enable_badges = false

    SiteSetting.authorized_extensions = "jpg|jpeg|png|gif|svg"
    SiteSetting.max_image_size_kb = 10_000.kilobytes
    SiteSetting.max_attachment_size_kb = 10_000.kilobytes
  end

  def execute
    list_imported_user_ids

    import_users
    import_categories
    import_posts

    build_topic_mapping

    update_topic_views
    close_locked_topics

    delete_banned_users

    download_avatars

    # TODO? handle edits?

    # TODO? mute_users (ignore_list)

    # TODO? watch_category (category_subscription, notify_category)
    # TODO? watch_topic (topic_subscription)
  end

  def list_imported_user_ids
    puts "", "listing imported user_ids..."

    author_ids = forum_query <<-SQL
      SELECT DISTINCT(author_id)
        FROM forum_message
       WHERE category_id IN (#{MIGRATED_CATEGORY_IDS_SQL})
         AND date >= '#{THRESHOLD_DATE}'
         AND topic_id NOT IN (SELECT topicId FROM topicDelete)
    SQL

    @imported_user_ids_sql = author_ids.to_a.map { |d| d["author_id"] }.join(",")
  end

  def import_users
    puts "", "importing users..."

    user_count = users_query("SELECT COUNT(id) AS count FROM user WHERE id IN (#{@imported_user_ids_sql})").first["count"]

    batches(BATCH_SIZE) do |offset|
      users = users_query <<-SQL
          SELECT id, username, email, active
            FROM user
           WHERE id IN (#{@imported_user_ids_sql})
        ORDER BY id
           LIMIT #{BATCH_SIZE}
          OFFSET #{offset}
      SQL

      users = users.to_a

      break if users.size < 1

      next if all_records_exist? :users, users.map {|u| u["id"].to_i}

      user_bios = {}
      user_avatars = {}
      user_properties = {}
      user_ids_sql = users.map { |u| u["id"] }.join(",")

      # properties
      attributes = users_query <<-SQL
        SELECT userid, pkey AS "key", TRIM(COALESCE(pvalue, "")) AS "value"
          FROM property
         WHERE userid IN (#{user_ids_sql})
           AND LENGTH(TRIM(COALESCE(pvalue, ""))) > 0
      SQL

      attributes.each do |a|
        user_properties[a["userid"]] ||= {}
        user_properties[a["userid"]][a["key"]] = a["value"]
      end

      # bios
      bios = forum_query <<-SQL
        SELECT uid, TRIM(COALESCE(quip, "")) AS "bio"
          FROM myt_oneliner
         WHERE uid IN (#{user_ids_sql})
           AND LENGTH(TRIM(COALESCE(quip, ""))) > 0
      SQL

      bios.each { |b| user_bios[b["uid"]] = b["bio"] }

      # avatars
      avatars = forum_query <<-SQL
        SELECT userid, filename
          FROM forum_avatar
         WHERE userid IN (#{user_ids_sql})
           AND width > 0
           AND height > 0
      SQL

      avatars.each { |a| user_avatars[a["userid"]] = a["filename"] }

      # actually create users
      create_users(users, total: user_count, offset: offset) do |user|
        properties = user_properties[user["id"]] || {}
        name = "#{properties["fname"]} #{properties["lname"]}".strip
        avatar_url = forum_avatar_url(user_avatars[user["id"]]) if user_avatars.include?(user["id"])

        {
          id: user["id"],
          name: name.presence || user["username"],
          username: user["username"],
          email: user["email"],
          created_at: properties["join_date"].presence || properties["JOIN_DATE"].presence,
          active: user["active"],
          website: properties["website"],
          location: properties["LOCATION"].presence || properties["city"].presence,
          date_of_birth: properties["BIRTHDATE"],
          bio_raw: user_bios[user["id"]],
          avatar_url: avatar_url,
          post_create_action: proc do |new_user|
            USER_CUSTOM_FIELDS.each do |field|
              new_user.custom_fields[field.downcase] = properties[field] if properties.include?(field)
            end
            new_user.save
          end
        }
      end
    end
  end

  def import_categories
    puts "", "importing categories..."

    position = Category.count

    # create parent categories
    create_categories(PARENT_CATEGORIES) do |c|
      {
        id: c.parameterize,
        name: c,
        description: c,
        color: "A03",
        position: position,
        post_create_action: proc do position += 1; end
      }
    end

    # children categories
    categories = forum_query <<-SQL
        SELECT id, name, description, is_veteran
          FROM forum_category
         WHERE id IN (#{MIGRATED_CATEGORY_IDS_SQL})
      ORDER BY id
    SQL

    create_categories(categories) do |category|
      name = category["name"].strip
      {
        id: category["id"],
        name: name,
        description: category["description"].strip.presence || name,
        position: MIGRATED_CATEGORY_IDS.index(category["id"]) + position,
        parent_category_id: category_id_from_imported_category_id(PARENT_CATEGORY_ID[category["id"]]),
        read_restricted: category["is_veteran"] == 1,
        color: HIGHLIGHTED_CATEGORY_IDS.include?(category["id"]) ? "C03" : "A03",
      }
    end
  end

  def import_posts
    puts "", "importing posts..."

    post_count = forum_query <<-SQL
      SELECT COUNT(id) AS count
        FROM forum_message
       WHERE author_id IN (#{@imported_user_ids_sql})
         AND category_id IN (#{MIGRATED_CATEGORY_IDS_SQL})
         AND date >= '#{THRESHOLD_DATE}'
         AND topic_id NOT IN (SELECT topicId FROM topicDelete)
         AND status = 1
         AND (edit_parent IS NULL OR edit_parent = -1)
         AND topic_id > 0
    SQL

    post_count = post_count.first["count"]

    batches(BATCH_SIZE) do |offset|
      posts = forum_query <<-SQL
          SELECT fm.id, fm.category_id, fm.topic_id, fm.date, fm.author_id, fm.subject, fm.message, ft.sticky
            FROM forum_message fm
       LEFT JOIN forum_topic ft ON fm.topic_id = ft.id
           WHERE fm.author_id IN (#{@imported_user_ids_sql})
             AND fm.category_id IN (#{MIGRATED_CATEGORY_IDS_SQL})
             AND fm.date >= '#{THRESHOLD_DATE}'
             AND fm.topic_id NOT IN (SELECT topicId FROM topicDelete)
             AND fm.status = 1
             AND (fm.edit_parent IS NULL OR fm.edit_parent = -1)
             AND fm.topic_id > 0
        ORDER BY fm.id
           LIMIT #{BATCH_SIZE}
          OFFSET #{offset}
      SQL

      posts = posts.to_a

      break if posts.size < 1
      next if all_records_exist? :posts, posts.map {|p| p['id'].to_i}

      # load images
      forum_images = {}
      message_ids_sql = posts.map { |p| p["id"] }.join(",")

      images = forum_query <<-SQL
        SELECT message_id, filename
          FROM forum_image
         WHERE message_id IN (#{message_ids_sql})
           AND width > 0
           AND height > 0
      SQL

      images.each do |image|
        forum_images[image["message_id"]] ||= []
        forum_images[image["message_id"]] << image["filename"]
      end

      create_posts(posts, total: post_count, offset: offset) do |post|
        raw = post["message"]

        if forum_images.include?(post["id"])
          forum_images[post["id"]].each do |filename|
            raw = forum_image_url(filename) + "\n\n" + raw
          end
        end

        p = {
          id: post["id"],
          user_id: user_id_from_imported_user_id(post["author_id"]) || -1,
          created_at: post["date"],
          raw: raw,
          custom_fields: {}
        }

        if @topic_to_first_post_id.include?(post["topic_id"]) && t = topic_lookup_from_imported_post_id(@topic_to_first_post_id[post["topic_id"]])
          first_post_id = @topic_to_first_post_id[post["topic_id"]]
          p[:topic_id] = t[:topic_id]
        else
          @topic_to_first_post_id[post["topic_id"]] = first_post_id = post["id"]
          p[:title] = post["subject"].strip
          p[:category] = category_id_from_imported_category_id(post["category_id"])
          p[:pinned_at] = post["date"] if post["sticky"] == 1
        end

        p[:custom_fields][:import_topic_mapping] = MultiJson.dump([post["topic_id"], first_post_id])

        p
      end
    end
  end

  def build_topic_mapping
    puts "", "building topic mapping..."

    @existing_topics = {}

    PostCustomField.where(name: 'import_topic_mapping').uniq.pluck(:value).each do |m|
      map = MultiJson.load(m)
      @existing_topics[map[0]] = topic_lookup_from_imported_post_id(map[1])[:topic_id]
    end

    @topic_ids_sql = @existing_topics.keys.join(",")
  end

  def update_topic_views
    puts "", "updating topic views..."

    topic_views = forum_query("SELECT topic_id, views FROM topic_views WHERE topic_id IN (#{@topic_ids_sql}) ORDER BY topic_id").to_a
    update_topic_views_sql = topic_views.map { |tv| "UPDATE topics SET views = #{tv['views']} WHERE id = #{@existing_topics[tv['topic_id']]}" }.join(";")
    postgresql_query(update_topic_views_sql)
  end

  def close_locked_topics
    puts "", "closing locked topics..."

    locked_topic_ids = forum_query("SELECT id FROM forum_topic WHERE id IN (#{@topic_ids_sql}) AND locked = 1 ORDER BY id").to_a.map { |d| d["id"] }

    current = 0
    max = locked_topic_ids.count

    locked_topic_ids.each do |id|
      print_status(current += 1, max)
      topic = Topic.find_by(id: @existing_topics[id])
      next if topic.blank?
      topic.update_status("closed", true, Discourse.system_user)
    end
  end

  def delete_banned_users
    puts "", "deleting banned users..."

    user_destroyer = UserDestroyer.new(Discourse.system_user)

    ids_from_banned_users = forum_query("SELECT user_id FROM banned_users WHERE user_id IN (#{@imported_user_ids_sql})").to_a.map { |d| @existing_users[d["user_id"]] }
    ids_from_cookie_of_death = forum_query("SELECT userid FROM cookie_of_death WHERE userid IN (#{@imported_user_ids_sql})").to_a.map { |d| @existing_users[d["userid"]] }

    banned_user_ids = (ids_from_banned_users.to_set | ids_from_cookie_of_death.to_set).to_a

    current = 0
    max = User.where(id: banned_user_ids).count

    User.where(id: banned_user_ids.to_a).find_each do |user|
      print_status(current += 1, max)
      user_destroyer.destroy(user, delete_posts: true)
    end
  end

  def download_avatars
    puts "", "downloading avatars..."

    current = 0
    max = UserCustomField.where(name: "import_avatar_url").count

    UserCustomField.where(name: "import_avatar_url").pluck(:user_id, :value).each do |user_id, avatar_url|
      begin
        print_status(current += 1, max)
        user = User.find(user_id)
        next unless user.uploaded_avatar_id.blank?
        avatar = FileHelper.download(avatar_url, SiteSetting.max_image_size_kb.kilobytes, "avatar")
        upload = Upload.create_for(user_id, avatar, File.basename(avatar_url), avatar.size)
        if upload.persisted?
          user.create_user_avatar
          user.user_avatar.update(custom_upload_id: upload.id)
          user.update(uploaded_avatar_id: upload.id)
        end
        avatar.try(:close!) rescue nil
      rescue OpenURI::HTTPError, Net::ReadTimeout
      end
    end
  end

  def forum_avatar_url(filename)
    "http://images.t-nation.com/avatar_images/#{filename[0]}/#{filename[1]}/#{filename}"
  end

  def forum_image_url(filename)
    "http://images.t-nation.com/forum_images/#{filename[0]}/#{filename[1]}/#{filename}"
  end

  # def forum_video_url(filename)
  #   "http://images.t-nation.com/forum_images/forum_video/fullSize/#{filename}.flv"
  # end

  def forum_query(sql)
    @biotest_forum ||= Mysql2::Client.new(username: "root", database: "biotest_forum")
    @biotest_forum.query(sql)
  end

  def users_query(sql)
    @biotest_users ||= Mysql2::Client.new(username: "root", database: "biotest_users")
    @biotest_users.query(sql)
  end

  def postgresql_query(sql)
    ActiveRecord::Base.connection.execute(sql)
  end

end

ImportScripts::Tnation.new.perform
