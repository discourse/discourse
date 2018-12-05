# Notes:
#
# Written by Sam
#
# Lithium are quite protective of data, there is no simple way of exporting
# If you have leverage you may get a data dump, in my case it was provided in XML
# format
#
# First step is to convert it to db format so you can import it into a DB
# that was done using import_scripts/support/convert_mysql_xml_to_mysql.rb
#

require 'mysql2'
require 'csv'
require 'reverse_markdown'
require File.expand_path(File.dirname(__FILE__) + "/base.rb")
require 'htmlentities'

# remove table conversion
[:table, :td, :tr, :th, :thead, :tbody].each do |tag|
  ReverseMarkdown::Converters.unregister(tag)
end

class ImportScripts::Lithium < ImportScripts::Base
  BATCH_SIZE = 1000

  # CHANGE THESE BEFORE RUNNING THE IMPORTER
  DATABASE = "wd"
  PASSWORD = "password"
  AVATAR_DIR = '/tmp/avatars'
  ATTACHMENT_DIR = '/tmp/attachments'
  UPLOAD_DIR = '/tmp/uploads'

  OLD_DOMAIN = 'community.wd.com'

  TEMP = ""

  USER_CUSTOM_FIELDS = [
    { name: "sso_id", user: "sso_id" },
    { name: "user_field_1", profile: "jobtitle" },
    { name: "user_field_2", profile: "company" },
    { name: "user_field_3", profile: "industry" },
  ]

  LITHIUM_PROFILE_FIELDS = "'profile.jobtitle', 'profile.company', 'profile.industry', 'profile.location'"

  USERNAME_MAPPINGS = {
    "admins": "admin_user"
  }.with_indifferent_access

  def initialize
    super

    @old_username_to_new_usernames = {}

    @htmlentities = HTMLEntities.new

    @client = Mysql2::Client.new(
      host: "localhost",
      username: "root",
      password: PASSWORD,
      database: DATABASE
    )
  end

  def execute

    @max_start_id = Post.maximum(:id)

    import_groups
    import_categories
    import_users
    import_user_visits
    import_topics
    import_posts
    import_likes
    import_accepted_answers
    import_pms
    close_topics
    create_permalinks

    post_process_posts
  end

  def import_groups
    puts "", "importing groups..."

    groups = mysql_query <<-SQL
        SELECT DISTINCT name
          FROM roles
      ORDER BY name
    SQL

    create_groups(groups) do |group|
      {
        id: group["name"],
        name: @htmlentities.decode(group["name"]).strip
      }
    end
  end

  def import_users
    puts "", "importing users"

    user_count = mysql_query("SELECT COUNT(*) count FROM users").first["count"]
    avatar_files = Dir.entries(AVATAR_DIR)
    duplicate_emails = mysql_query("SELECT email_lower FROM users GROUP BY email_lower HAVING COUNT(email_lower) > 1").map { |e| [e["email_lower"], 0] }.to_h

    batches(BATCH_SIZE) do |offset|
      users = mysql_query <<-SQL
          SELECT id, nlogin, login_canon, email, registration_time, sso_id
            FROM users
        ORDER BY id
           LIMIT #{BATCH_SIZE}
          OFFSET #{offset}
      SQL

      break if users.size < 1

      next if all_records_exist? :users, users.map { |u| u["id"].to_i }

      users = users.to_a
      first_id = users.first["id"]
      last_id = users.last["id"]

      profiles = mysql_query <<-SQL
          SELECT user_id, param, nvalue
            FROM user_profile
          WHERE nvalue IS NOT NULL AND param IN (#{LITHIUM_PROFILE_FIELDS}) AND user_id >= #{first_id} AND user_id <= #{last_id}
        ORDER BY user_id
      SQL

      create_users(users, total: user_count, offset: offset) do |user|
        user_id = user["id"]
        profile = profiles.select { |p|  p["user_id"] == user_id }
        result = profile.select { |p|  p["param"] == "profile.location" }
        location = result.count > 0 ? result.first["nvalue"] : nil
        username = user["login_canon"]
        username = USERNAME_MAPPINGS[username] if USERNAME_MAPPINGS[username].present?

        email = user["email"].presence || fake_email
        email_lower = email.downcase
        if duplicate_emails.key?(email_lower)
          duplicate_emails[email_lower] += 1
          email.sub!("@", "+#{duplicate_emails[email_lower]}@") if duplicate_emails[email_lower] > 1
        end

        {
          id: user_id,
          name: user["nlogin"],
          username: username,
          email: email,
          location: location,
          custom_fields: user_custom_fields(user, profile),
          # website: user["homepage"].strip,
          # title: @htmlentities.decode(user["usertitle"]).strip,
          # primary_group_id: group_id_from_imported_group_id(user["usergroupid"]),
          created_at: unix_time(user["registration_time"]),
          post_create_action: proc do |u|
            @old_username_to_new_usernames[user["login_canon"]] = u.username

            # import user avatar
            sso_id = u.custom_fields["sso_id"]
            if sso_id.present?
              prefix = "#{AVATAR_DIR}/#{sso_id}_"
              file = get_file(prefix + "actual.jpeg")
              file ||= get_file(prefix + "profile.jpeg")

              if file.present?
                upload = UploadCreator.new(file, file.path, type: "avatar").create_for(u.id)
                u.create_user_avatar unless u.user_avatar

                if !u.user_avatar.contains_upload?(upload.id)
                  u.user_avatar.update_columns(custom_upload_id: upload.id)

                  if u.uploaded_avatar_id.nil? ||
                    !u.user_avatar.contains_upload?(u.uploaded_avatar_id)
                    u.update_columns(uploaded_avatar_id: upload.id)
                  end
                end
              end
            end
          end
        }
      end
    end
  end

  def import_user_visits
    puts "", "importing user visits"

    batches(BATCH_SIZE) do |offset|
      visits = mysql_query <<-SQL
          SELECT user_id, login_time
            FROM user_log
        ORDER BY user_id
           LIMIT #{BATCH_SIZE}
          OFFSET #{offset}
      SQL

      break if visits.size < 1

      user_ids = visits.uniq { |v| v["user_id"] }

      user_ids.each do |user_id|
        user = UserCustomField.find_by(name: "import_id", value: user_id).try(:user)
        raise "User not found for id #{user_id}" if user.blank?

        user_visits = visits.select { |v| v["user_id"] == user_id }
        user_visits.each do |v|
          date = unix_time(v["login_time"])
          user.update_visit_record!(date)
        end
      end
    end
  end

  def user_custom_fields(user, profile)
    fields = Hash.new

    USER_CUSTOM_FIELDS.each do |attr|
      name = attr[:name]

      if attr[:user].present?
        fields[name] = user[attr[:user]]
      elsif attr[:profile].present? && profile.count > 0
        result = profile.select { |p|  p["param"] == "profile.#{attr[:profile]}" }
        fields[name] = result.first["nvalue"] if result.count > 0
      end
    end

    fields
  end

  def get_file(path)
    return File.open(path) if File.exist?(path)
    nil
  end

  def unix_time(t)
    Time.at(t / 1000.0)
  end

  def import_profile_picture(old_user, imported_user)
    query = mysql_query <<-SQL
        SELECT filedata, filename
          FROM customavatar
         WHERE userid = #{old_user["userid"]}
      ORDER BY dateline DESC
         LIMIT 1
    SQL

    picture = query.first

    return if picture.nil?

    file = Tempfile.new("profile-picture")
    file.write(picture["filedata"].encode("ASCII-8BIT").force_encoding("UTF-8"))
    file.rewind

    upload = UploadCreator.new(file, picture["filename"]).create_for(imported_user.id)

    return if !upload.persisted?

    imported_user.create_user_avatar
    imported_user.user_avatar.update(custom_upload_id: upload.id)
    imported_user.update(uploaded_avatar_id: upload.id)
  ensure
    file.close rescue nil
    file.unlind rescue nil
  end

  def import_profile_background(old_user, imported_user)
    query = mysql_query <<-SQL
        SELECT filedata, filename
          FROM customprofilepic
         WHERE userid = #{old_user["userid"]}
      ORDER BY dateline DESC
         LIMIT 1
    SQL

    background = query.first

    return if background.nil?

    file = Tempfile.new("profile-background")
    file.write(background["filedata"].encode("ASCII-8BIT").force_encoding("UTF-8"))
    file.rewind

    upload = UploadCreator.new(file, background["filename"]).create_for(imported_user.id)

    return if !upload.persisted?

    imported_user.user_profile.update(profile_background: upload.url)
  ensure
    file.close rescue nil
    file.unlink rescue nil
  end

  def import_categories
    puts "", "importing top level categories..."

    categories = mysql_query <<-SQL
        SELECT n.node_id, n.display_id, c.nvalue c_title, b.nvalue b_title, n.position, n.parent_node_id, n.type_id
          FROM nodes n
          LEFT JOIN settings c ON n.node_id = c.node_id AND c.param = 'category.title'
          LEFT JOIN settings b ON n.node_id = b.node_id AND b.param = 'board.title'
          ORDER BY n.type_id DESC, n.node_id ASC
    SQL

    categories = categories.map { |c| (c["name"] = c["c_title"] || c["b_title"] || c["display_id"]) && c }

    # To prevent duplicate category names
    categories = categories.map do |category|
      count = categories.to_a.count { |c| c["name"].present? && c["name"] == category["name"] }
      category["name"] << " (#{category["node_id"]})" if count > 1
      category
    end

    parent_categories = categories.select { |c| c["parent_node_id"] <= 2 }

    create_categories(parent_categories) do |category|
      {
        id: category["node_id"],
        name: category["name"],
        position: category["position"],
        post_create_action: lambda do |record|
          after_category_create(record, category)
        end
      }
    end

    puts "", "importing children categories..."

    children_categories = categories.select { |c| c["parent_node_id"] > 2 }

    create_categories(children_categories) do |category|
      {
        id: category["node_id"],
        name: category["name"],
        position: category["position"],
        parent_category_id: category_id_from_imported_category_id(category["parent_node_id"]),
        post_create_action: lambda do |record|
          after_category_create(record, category)
        end
      }
    end
  end

  def after_category_create(category, params)
    node_id = category.custom_fields["import_id"]
    roles = mysql_query <<-SQL
      SELECT name
        FROM roles
      WHERE node_id = #{node_id}
    SQL

    if roles.count > 0
      category.update(read_restricted: true)

      roles.each do |role|
        group_id = group_id_from_imported_group_id(role["name"])
        if group_id.present?
          CategoryGroup.find_or_create_by(category: category, group_id: group_id) do |cg|
            cg.permission_type = CategoryGroup.permission_types[:full]
          end
        else
          puts "", "Group not found for id '#{role["name"]}'"
        end
      end
    end

  end

  def staff_guardian
    @_staff_guardian ||= Guardian.new(Discourse.system_user)
  end

  def import_topics
    puts "", "importing topics..."
    SiteSetting.tagging_enabled = true
    default_max_tags_per_topic = SiteSetting.max_tags_per_topic
    default_max_tag_length = SiteSetting.max_tag_length
    SiteSetting.max_tags_per_topic = 10
    SiteSetting.max_tag_length = 100

    topic_count = mysql_query("SELECT COUNT(*) count FROM message2 where id = root_id").first["count"]
    topic_tags = mysql_query("SELECT e.target_id, GROUP_CONCAT(l.tag_text SEPARATOR ',') tags FROM tag_events_label_message e LEFT JOIN tags_label l ON e.tag_id = l.tag_id GROUP BY e.target_id")

    batches(BATCH_SIZE) do |offset|
      topics = mysql_query <<-SQL
          SELECT id, subject, body, deleted, user_id,
                 post_date, views, node_id, unique_id, row_version
            FROM message2
        WHERE id = root_id #{TEMP}
        ORDER BY node_id, id
           LIMIT #{BATCH_SIZE}
          OFFSET #{offset}
      SQL

      break if topics.size < 1

      next if all_records_exist? :posts, topics.map { |topic| "#{topic["node_id"]} #{topic["id"]}" }

      create_posts(topics, total: topic_count, offset: offset) do |topic|

        category_id = category_id_from_imported_category_id(topic["node_id"])
        deleted_at = topic["deleted"] == 1 ? topic["row_version"] : nil
        raw = topic["body"]

        if category_id.present? && raw.present?
          {
            id: "#{topic["node_id"]} #{topic["id"]}",
            user_id: user_id_from_imported_user_id(topic["user_id"]) || Discourse::SYSTEM_USER_ID,
            title: @htmlentities.decode(topic["subject"]).strip[0...255],
            category: category_id,
            raw: raw,
            created_at: unix_time(topic["post_date"]),
            deleted_at: deleted_at,
            views: topic["views"],
            custom_fields: { import_unique_id: topic["unique_id"] },
            import_mode: true,
            post_create_action: proc do |post|
              result = topic_tags.select { |t| t["target_id"] == topic["unique_id"] }
              if result.count > 0
                tag_names = result.first["tags"].split(",")
                DiscourseTagging.tag_topic_by_names(post.topic, staff_guardian, tag_names)
              end
            end
          }
        else
          message = "Unknown"
          message = "Category '#{category_id}' not exist" if category_id.blank?
          message = "Topic 'body' is empty" if raw.blank?
          PluginStoreRow.find_or_create_by(plugin_name: "topic_import_log", key: topic["unique_id"].to_s, value: message, type_name: 'String')
          nil
        end

      end
    end

    SiteSetting.max_tags_per_topic = default_max_tags_per_topic
    SiteSetting.max_tag_length = default_max_tag_length
  end

  def import_posts

    post_count = mysql_query("SELECT COUNT(*) count FROM message2
                              WHERE id <> root_id").first["count"]

    puts "", "importing posts... (#{post_count})"

    batches(BATCH_SIZE) do |offset|
      posts = mysql_query <<-SQL
          SELECT id, body, deleted, user_id,
                 post_date, parent_id, root_id, node_id, unique_id, row_version
            FROM message2
        WHERE id <> root_id #{TEMP}
        ORDER BY node_id, root_id, id
           LIMIT #{BATCH_SIZE}
          OFFSET #{offset}
      SQL

      break if posts.size < 1

      next if all_records_exist? :posts, posts.map { |post| "#{post["node_id"]} #{post["root_id"]} #{post["id"]}" }

      create_posts(posts, total: post_count, offset: offset) do |post|
        raw = post["raw"]
        next unless topic = topic_lookup_from_imported_post_id("#{post["node_id"]} #{post["root_id"]}")

        deleted_at = topic["deleted"] == 1 ? topic["row_version"] : nil
        raw = post["body"]

        if raw.present?
          new_post = {
            id: "#{post["node_id"]} #{post["root_id"]} #{post["id"]}",
            user_id: user_id_from_imported_user_id(post["user_id"]) || Discourse::SYSTEM_USER_ID,
            topic_id: topic[:topic_id],
            raw: raw,
            created_at: unix_time(post["post_date"]),
            deleted_at: deleted_at,
            custom_fields: { import_unique_id: post["unique_id"] },
            import_mode: true
          }

          if parent = topic_lookup_from_imported_post_id("#{post["node_id"]} #{post["root_id"]} #{post["parent_id"]}")
            new_post[:reply_to_post_number] = parent[:post_number]
          end

          new_post
        else
          PluginStoreRow.find_or_create_by(plugin_name: "post_import_log", key: post["unique_id"].to_s, value: "Post 'body' is empty", type_name: 'String')
          nil
        end
      end
    end
  end

  SMILEY_SUBS = {
    "smileyhappy" => "smiley",
    "smileyindifferent" => "neutral_face",
    "smileymad" => "angry",
    "smileysad" => "cry",
    "smileysurprised" => "dizzy_face",
    "smileytongue" => "stuck_out_tongue",
    "smileyvery-happy" => "grin",
    "smileywink" => "wink",
    "smileyfrustrated" => "confounded",
    "smileyembarrassed" => "flushed",
    "smileylol" => "laughing",
    "cathappy" => "smiley_cat",
    "catindifferent" => "cat",
    "catmad" => "smirk_cat",
    "catsad" => "crying_cat_face",
    "catsurprised" => "scream_cat",
    "cattongue" => "stuck_out_tongue",
    "catvery-happy" => "smile_cat",
    "catwink" => "wink",
    "catfrustrated" => "grumpycat",
    "catembarrassed" => "kissing_cat",
    "catlol" => "joy_cat"
  }

  def import_likes
    puts "\nimporting likes..."

    sql = "select source_id user_id, target_id post_id, row_version created_at from tag_events_score_message"
    results = mysql_query(sql)

    puts "loading unique id map"
    existing_map = {}
    PostCustomField.where(name: 'import_unique_id').pluck(:post_id, :value).each do |post_id, import_id|
      existing_map[import_id] = post_id
    end

    puts "loading data into temp table"
    DB.exec("create temp table like_data(user_id int, post_id int, created_at timestamp without time zone)")
    PostAction.transaction do
      results.each do |result|

        result["user_id"] = user_id_from_imported_user_id(result["user_id"].to_s)
        result["post_id"] = existing_map[result["post_id"].to_s]

        next unless result["user_id"] && result["post_id"]

        DB.exec("INSERT INTO like_data VALUES (:user_id,:post_id,:created_at)",
          user_id: result["user_id"],
          post_id: result["post_id"],
          created_at: result["created_at"]
        )

      end
    end

    puts "creating missing post actions"
    DB.exec <<~SQL

    INSERT INTO post_actions (post_id, user_id, post_action_type_id, created_at, updated_at)
             SELECT l.post_id, l.user_id, 2, l.created_at, l.created_at FROM like_data l
             LEFT JOIN post_actions a ON a.post_id = l.post_id AND l.user_id = a.user_id AND a.post_action_type_id = 2
             WHERE a.id IS NULL
    SQL

    puts "creating missing user actions"
    DB.exec <<~SQL
    INSERT INTO user_actions (user_id, action_type, target_topic_id, target_post_id, acting_user_id, created_at, updated_at)
             SELECT pa.user_id, 1, p.topic_id, p.id, pa.user_id, pa.created_at, pa.created_at
             FROM post_actions pa
             JOIN posts p ON p.id = pa.post_id
             LEFT JOIN user_actions ua ON action_type = 1 AND ua.target_post_id = pa.post_id AND ua.user_id = pa.user_id

             WHERE ua.id IS NULL AND pa.post_action_type_id = 2
    SQL

    # reverse action
    DB.exec <<~SQL
    INSERT INTO user_actions (user_id, action_type, target_topic_id, target_post_id, acting_user_id, created_at, updated_at)
             SELECT p.user_id, 2, p.topic_id, p.id, pa.user_id, pa.created_at, pa.created_at
             FROM post_actions pa
             JOIN posts p ON p.id = pa.post_id
             LEFT JOIN user_actions ua ON action_type = 2 AND ua.target_post_id = pa.post_id AND
                ua.acting_user_id = pa.user_id AND ua.user_id = p.user_id

             WHERE ua.id IS NULL AND pa.post_action_type_id = 2
    SQL
    puts "updating like counts on posts"

    DB.exec <<~SQL
        UPDATE posts SET like_count = coalesce(cnt,0)
                  FROM (
        SELECT post_id, count(*) cnt
        FROM post_actions
        WHERE post_action_type_id = 2 AND deleted_at IS NULL
        GROUP BY post_id
    ) x
    WHERE posts.like_count <> x.cnt AND posts.id = x.post_id

    SQL

    puts "updating like counts on topics"

    DB.exec <<-SQL
      UPDATE topics SET like_count = coalesce(cnt,0)
      FROM (
        SELECT topic_id, sum(like_count) cnt
        FROM posts
        WHERE deleted_at IS NULL
        GROUP BY topic_id
      ) x
      WHERE topics.like_count <> x.cnt AND topics.id = x.topic_id

    SQL
  end

  def import_accepted_answers

    puts "\nimporting accepted answers..."

    sql = "select unique_id post_id from message2 where (attributes & 0x4000 ) != 0 and deleted = 0;"
    results = mysql_query(sql)

    puts "loading unique id map"
    existing_map = {}
    PostCustomField.where(name: 'import_unique_id').pluck(:post_id, :value).each do |post_id, import_id|
      existing_map[import_id] = post_id
    end

    puts "loading data into temp table"
    DB.exec("create temp table accepted_data(post_id int primary key)")
    PostAction.transaction do
      results.each do |result|

        result["post_id"] = existing_map[result["post_id"].to_s]

        next unless result["post_id"]

        DB.exec("INSERT INTO accepted_data VALUES (:post_id)",
                              post_id: result["post_id"]
                           )

      end
    end

    puts "deleting dupe answers"
    DB.exec <<~SQL
    DELETE FROM accepted_data WHERE post_id NOT IN (
      SELECT post_id FROM
      (
        SELECT topic_id, MIN(post_id) post_id
        FROM accepted_data a
        JOIN posts p ON p.id = a.post_id
        GROUP BY topic_id
      ) X
    )
    SQL

    puts "importing accepted answers"
    DB.exec <<~SQL
      INSERT into post_custom_fields (name, value, post_id, created_at, updated_at)
      SELECT 'is_accepted_answer', 'true', a.post_id, current_timestamp, current_timestamp
      FROM accepted_data a
      LEFT JOIN post_custom_fields f ON name = 'is_accepted_answer' AND f.post_id = a.post_id
      WHERE f.id IS NULL
    SQL

    puts "marking accepted topics"
    DB.exec <<~SQL
      INSERT into topic_custom_fields (name, value, topic_id, created_at, updated_at)
      SELECT 'accepted_answer_post_id', a.post_id::varchar, p.topic_id, current_timestamp, current_timestamp
      FROM accepted_data a
      JOIN posts p ON p.id = a.post_id
      LEFT JOIN topic_custom_fields f ON name = 'accepted_answer_post_id' AND f.topic_id = p.topic_id
      WHERE f.id IS NULL
    SQL
    puts "done importing accepted answers"
  end

  def import_pms

    puts "", "importing pms..."

    puts "determining participation records"

    inbox = mysql_query("SELECT note_id, recipient_user_id user_id FROM tblia_notes_inbox")
    outbox = mysql_query("SELECT note_id, recipient_id user_id FROM tblia_notes_outbox")

    users = {}

    [inbox, outbox].each do |r|
      r.each do |row|
        ary = (users[row["note_id"]] ||= Set.new)
        user_id = user_id_from_imported_user_id(row["user_id"])
        ary << user_id if user_id
      end
    end

    puts "untangling PM soup"

    note_to_subject = {}
    subject_to_first_note = {}

    mysql_query("SELECT note_id, subject, sender_user_id FROM tblia_notes_content order by note_id").each do |row|
      user_id = user_id_from_imported_user_id(row["sender_user_id"])
        ary = (users[row["note_id"]] ||= Set.new)
        if user_id
          ary << user_id
        end
        note_to_subject[row["note_id"]] = row["subject"]

        if row["subject"] !~ /^Re: /
          subject_to_first_note[[row["subject"], ary]] ||= row["note_id"]
        end
    end

    puts "Loading user_id to username map"
    user_map = {}
    User.pluck(:id, :username).each do |id, username|
      user_map[id] = username
    end

    topic_count = mysql_query("SELECT COUNT(*) count FROM tblia_notes_content").first["count"]

    batches(BATCH_SIZE) do |offset|
      topics = mysql_query <<-SQL
          SELECT note_id, subject, body, sender_user_id, sent_time
            FROM tblia_notes_content
        ORDER BY note_id
           LIMIT #{BATCH_SIZE}
          OFFSET #{offset}
      SQL

      break if topics.size < 1

      next if all_records_exist? :posts, topics.map { |topic| "pm_#{topic["note_id"]}" }

      create_posts(topics, total: topic_count, offset: offset) do |topic|

        user_id = user_id_from_imported_user_id(topic["sender_user_id"]) || Discourse::SYSTEM_USER_ID
        participants = users[topic["note_id"]]

        usernames = (participants - [user_id]).map { |id| user_map[id] }

        subject = topic["subject"]
        topic_id = nil

        if subject =~ /^Re: /
          parent_id = subject_to_first_note[[subject[4..-1], participants]]
          if parent_id
            if t = topic_lookup_from_imported_post_id("pm_#{parent_id}")
              topic_id = t[:topic_id]
            end
          end
        end

        raw = topic["body"]

        if raw.present?
          msg = {
            id: "pm_#{topic["note_id"]}",
            user_id: user_id,
            raw: raw,
            created_at: unix_time(topic["sent_time"]),
            import_mode: true
          }

          unless topic_id
            msg[:title] = @htmlentities.decode(topic["subject"]).strip[0...255]
            msg[:archetype] = Archetype.private_message
            msg[:target_usernames] = usernames.join(',')
          else
            msg[:topic_id] = topic_id
          end

          msg
        else
          PluginStoreRow.find_or_create_by(plugin_name: "pm_import_log", key: topic["note_id"].to_s, value: "PM 'body' is empty", type_name: 'String')
          nil
        end
      end
    end

  end

  def close_topics

    puts "\nclosing closed topics..."

    sql = "select unique_id post_id from message2 where root_id = id AND (attributes & 0x0002 ) != 0;"
    results = mysql_query(sql)

    # loading post map
    existing_map = {}
    PostCustomField.where(name: 'import_unique_id').pluck(:post_id, :value).each do |post_id, import_id|
      existing_map[import_id.to_i] = post_id.to_i
    end

    results.map { |r| r["post_id"] }.each_slice(500) do |ids|
      mapped = ids.map { |id| existing_map[id] }.compact
      DB.exec(<<~SQL, ids: mapped) if mapped.present?
         UPDATE topics SET closed = true
         WHERE id IN (SELECT topic_id FROM posts where id in (:ids))
      SQL
    end

  end

  def create_permalinks
    puts "Creating permalinks"

    SiteSetting.permalink_normalizations = '/t5\\/.*p\\/(\\d+).*//p/\\1'

    sql = <<-SQL
    INSERT INTO permalinks (url, topic_id, created_at, updated_at)
    SELECT '/p/' || value, p.topic_id, current_timestamp, current_timestamp
    FROM post_custom_fields f
    JOIN posts p on f.post_id = p.id AND post_number = 1
    LEFT JOIN permalinks pm ON url = '/p/' || value
    WHERE pm.id IS NULL AND f.name = 'import_unique_id'
SQL

    r = DB.exec sql
    puts "#{r} permalinks to topics added!"

    sql = <<-SQL
    INSERT INTO permalinks (url, post_id, created_at, updated_at)
    SELECT '/p/' || value, p.id, current_timestamp, current_timestamp
    FROM post_custom_fields f
    JOIN posts p on f.post_id = p.id AND post_number <> 1
    LEFT JOIN permalinks pm ON url = '/p/' || value
    WHERE pm.id IS NULL AND f.name = 'import_unique_id'
SQL

    r = DB.exec sql
    puts "#{r} permalinks to posts added!"

  end

  def find_upload(user_id, attachment_id, real_filename)
    filename = attachment_id.to_s.rjust(4, "0")
    filename = File.join(ATTACHMENT_DIR, "000#{filename[0]}/#{filename}.dat")

    unless File.exists?(filename)
      puts "Attachment file doesn't exist: #{filename}"
      return nil
    end
    real_filename.prepend SecureRandom.hex if real_filename[0] == '.'
    upload = create_upload(user_id, filename, real_filename)

    if upload.nil? || !upload.valid?
      puts "Upload not valid :("
      puts upload.errors.inspect if upload
      return nil
    end

    return upload, real_filename
  end

  def post_process_posts
    puts "", "Postprocessing posts..."

    default_extensions = SiteSetting.authorized_extensions
    default_max_att_size = SiteSetting.max_attachment_size_kb
    SiteSetting.authorized_extensions = "*"
    SiteSetting.max_attachment_size_kb = 307200

    current = 0
    max = Post.count

    mysql_query("create index idxUniqueId on message2(unique_id)") rescue nil
    attachments = mysql_query("SELECT a.attachment_id, a.file_name, m.message_uid FROM tblia_attachment a INNER JOIN tblia_message_attachments m ON a.attachment_id = m.attachment_id")

    Post.where('id > ?', @max_start_id).find_each do |post|
      begin
        id = post.custom_fields["import_unique_id"]
        next unless id
        raw = mysql_query("select body from message2 where unique_id = '#{id}'").first['body']
        unless raw
          puts "Missing raw for post: #{post.id}"
          next
        end
        new_raw = postprocess_post_raw(raw, post.user_id)
        files = attachments.select { |a| a["message_uid"].to_s == id }
        new_raw << html_for_attachments(post.user_id, files)
        unless post.raw == new_raw
          post.raw = new_raw
          post.cooked = post.cook(new_raw)
          cpp = CookedPostProcessor.new(post)
          cpp.link_post_uploads
          post.custom_fields["import_post_process"] = true
          post.save
        end
      rescue PrettyText::JavaScriptError
        puts "GOT A JS error on post: #{post.id}"
        nil
      ensure
        print_status(current += 1, max)
      end
    end

    SiteSetting.authorized_extensions = default_extensions
    SiteSetting.max_attachment_size_kb = default_max_att_size
  end

  def postprocess_post_raw(raw, user_id)
    matches = raw.match(/<messagetemplate.*<\/messagetemplate>/m) || []
    matches.each do |match|
      hash = Hash.from_xml(match)
      template = hash["messagetemplate"]["zone"]["item"]
      content = (template[0] || template)["content"] || ""
      raw.sub!(match, content)
    end

    doc = Nokogiri::HTML.fragment(raw)

    doc.css("a,img,li-image").each do |l|
      upload_name, image, linked_upload = [nil] * 3

      if l.name == "li-image" && l["id"]
        upload_name = l["id"]
      else
        uri = URI.parse(l["href"] || l["src"]) rescue nil
        uri.hostname = nil if uri && uri.hostname == OLD_DOMAIN

        if uri && !uri.hostname
          if l["href"]
            l["href"] = uri.path
            # we have an internal link, lets see if we can remap it?
            permalink = Permalink.find_by_url(uri.path) rescue nil

            if l["href"]
              if permalink && permalink.target_url
                l["href"] = permalink.target_url
              elsif l["href"] =~ /^\/gartner\/attachments\/gartner\/([^.]*).(\w*)/
                linked_upload = "#{$1}.#{$2}"
              end
            end
          elsif l["src"]

            # we need an upload here
            upload_name = $1 if uri.path =~ /image-id\/([^\/]+)/
          end
        end
      end

      if upload_name
        png = UPLOAD_DIR + "/" + upload_name + ".png"
        jpg = UPLOAD_DIR + "/" + upload_name + ".jpg"
        gif = UPLOAD_DIR + "/" + upload_name + ".gif"

        # check to see if we have it
        if File.exist?(png)
          image = png
        elsif File.exists?(jpg)
          image = jpg
        elsif File.exists?(gif)
          image = gif
        end

        if image
          File.open(image) do |file|
            upload = UploadCreator.new(file, "image." + (image.ends_with?(".png") ? "png" : "jpg")).create_for(user_id)
            l.name = "img" if l.name == "li-image"
            l["src"] = upload.url
          end
        else
          puts "image was missing #{l["src"]}"
        end
      elsif linked_upload
        segments = linked_upload.match(/\/(\d*)\/(\d)\/([^.]*).(\w*)$/)

        if segments.present?
          lithium_post_id = segments[1]
          attachment_number = segments[2]

          result = mysql_query("select a.attachment_id, f.file_name from tblia_message_attachments a
            INNER JOIN message2 m ON a.message_uid = m.unique_id
            INNER JOIN tblia_attachment f ON a.attachment_id = f.attachment_id
            where m.id = #{lithium_post_id} AND a.attach_num = #{attachment_number} limit 0, 1")

          result.each do |row|
            upload, filename = find_upload(user_id, row["attachment_id"], row["file_name"])
            if upload.present?
              l["href"] = upload.url
            else
              puts "attachment was missing #{l["href"]}"
            end
          end
        end
      end

    end

    # for user mentions
    doc.css("li-user").each do |l|
      uid = l["uid"]

      if uid.present?
        user = UserCustomField.find_by(name: 'import_id', value: uid).try(:user)
        if user.present?
          username = user.username
          span = l.document.create_element "span"
          span.inner_html = "@#{username}"
          l.replace span
        end
      end
    end

    raw = ReverseMarkdown.convert(doc.to_s)
    raw.gsub!(/^\s*&nbsp;\s*$/, "")
    # ugly quotes
    raw.gsub!(/^>[\s\*]*$/, "")
    raw.gsub!(/:([a-z]+):/) do |match|
      ":#{SMILEY_SUBS[$1] || $1}:"
    end
    # nbsp central
    raw.gsub!(/([a-zA-Z0-9])&nbsp;([a-zA-Z0-9])/, "\\1 \\2")
    raw
  end

  def html_for_attachments(user_id, files)
    html = ""

    files.each do |file|
      upload, filename = find_upload(user_id, file["attachment_id"], file["file_name"])
      if upload.present?
        html << "\n" if html.present?
        html << html_for_upload(upload, filename)
      end
    end

    html
  end

  def mysql_query(sql)
    @client.query(sql, cache_rows: true)
  end

end

ImportScripts::Lithium.new.perform
