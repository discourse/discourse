# frozen_string_literal: true

require "mysql2"
require "reverse_markdown"
require File.expand_path(File.dirname(__FILE__) + "/base.rb")

class ImportScripts::IPBoard3 < ImportScripts::Base
  BATCH_SIZE = 5000
  UPLOADS_DIR = "/path/to/uploads"

  def initialize
    super

    @client =
      Mysql2::Client.new(
        host: ENV["DB_HOST"] || "localhost",
        username: ENV["DB_USER"] || "root",
        password: ENV["DB_PW"],
        database: ENV["DB_NAME"],
      )

    @client.query("SET character_set_results = binary")
  end

  def execute
    import_users
    import_categories
    import_topics
    import_posts
    close_topics
    import_personal_topics
    import_personal_posts
  end

  def import_users
    puts "", "importing users..."

    last_user_id = -1
    total_users = mysql_query("SELECT COUNT(*) count FROM members").first["count"]

    batches(BATCH_SIZE) do |offset|
      users = mysql_query(<<~SQL).to_a
        SELECT member_id id
             , name
             , email
             , joined
             , ip_address
             , title
             , CONCAT(bday_year, '-', bday_month, '-', bday_day) date_of_birth
             , last_activity
             , member_banned
             , g_title
             , pp_main_photo
             , pp_about_me
          FROM members
     LEFT JOIN groups ON member_group_id = g_id
     LEFT JOIN profile_portal ON member_id = pp_member_id
         WHERE member_id > #{last_user_id}
         ORDER BY member_id
         LIMIT #{BATCH_SIZE}
      SQL

      break if users.empty?

      last_user_id = users[-1]["id"]

      create_users(users, total: total_users, offset: offset) do |u|
        next if user_id_from_imported_user_id(u["id"])
        %W[name email title pp_about_me].each do |k|
          u[k]&.encode!("utf-8", "utf-8", invalid: :replace, undef: :replace, replace: "")
        end
        next if u["name"].blank? && !Email.is_valid?(u["email"])

        {
          id: u["id"],
          username: u["name"],
          email: u["email"],
          created_at: Time.zone.at(u["joined"]),
          registration_ip_address: u["ip_address"],
          title: CGI.unescapeHTML(u["title"].presence || ""),
          date_of_birth:
            (
              begin
                Date.parse(u["date_of_birth"])
              rescue StandardError
                nil
              end
            ),
          last_seen_at: Time.zone.at(u["last_activity"]),
          admin: !!(u["g_title"] =~ /admin/i),
          moderator: !!(u["g_title"] =~ /moderator/i),
          bio_raw: clean_up(u["pp_about_me"]),
          post_create_action:
            proc do |new_user|
              if u["member_banned"] == 1
                new_user.update(suspended_at: DateTime.now, suspended_till: 100.years.from_now)
              elsif u["pp_main_photo"].present?
                path = File.join(UPLOADS_DIR, u["pp_main_photo"])
                if File.exist?(path)
                  begin
                    upload = create_upload(new_user.id, path, File.basename(path))
                    if upload.persisted?
                      new_user.create_user_avatar
                      new_user.user_avatar.update(custom_upload_id: upload.id)
                      new_user.update(uploaded_avatar_id: upload.id)
                    end
                  rescue StandardError
                    # don't care
                  end
                end
              end
            end,
        }
      end
    end
  end

  def import_categories
    puts "", "importing categories..."

    categories =
      mysql_query("SELECT id, parent_id, name, description, position FROM forums ORDER BY id").to_a

    parent_categories = categories.select { |c| c["parent_id"] == -1 }
    child_categories = categories.select { |c| c["parent_id"] != -1 }

    create_categories(parent_categories) do |c|
      next if category_id_from_imported_category_id(c["id"])
      {
        id: c["id"],
        name: c["name"].encode("utf-8", "utf-8"),
        description: clean_up(c["description"]),
        position: c["position"],
      }
    end

    create_categories(child_categories) do |c|
      next if category_id_from_imported_category_id(c["id"])
      {
        id: c["id"],
        parent_category_id: category_id_from_imported_category_id(c["parent_id"]),
        name: c["name"].encode("utf-8", "utf-8"),
        description: clean_up(c["description"]),
        position: c["position"],
      }
    end
  end

  def import_topics
    puts "", "importing topics..."

    @closed_topic_ids = []

    last_topic_id = -1
    total_topics = mysql_query(<<~SQL).first["count"]
      SELECT COUNT(*) count
        FROM topics
        JOIN posts ON tid = topic_id
       WHERE tdelete_time = 0
         AND pdelete_time = 0
         AND new_topic = 1
         AND approved = 1
         AND queued = 0
    SQL

    batches(BATCH_SIZE) do |offset|
      topics = mysql_query(<<~SQL).to_a
        SELECT tid id
             , title
             , state
             , starter_id
             , start_date
             , views
             , forum_id
             , pinned
             , post
          FROM topics
          JOIN posts ON tid = topic_id
         WHERE tdelete_time = 0
           AND pdelete_time = 0
           AND new_topic = 1
           AND approved = 1
           AND queued = 0
           AND tid > #{last_topic_id}
         ORDER BY tid
         LIMIT #{BATCH_SIZE}
      SQL

      break if topics.empty?

      last_topic_id = topics[-1]["id"]

      create_posts(topics, total: total_topics, offset: offset) do |t|
        @closed_topic_ids << "t-#{t["id"]}" if t["state"] != "open"
        next if post_id_from_imported_post_id("t-#{t["id"]}")
        created_at = Time.zone.at(t["start_date"])
        user_id = user_id_from_imported_user_id(t["starter_id"]) || -1

        {
          id: "t-#{t["id"]}",
          title: CGI.unescapeHTML(t["title"].encode("utf-8", "utf-8")),
          user_id: user_id,
          created_at: created_at,
          views: t["views"],
          category: category_id_from_imported_category_id(t["forum_id"]),
          pinned_at: t["pinned"] == 1 ? created_at : nil,
          raw: clean_up(t["post"], user_id),
        }
      end
    end
  end

  def import_posts
    puts "", "importing posts..."

    last_post_id = -1
    total_posts = mysql_query(<<~SQL).first["count"]
      SELECT COUNT(*) count
        FROM posts
       WHERE new_topic = 0
         AND pdelete_time = 0
         AND queued = 0
    SQL

    batches(BATCH_SIZE) do |offset|
      posts = mysql_query(<<~SQL).to_a
        SELECT pid id
             , author_id
             , post_date
             , post
             , topic_id
          FROM posts
         WHERE new_topic = 0
           AND pdelete_time = 0
           AND queued = 0
           AND pid > #{last_post_id}
         ORDER BY pid
         LIMIT #{BATCH_SIZE}
      SQL

      break if posts.empty?

      last_post_id = posts[-1]["id"]

      create_posts(posts, total: total_posts, offset: offset) do |p|
        next if post_id_from_imported_post_id(p["id"])
        next unless t = topic_lookup_from_imported_post_id("t-#{p["topic_id"]}")
        user_id = user_id_from_imported_user_id(p["author_id"]) || -1

        {
          id: p["id"],
          user_id: user_id,
          created_at: Time.zone.at(p["post_date"]),
          raw: clean_up(p["post"], user_id),
          topic_id: t[:topic_id],
        }
      end
    end
  end

  def close_topics
    puts "", "closing #{@closed_topic_ids.size} topics..."

    sql = <<~SQL
      WITH closed_topic_ids AS (
        SELECT t.id AS topic_id
          FROM post_custom_fields pcf
          JOIN posts p ON p.id = pcf.post_id
          JOIN topics t ON t.id = p.topic_id
         WHERE pcf.name = 'import_id'
           AND pcf.value IN (?)
      )
      UPDATE topics
         SET closed = true
       WHERE id IN (SELECT topic_id FROM closed_topic_ids)
    SQL

    DB.exec(sql, @closed_topic_ids)
  end

  def import_personal_topics
    puts "", "import personal topics..."

    last_personal_topic_id = -1
    total_personal_topics = mysql_query(<<~SQL).first["count"]
      SELECT COUNT(*) count
        FROM message_topics
        JOIN message_posts ON msg_topic_id = mt_id
       WHERE mt_is_deleted = 0
         AND msg_is_first_post = 1
    SQL

    batches(BATCH_SIZE) do |offset|
      personal_topics = mysql_query(<<~SQL).to_a
        SELECT mt_id id
             , mt_date
             , mt_title
             , mt_starter_id
             , mt_to_member_id
             , mt_invited_members
             , msg_post
          FROM message_topics
          JOIN message_posts ON msg_topic_id = mt_id
         WHERE mt_is_deleted = 0
           AND msg_is_first_post = 1
           AND mt_id > #{last_personal_topic_id}
         ORDER BY mt_id
         LIMIT #{BATCH_SIZE}
      SQL

      break if personal_topics.empty?

      last_personal_topic_id = personal_topics[-1]["id"]

      create_posts(personal_topics, total: total_personal_topics, offset: offset) do |pt|
        next if post_id_from_imported_post_id("pt-#{pt["id"]}")
        user_id = user_id_from_imported_user_id(pt["mt_starter_id"]) || -1

        user_ids =
          [pt["mt_to_member_id"]] + pt["mt_invited_members"].scan(/i:(\d+);/).flatten.map(&:to_i)
        user_ids.map! { |id| user_id_from_imported_user_id(id) }
        user_ids.compact!
        user_ids.uniq!

        {
          archetype: Archetype.private_message,
          id: "pt-#{pt["id"]}",
          created_at: Time.zone.at(pt["mt_date"]),
          title: CGI.unescapeHTML(pt["mt_title"].encode("utf-8", "utf-8")),
          user_id: user_id,
          target_usernames: User.where(id: user_ids).pluck(:username),
          raw: clean_up(pt["msg_post"], user_id),
        }
      end
    end
  end

  def import_personal_posts
    puts "", "importing personal posts..."

    last_personal_post_id = -1
    total_personal_posts =
      mysql_query("SELECT COUNT(*) count FROM message_posts WHERE msg_is_first_post = 0").first[
        "count"
      ]

    batches(BATCH_SIZE) do |offset|
      personal_posts = mysql_query(<<~SQL).to_a
        SELECT msg_id id
             , msg_topic_id
             , msg_date
             , msg_post
             , msg_author_id
          FROM message_posts
         WHERE msg_is_first_post = 0
           AND msg_id > #{last_personal_post_id}
         ORDER BY msg_id
         LIMIT #{BATCH_SIZE}
      SQL

      break if personal_posts.empty?

      last_personal_post_id = personal_posts[-1]["id"]

      create_posts(personal_posts, total: total_personal_posts, offset: offset) do |pp|
        next if post_id_from_imported_post_id("pp-#{pp["id"]}")
        next unless t = topic_lookup_from_imported_post_id("pt-#{pp["msg_topic_id"]}")
        user_id = user_id_from_imported_user_id(pp["msg_author_id"]) || -1

        {
          id: "pp-#{pp["id"]}",
          topic_id: t[:topic_id],
          created_at: Time.zone.at(pp["msg_date"]),
          raw: clean_up(pp["msg_post"], user_id),
          user_id: user_id,
        }
      end
    end
  end

  def clean_up(raw, user_id = -1)
    raw.encode!("utf-8", "utf-8", invalid: :replace, undef: :replace, replace: "")

    raw.gsub!(%r{<(.+)>&nbsp;</\1>}, "\n\n")

    doc = Nokogiri::HTML5.fragment(raw)

    doc
      .css("blockquote.ipsBlockquote")
      .each do |bq|
        post_id = post_id_from_imported_post_id(bq["data-cid"])
        if post = Post.find_by(id: post_id)
          bq.replace %{<br>[quote="#{post.user.username},post:#{post.post_number},topic:#{post.topic_id}"]\n#{bq.inner_html}\n[/quote]<br>}
        end
      end

    markdown = ReverseMarkdown.convert(doc.to_html)

    markdown.gsub!(/\[attachment=(\d+):.+\]/) do
      if a =
           mysql_query(
             "SELECT attach_file, attach_location FROM attachments WHERE attach_id = #{$1}",
           ).first
        path = File.join(UPLOADS_DIR, a["attach_location"])
        if File.exist?(path)
          begin
            upload = create_upload(user_id, path, a["attach_file"])
            return html_for_upload(upload, a["attach_file"]) if upload.persisted?
          rescue StandardError
          end
        end
      end
    end

    markdown
  end

  def mysql_query(sql)
    @client.query(sql)
  end
end

ImportScripts::IPBoard3.new.perform
