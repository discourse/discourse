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
[:table,:td,:tr,:th,:thead,:tbody].each do |tag|
  ReverseMarkdown::Converters.unregister(tag)
end

class ImportScripts::Lithium < ImportScripts::Base
  BATCH_SIZE = 1000

  # CHANGE THESE BEFORE RUNNING THE IMPORTER
  DATABASE = "wd"
  PASSWORD = "password"
  CATEGORY_CSV = "/tmp/wd-cats.csv"
  UPLOAD_DIR = '/tmp/uploads'

  OLD_DOMAIN = 'community.wd.com'

  TEMP = ""

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

    SiteSetting.allow_html_tables = true

    import_categories
    import_users
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
        SELECT usergroupid, title
          FROM usergroup
      ORDER BY usergroupid
    SQL

    create_groups(groups) do |group|
      {
        id: group["usergroupid"],
        name: @htmlentities.decode(group["title"]).strip
      }
    end
  end

  def import_users
    puts "", "importing users"

    user_count = mysql_query("SELECT COUNT(*) count FROM users").first["count"]

    batches(BATCH_SIZE) do |offset|
      users = mysql_query <<-SQL
          SELECT id, nlogin, login_canon, email, registration_time
            FROM users
        ORDER BY id
           LIMIT #{BATCH_SIZE}
          OFFSET #{offset}
      SQL

      break if users.size < 1

      next if all_records_exist? :users, users.map {|u| u["id"].to_i}

      create_users(users, total: user_count, offset: offset) do |user|

        {
          id: user["id"],
          name: user["nlogin"],
          username: user["login-canon"],
          email: user["email"].presence || fake_email,
          # website: user["homepage"].strip,
          # title: @htmlentities.decode(user["usertitle"]).strip,
          # primary_group_id: group_id_from_imported_group_id(user["usergroupid"]),
          created_at: unix_time(user["registration_time"]),
          post_create_action: proc do |u|
            @old_username_to_new_usernames[user["username"]] = u.username
          end
        }
      end
    end
  end

  def unix_time(t)
    Time.at(t/1000.0)
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

    upload = Upload.create_for(imported_user.id, file, picture["filename"], file.size)

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

    upload = Upload.create_for(imported_user.id, file, background["filename"], file.size)

    return if !upload.persisted?

    imported_user.user_profile.update(profile_background: upload.url)
  ensure
    file.close rescue nil
    file.unlink rescue nil
  end

  def import_categories
    puts "", "importing top level categories..."

    categories = mysql_query("SELECT node_id, display_id, position, parent_node_id from nodes").to_a

    category_info = {}
    top_level_ids = Set.new
    child_ids = Set.new


    parent = nil
    CSV.foreach(CATEGORY_CSV) do |row|
      display_id = row[2].strip

      node = {
        name: (row[0] || row[1]).strip,
        secure: row[3] == "x",
        top_level: !!row[0]
      }

      if row[0]
        top_level_ids << display_id
        parent = node
      else
        child_ids << display_id
        node[:parent] = parent
      end

      category_info[display_id] = node

    end

    top_level_categories = categories.select { |c| top_level_ids.include? c["display_id"] }


    create_categories(top_level_categories) do |category|
      info = category_info[category["display_id"]]
      info[:id] = category["node_id"]

      {
        id: info[:id],
        name:  info[:name],
        position: category["position"]
      }
    end


    puts "", "importing children categories..."

    children_categories = categories.select { |c| child_ids.include? c["display_id"] }

    create_categories(children_categories) do |category|
      info = category_info[category["display_id"]]
      info[:id] = category["node_id"]

      {
        id: info[:id],
        name: info[:name],
        position: category["position"],
        parent_category_id: category_id_from_imported_category_id(info[:parent][:id])
      }
    end

    puts "", "securing categories"
    category_info.each do |_,info|
      if info[:secure]
        id = category_id_from_imported_category_id(info[:id])
        if id
          cat = Category.find(id)
          cat.set_permissions({})
          cat.save
          putc "."
        end
      end
    end

  end

  def import_topics
    puts "", "importing topics..."

    topic_count = mysql_query("SELECT COUNT(*) count FROM message2 where id = root_id").first["count"]

    batches(BATCH_SIZE) do |offset|
      topics = mysql_query <<-SQL
          SELECT id, subject, body, deleted, user_id,
                 post_date, views, node_id, unique_id
            FROM message2
        WHERE id = root_id #{TEMP} AND deleted = 0
        ORDER BY node_id, id
           LIMIT #{BATCH_SIZE}
          OFFSET #{offset}
      SQL

      break if topics.size < 1

      next if all_records_exist? :posts, topics.map {|topic| "#{topic["node_id"]} #{topic["id"]}"}

      create_posts(topics, total: topic_count, offset: offset) do |topic|

        category_id = category_id_from_imported_category_id(topic["node_id"])

        raw = topic["body"]

        if category_id
          {
            id: "#{topic["node_id"]} #{topic["id"]}",
            user_id: user_id_from_imported_user_id(topic["user_id"]) || Discourse::SYSTEM_USER_ID,
            title: @htmlentities.decode(topic["subject"]).strip[0...255],
            category: category_id,
            raw: raw,
            created_at: unix_time(topic["post_date"]),
            views: topic["views"],
            custom_fields: {import_unique_id: topic["unique_id"]},
            import_mode: true
          }
        else
          nil
        end

      end
    end
  end

  def import_posts
    puts "", "importing posts..."

    post_count = mysql_query("SELECT COUNT(*) count FROM message2
                              WHERE id <> root_id").first["count"]

    batches(BATCH_SIZE) do |offset|
      posts = mysql_query <<-SQL
          SELECT id, body, deleted, user_id,
                 post_date, parent_id, root_id, node_id, unique_id
            FROM message2
        WHERE id <> root_id #{TEMP} AND deleted = 0
        ORDER BY node_id, root_id, id
           LIMIT #{BATCH_SIZE}
          OFFSET #{offset}
      SQL

      break if posts.size < 1

      next if all_records_exist? :posts, posts.map {|post| "#{post["node_id"]} #{post["root_id"]} #{post["id"]}"}

      create_posts(posts, total: post_count, offset: offset) do |post|
        raw = post["raw"]
        next unless topic = topic_lookup_from_imported_post_id("#{post["node_id"]} #{post["root_id"]}")

        raw = post["body"]

        new_post = {
          id: "#{post["node_id"]} #{post["root_id"]} #{post["id"]}",
          user_id: user_id_from_imported_user_id(post["user_id"]) || Discourse::SYSTEM_USER_ID,
          topic_id: topic[:topic_id],
          raw: raw,
          created_at: unix_time(post["post_date"]),
          custom_fields: {import_unique_id: post["unique_id"]},
          import_mode: true
        }

        if post["deleted"] > 0
          new_post["deleted_at"] = Time.now
        end

        if parent = topic_lookup_from_imported_post_id("#{post["node_id"]} #{post["root_id"]} #{post["parent_id"]}")
          new_post[:reply_to_post_number] = parent[:post_number]
        end

        new_post
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
    "smileywink"  => "wink",
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

    sql = "select source_id user_id, target_id post_id, row_version created_at from wd.tag_events_score_message"
    results = mysql_query(sql)

    puts "loading unique id map"
    existing_map = {}
    PostCustomField.where(name: 'import_unique_id').pluck(:post_id, :value).each do |post_id, import_id|
      existing_map[import_id] = post_id
    end



    puts "loading data into temp table"
    PostAction.exec_sql("create temp table like_data(user_id int, post_id int, created_at timestamp without time zone)")
    PostAction.transaction do
      results.each do |result|

        result["user_id"] = user_id_from_imported_user_id(result["user_id"].to_s)
        result["post_id"] = existing_map[result["post_id"].to_s]

        next unless result["user_id"] && result["post_id"]

        PostAction.exec_sql("INSERT INTO like_data VALUES (:user_id,:post_id,:created_at)",
                              user_id: result["user_id"],
                              post_id: result["post_id"],
                              created_at: result["created_at"]
                           )

      end
    end

    puts "creating missing post actions"
    PostAction.exec_sql <<-SQL

    INSERT INTO post_actions (post_id, user_id, post_action_type_id, created_at, updated_at)
             SELECT l.post_id, l.user_id, 2, l.created_at, l.created_at FROM like_data l
             LEFT JOIN post_actions a ON a.post_id = l.post_id AND l.user_id = a.user_id AND a.post_action_type_id = 2
             WHERE a.id IS NULL
    SQL

    puts "creating missing user actions"
    UserAction.exec_sql <<-SQL
    INSERT INTO user_actions (user_id, action_type, target_topic_id, target_post_id, acting_user_id, created_at, updated_at)
             SELECT pa.user_id, 1, p.topic_id, p.id, pa.user_id, pa.created_at, pa.created_at
             FROM post_actions pa
             JOIN posts p ON p.id = pa.post_id
             LEFT JOIN user_actions ua ON action_type = 1 AND ua.target_post_id = pa.post_id AND ua.user_id = pa.user_id

             WHERE ua.id IS NULL AND pa.post_action_type_id = 2
    SQL


    # reverse action
    UserAction.exec_sql <<-SQL
    INSERT INTO user_actions (user_id, action_type, target_topic_id, target_post_id, acting_user_id, created_at, updated_at)
             SELECT p.user_id, 2, p.topic_id, p.id, pa.user_id, pa.created_at, pa.created_at
             FROM post_actions pa
             JOIN posts p ON p.id = pa.post_id
             LEFT JOIN user_actions ua ON action_type = 2 AND ua.target_post_id = pa.post_id AND
                ua.acting_user_id = pa.user_id AND ua.user_id = p.user_id

             WHERE ua.id IS NULL AND pa.post_action_type_id = 2
    SQL
    puts "updating like counts on posts"

    Post.exec_sql <<-SQL
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

    Post.exec_sql <<-SQL
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
    PostAction.exec_sql("create temp table accepted_data(post_id int primary key)")
    PostAction.transaction do
      results.each do |result|

        result["post_id"] = existing_map[result["post_id"].to_s]

        next unless result["post_id"]

        PostAction.exec_sql("INSERT INTO accepted_data VALUES (:post_id)",
                              post_id: result["post_id"]
                           )

      end
    end


    puts "deleting dupe answers"
    PostAction.exec_sql <<-SQL
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
    PostAction.exec_sql <<-SQL
      INSERT into post_custom_fields (name, value, post_id, created_at, updated_at)
      SELECT 'is_accepted_answer', 'true', a.post_id, current_timestamp, current_timestamp
      FROM accepted_data a
      LEFT JOIN post_custom_fields f ON name = 'is_accepted_answer' AND f.post_id = a.post_id
      WHERE f.id IS NULL
    SQL

    puts "marking accepted topics"
    PostAction.exec_sql <<-SQL
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

    [inbox,outbox].each do |r|
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
    User.pluck(:id, :username).each do |id,username|
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

      next if all_records_exist? :posts, topics.map {|topic| "pm_#{topic["note_id"]}"}

      create_posts(topics, total: topic_count, offset: offset) do |topic|

        user_id = user_id_from_imported_user_id(topic["sender_user_id"]) || Discourse::SYSTEM_USER_ID
        participants = users[topic["note_id"]]

        usernames = (participants - [user_id]).map{|id| user_map[id]}

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

    results.map{|r| r["post_id"]}.each_slice(500) do |ids|
      mapped = ids.map{|id| existing_map[id]}.compact
      Topic.exec_sql("
                     UPDATE topics SET closed = true
                     WHERE id IN (SELECT topic_id FROM posts where id in (:ids))
                     ", ids: mapped) if mapped.present?
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

    r = Permalink.exec_sql sql
    puts "#{r.cmd_tuples} permalinks to topics added!"

    sql = <<-SQL
    INSERT INTO permalinks (url, post_id, created_at, updated_at)
    SELECT '/p/' || value, p.id, current_timestamp, current_timestamp
    FROM post_custom_fields f
    JOIN posts p on f.post_id = p.id AND post_number <> 1
    LEFT JOIN permalinks pm ON url = '/p/' || value
    WHERE pm.id IS NULL AND f.name = 'import_unique_id'
SQL

    r = Permalink.exec_sql sql
    puts "#{r.cmd_tuples} permalinks to posts added!"

  end

  # find the uploaded file information from the db
  def find_upload(post, attachment_id)
    sql = "SELECT a.attachmentid attachment_id, a.userid user_id, a.filedataid file_id, a.filename filename,
                  a.caption caption
             FROM attachment a
            WHERE a.attachmentid = #{attachment_id}"
    results = mysql_query(sql)

    unless (row = results.first)
      puts "Couldn't find attachment record for post.id = #{post.id}, import_id = #{post.custom_fields['import_id']}"
      return nil
    end

    filename = File.join(ATTACHMENT_DIR, row['user_id'].to_s.split('').join('/'), "#{row['file_id']}.attach")
    unless File.exists?(filename)
      puts "Attachment file doesn't exist: #{filename}"
      return nil
    end
    real_filename = row['filename']
    real_filename.prepend SecureRandom.hex if real_filename[0] == '.'
    upload = create_upload(post.user.id, filename, real_filename)

    if upload.nil? || !upload.valid?
      puts "Upload not valid :("
      puts upload.errors.inspect if upload
      return nil
    end

    return upload, real_filename
  rescue Mysql2::Error => e
    puts "SQL Error"
    puts e.message
    puts sql
    return nil
  end

  def post_process_posts
    puts "", "Postprocessing posts..."

    current = 0
    max = Post.count

    Post.all.find_each do |post|
      begin
        new_raw = postprocess_post_raw(post.raw, post.user_id)
        post.raw = new_raw
        post.save
      rescue PrettyText::JavaScriptError
        nil
      ensure
        print_status(current += 1, max)
      end
    end
  end


  def postprocess_post_raw(raw, user_id)

    doc = Nokogiri::HTML.fragment(raw)

    doc.css("a,img").each do |l|
      uri = URI.parse(l["href"] || l["src"]) rescue nil
      if uri && uri.hostname == OLD_DOMAIN
        uri.hostname = nil
      end

      if uri && !uri.hostname
        if l["href"]
          l["href"] = uri.path
          # we have an internal link, lets see if we can remap it?
          permalink = Permalink.find_by_url(uri.path) rescue nil
          if l["href"] && permalink && permalink.target_url
            l["href"] = permalink.target_url
          end
        elsif l["src"]

          # we need an upload here
          upload_name = $1 if uri.path =~ /image-id\/([^\/]+)/
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
          end

          if image
            File.open(image) do |file|
              upload = Upload.create_for(user_id, file, "image." + (image =~ /.png$/ ? "png": "jpg"), File.size(image))
              l["src"] = upload.url
            end
          else
            puts "image was missing #{l["src"]}"
          end

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
    raw.gsub!(/([a-zA-Z0-9])&nbsp;([a-zA-Z0-9])/,"\\1 \\2")
    raw
  end

  def fake_email
    SecureRandom.hex << "@domain.com"
  end

  def mysql_query(sql)
    @client.query(sql, cache_rows: false)
  end

end

ImportScripts::Lithium.new.perform
