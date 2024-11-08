# encoding: utf-8
# frozen_string_literal: true

#
# Author: Erick Guan <fantasticfears@gmail.com>
#
# This script import the data from latest Discuz! X
# Should work among Discuz! X3.x
# This script is tested only on Simplified Chinese Discuz! X instances
# If you want to import data other than Simplified Chinese, email me.

require "php_serialize"
require "miro"
require "mysql2"
require File.expand_path(File.dirname(__FILE__) + "/base.rb")

class ImportScripts::DiscuzX < ImportScripts::Base
  DISCUZX_DB = "ultrax"
  DB_TABLE_PREFIX = "pre_"
  BATCH_SIZE = 1000
  ORIGINAL_SITE_PREFIX = "oldsite.example.com/forums" # without http(s)://
  NEW_SITE_PREFIX = "http://discourse.example.com" # with http:// or https://

  # Set DISCUZX_BASE_DIR to the base directory of your discuz installation.
  DISCUZX_BASE_DIR = "/var/www/discuz/upload"
  AVATAR_DIR = "/uc_server/data/avatar"
  ATTACHMENT_DIR = "/data/attachment/forum"
  AUTHORIZED_EXTENSIONS = %w[jpg jpeg png gif zip rar pdf].freeze

  def initialize
    super

    @client =
      Mysql2::Client.new(
        host: "localhost",
        username: "root",
        #password: "password",
        database: DISCUZX_DB,
      )
    @first_post_id_by_topic_id = {}

    @internal_url_regexps = [
      %r{http(?:s)?://#{ORIGINAL_SITE_PREFIX.gsub(".", '\.')}/forum\.php\?mod=viewthread(?:&|&amp;)tid=(?<tid>\d+)(?:[^\[\]\s]*)(?:pid=?(?<pid>\d+))?(?:[^\[\]\s]*)},
      %r{http(?:s)?://#{ORIGINAL_SITE_PREFIX.gsub(".", '\.')}/viewthread\.php\?tid=(?<tid>\d+)(?:[^\[\]\s]*)(?:pid=?(?<pid>\d+))?(?:[^\[\]\s]*)},
      %r{http(?:s)?://#{ORIGINAL_SITE_PREFIX.gsub(".", '\.')}/forum\.php\?mod=redirect(?:&|&amp;)goto=findpost(?:&|&amp;)pid=(?<pid>\d+)(?:&|&amp;)ptid=(?<tid>\d+)(?:[^\[\]\s]*)},
      %r{http(?:s)?://#{ORIGINAL_SITE_PREFIX.gsub(".", '\.')}/redirect\.php\?goto=findpost(?:&|&amp;)pid=(?<pid>\d+)(?:&|&amp;)ptid=(?<tid>\d+)(?:[^\[\]\s]*)},
      %r{http(?:s)?://#{ORIGINAL_SITE_PREFIX.gsub(".", '\.')}/forumdisplay\.php\?fid=(?<fid>\d+)(?:[^\[\]\s]*)},
      %r{http(?:s)?://#{ORIGINAL_SITE_PREFIX.gsub(".", '\.')}/forum\.php\?mod=forumdisplay(?:&|&amp;)fid=(?<fid>\d+)(?:[^\[\]\s]*)},
      %r{http(?:s)?://#{ORIGINAL_SITE_PREFIX.gsub(".", '\.')}/(?<action>index)\.php(?:[^\[\]\s]*)},
      %r{http(?:s)?://#{ORIGINAL_SITE_PREFIX.gsub(".", '\.')}/(?<action>stats)\.php(?:[^\[\]\s]*)},
      %r{http(?:s)?://#{ORIGINAL_SITE_PREFIX.gsub(".", '\.')}/misc.php\?mod=(?<mod>stat|ranklist)(?:[^\[\]\s]*)},
    ]
  end

  def execute
    get_knowledge_about_duplicated_email
    import_users
    import_categories
    import_posts
    import_private_messages
    import_attachments
  end

  # add the prefix to the table name
  def table_name(name = nil)
    DB_TABLE_PREFIX + name
  end

  # find which group members can be granted as admin
  def get_knowledge_about_group
    group_table = table_name "common_usergroup"
    result =
      mysql_query(
        "SELECT groupid group_id, radminid role_id
             FROM #{group_table};",
      )
    @moderator_group_id = []
    @admin_group_id = []
    #@banned_group_id = [4,5] # 禁止的用户及其帖子均不导入，如果你想导入这些用户和帖子，请把这个数组清空。

    result.each do |group|
      case group["role_id"]
      when 1 # 管理员
        @admin_group_id << group["group_id"]
      when 2,
           3 # 超级版主、版主。如果你不希望原普通版主成为Discourse版主，把3去掉。
        @moderator_group_id << group["group_id"]
      end
    end
  end

  def get_knowledge_about_category_slug
    @category_slug = {}
    results =
      mysql_query(
        "SELECT svalue value
      FROM #{table_name "common_setting"}
      WHERE skey = 'forumkeys'",
      )

    return if results.size < 1
    value = results.first["value"]

    return if value.blank?

    PHP
      .unserialize(value)
      .each do |category_import_id, slug|
        next if slug.blank?
        @category_slug[category_import_id] = slug
      end
  end

  def get_knowledge_about_duplicated_email
    @duplicated_email = {}
    results =
      mysql_query(
        "select a.uid uid, b.uid import_id from pre_common_member a
        join (select uid, email from pre_common_member group by email having count(email) > 1 order by uid asc) b USING(email)
        where a.uid != b.uid",
      )

    users = @lookup.instance_variable_get :@users

    results.each do |row|
      @duplicated_email[row["uid"]] = row["import_id"]
      user_id = users[row["import_id"]]
      users[row["uid"]] = user_id if user_id
    end
  end

  def import_users
    puts "", "creating users"

    get_knowledge_about_group

    sensitive_user_table = table_name "ucenter_members"
    user_table = table_name "common_member"
    profile_table = table_name "common_member_profile"
    status_table = table_name "common_member_status"
    forum_table = table_name "common_member_field_forum"
    home_table = table_name "common_member_field_home"
    total_count = mysql_query("SELECT count(*) count FROM #{user_table};").first["count"]

    batches(BATCH_SIZE) do |offset|
      results =
        mysql_query(
          "SELECT u.uid id, u.username username, u.email email, u.groupid group_id,
                    su.regdate regdate, su.password password_hash, su.salt salt,
                    s.regip regip, s.lastip last_visit_ip, s.lastvisit last_visit_time, s.lastpost last_posted_at, s.lastsendmail last_emailed_at,
                    u.emailstatus email_confirmed, u.avatarstatus avatar_exists,
                    p.site website, p.address address, p.bio bio, p.realname realname, p.qq qq,
                    p.resideprovince resideprovince, p.residecity residecity, p.residedist residedist, p.residecommunity residecommunity,
                    p.resideprovince birthprovince, p.birthcity birthcity, p.birthdist birthdist, p.birthcommunity birthcommunity,
                    h.spacecss spacecss, h.spacenote spacenote,
                    f.customstatus customstatus, f.sightml sightml
               FROM #{user_table} u
               LEFT JOIN #{sensitive_user_table} su USING(uid)
               LEFT JOIN #{profile_table} p USING(uid)
               LEFT JOIN #{status_table} s USING(uid)
               LEFT JOIN #{forum_table} f USING(uid)
               LEFT JOIN #{home_table} h USING(uid)
              ORDER BY u.uid ASC
              LIMIT #{BATCH_SIZE}
             OFFSET #{offset};",
        )

      break if results.size < 1

      # TODO: breaks the script reported by some users
      # next if all_records_exist? :users, users.map {|u| u["id"].to_i}

      create_users(results, total: total_count, offset: offset) do |user|
        {
          id: user["id"],
          email: user["email"],
          username: user["username"],
          name: first_exists(user["realname"], user["customstatus"], user["username"]),
          import_pass: user["password_hash"],
          active: true,
          salt: user["salt"],
          # TODO: title: user['customstatus'], # move custom title to name since discourse can't let user custom title https://meta.discourse.org/t/let-users-custom-their-title/37626
          created_at: user["regdate"] ? Time.zone.at(user["regdate"]) : nil,
          registration_ip_address: user["regip"],
          ip_address: user["last_visit_ip"],
          last_seen_at: user["last_visit_time"],
          last_emailed_at: user["last_emailed_at"],
          last_posted_at: user["last_posted_at"],
          moderator: @moderator_group_id.include?(user["group_id"]),
          admin: @admin_group_id.include?(user["group_id"]),
          website:
            (user["website"] && user["website"].include?(".")) ?
              user["website"].strip :
              if (
                   user["qq"] && user["qq"].strip == (user["qq"].strip.to_i) &&
                     user["qq"].strip.to_i > (10_000)
                 )
                "http://user.qzone.qq.com/" + user["qq"].strip
              else
                nil
              end,
          bio_raw:
            first_exists(
              (user["bio"] && CGI.unescapeHTML(user["bio"])),
              user["sightml"],
              user["spacenote"],
            ).strip[
              0,
              3000
            ],
          location:
            first_exists(
              user["address"],
              (
                if !user["resideprovince"].blank?
                  [
                    user["resideprovince"],
                    user["residecity"],
                    user["residedist"],
                    user["residecommunity"],
                  ]
                else
                  [
                    user["birthprovince"],
                    user["birthcity"],
                    user["birthdist"],
                    user["birthcommunity"],
                  ]
                end
              ).reject { |location| location.blank? }.join(" "),
            ),
          post_create_action:
            lambda do |newmember|
              if user["avatar_exists"] == (1) && newmember.uploaded_avatar_id.blank?
                path, filename = discuzx_avatar_fullpath(user["id"])
                if path
                  begin
                    upload = create_upload(newmember.id, path, filename)
                    if !upload.nil? && upload.persisted?
                      newmember.import_mode = false
                      newmember.create_user_avatar
                      newmember.import_mode = true
                      newmember.user_avatar.update(custom_upload_id: upload.id)
                      newmember.update(uploaded_avatar_id: upload.id)
                    else
                      puts "Error: Upload did not persist!"
                    end
                  rescue SystemCallError => err
                    puts "Could not import avatar: #{err.message}"
                  end
                end
              end
              if !user["spacecss"].blank? && newmember.user_profile.profile_background_upload.blank?
                # profile background
                if matched = user["spacecss"].match(/body\s*{[^}]*url\('?(.+?)'?\)/i)
                  body_background = matched[1].split(ORIGINAL_SITE_PREFIX, 2).last
                end
                if matched = user["spacecss"].match(/#hd\s*{[^}]*url\('?(.+?)'?\)/i)
                  header_background = matched[1].split(ORIGINAL_SITE_PREFIX, 2).last
                end
                if matched = user["spacecss"].match(/.blocktitle\s*{[^}]*url\('?(.+?)'?\)/i)
                  blocktitle_background = matched[1].split(ORIGINAL_SITE_PREFIX, 2).last
                end
                if matched = user["spacecss"].match(/#ct\s*{[^}]*url\('?(.+?)'?\)/i)
                  content_background = matched[1].split(ORIGINAL_SITE_PREFIX, 2).last
                end

                if body_background || header_background || blocktitle_background ||
                     content_background
                  profile_background =
                    first_exists(
                      header_background,
                      body_background,
                      content_background,
                      blocktitle_background,
                    )
                  card_background =
                    first_exists(
                      content_background,
                      body_background,
                      header_background,
                      blocktitle_background,
                    )
                  upload =
                    create_upload(
                      newmember.id,
                      File.join(DISCUZX_BASE_DIR, profile_background),
                      File.basename(profile_background),
                    )
                  if upload
                    newmember.user_profile.upload_profile_background upload
                  else
                    puts "WARNING: #{user["username"]} (UID: #{user["id"]}) profile_background file did not persist!"
                  end
                  upload =
                    create_upload(
                      newmember.id,
                      File.join(DISCUZX_BASE_DIR, card_background),
                      File.basename(card_background),
                    )
                  if upload
                    newmember.user_profile.upload_card_background upload
                  else
                    puts "WARNING: #{user["username"]} (UID: #{user["id"]}) card_background file did not persist!"
                  end
                end
              end

              # we don't send email to the unconfirmed user
              if newmember.email_digests
                newmember.update(email_digests: user["email_confirmed"] == 1)
              end
              if !newmember.name.blank? && newmember.name == (newmember.username)
                newmember.update(name: "")
              end
            end,
        }
      end
    end
  end

  def import_categories
    puts "", "creating categories"

    get_knowledge_about_category_slug

    forums_table = table_name "forum_forum"
    forums_data_table = table_name "forum_forumfield"

    results =
      mysql_query(
        "
          SELECT f.fid id, f.fup parent_id, f.name, f.type type, f.status status, f.displayorder position,
                 d.description description, d.rules rules, d.icon, d.extra extra
            FROM #{forums_table} f
            LEFT JOIN #{forums_data_table} d USING(fid)
           ORDER BY parent_id ASC, id ASC
        ",
      )

    max_position = Category.all.max_by(&:position).position
    create_categories(results) do |row|
      next if row["type"] == ("group") || row["status"] == (2) # or row['status'].to_i == 3 # 如果不想导入群组，取消注释
      extra = PHP.unserialize(row["extra"]) if !row["extra"].blank?
      color = extra["namecolor"][1, 6] if extra && !extra["namecolor"].blank?

      Category.all.max_by(&:position).position

      h = {
        id: row["id"],
        name: row["name"],
        description: row["description"],
        position: row["position"].to_i + max_position,
        color: color,
        post_create_action:
          lambda do |category|
            if slug = @category_slug[row["id"]]
              category.update(slug: slug)
            end

            raw = process_discuzx_post(row["rules"], nil)
            if @bbcode_to_md
              raw =
                begin
                  raw.bbcode_to_md(false)
                rescue StandardError
                  raw
                end
            end
            category.topic.posts.first.update_attribute(:raw, raw)
            if !row["icon"].empty?
              upload =
                create_upload(
                  Discourse::SYSTEM_USER_ID,
                  File.join(DISCUZX_BASE_DIR, ATTACHMENT_DIR, "../common", row["icon"]),
                  File.basename(row["icon"]),
                )
              if upload
                category.uploaded_logo_id = upload.id
                # FIXME: I don't know how to get '/shared' by script. May change to Rails.root
                category.color =
                  Miro::DominantColors.new(File.join("/shared", upload.url)).to_hex.first[
                    1,
                    6
                  ] if !color
                category.save!
              end
            end

            if row["status"] == (0) || row["status"] == (3)
              SiteSetting.default_categories_muted = [
                SiteSetting.default_categories_muted,
                category.id,
              ].reject(&:blank?).join("|")
            end
            category
          end,
      }
      if row["parent_id"].to_i > 0
        h[:parent_category_id] = category_id_from_imported_category_id(row["parent_id"])
      end
      h
    end
  end

  def import_posts
    puts "", "creating topics and posts"

    users_table = table_name "common_member"
    posts_table = table_name "forum_post"
    topics_table = table_name "forum_thread"

    total_count = mysql_query("SELECT count(*) count FROM #{posts_table}").first["count"]

    batches(BATCH_SIZE) do |offset|
      results =
        mysql_query(
          "
            SELECT p.pid id,
                   p.tid topic_id,
                   t.fid category_id,
                   t.subject title,
                   p.authorid user_id,
                   p.message raw,
                   p.dateline post_time,
                   p2.pid first_id,
                   p.invisible status,
                   t.special special
              FROM #{posts_table} p
              JOIN #{posts_table} p2 ON p2.first AND p2.tid = p.tid
              JOIN #{topics_table} t ON t.tid = p.tid
             ORDER BY id ASC, topic_id ASC
             LIMIT #{BATCH_SIZE}
            OFFSET #{offset};
          ",
        )
      # u.status != -1 AND u.groupid != 4 AND u.groupid != 5 用户未被锁定、禁访或禁言。在现实中的 Discuz 论坛，禁止的用户通常是广告机或驱逐的用户，这些不需要导入。
      break if results.size < 1

      next if all_records_exist? :posts, results.map { |p| p["id"].to_i }

      create_posts(results, total: total_count, offset: offset) do |m|
        skip = false
        mapped = {}

        mapped[:id] = m["id"]
        mapped[:user_id] = user_id_from_imported_user_id(m["user_id"]) || -1
        mapped[:raw] = process_discuzx_post(m["raw"], m["id"])
        mapped[:created_at] = Time.zone.at(m["post_time"])
        mapped[:tags] = m["tags"]

        if m["id"] == m["first_id"]
          mapped[:category] = category_id_from_imported_category_id(m["category_id"])
          mapped[:title] = CGI.unescapeHTML(m["title"])

          if m["special"] == 1
            results =
              mysql_query(
                "
              SELECT multiple, maxchoices
              FROM #{table_name "forum_poll"}
              WHERE tid = #{m["topic_id"]}",
              )
            poll = results.first || {}
            results =
              mysql_query(
                "
              SELECT polloption
              FROM #{table_name "forum_polloption"}
              WHERE tid = #{m["topic_id"]}
              ORDER BY displayorder",
              )
            if results.empty?
              puts "WARNING: can't find poll options for topic #{m["topic_id"]}, skip poll"
            else
              mapped[
                :raw
              ].prepend "[poll#{poll["multiple"] ? " type=multiple" : ""}#{poll["maxchoices"] > 0 ? " max=#{poll["maxchoices"]}" : ""}]\n#{results.map { |option| "- " + option["polloption"] }.join("\n")}\n[/poll]\n"
            end
          end
        else
          parent = topic_lookup_from_imported_post_id(m["first_id"])

          if parent
            mapped[:topic_id] = parent[:topic_id]
            reply_post_import_id = find_post_id_by_quote_number(m["raw"])
            if reply_post_import_id
              post_id = post_id_from_imported_post_id(reply_post_import_id.to_i)
              if (post = Post.find_by(id: post_id))
                if post.topic_id == mapped[:topic_id]
                  mapped[:reply_to_post_number] = post.post_number
                else
                  puts "post #{m["id"]} reply to another topic, skip reply"
                end
              else
                puts "post #{m["id"]} reply to not exists post #{reply_post_import_id}, skip reply"
              end
            end
          else
            puts "Parent topic #{m["topic_id"]} doesn't exist. Skipping #{m["id"]}: #{m["title"][0..40]}"
            skip = true
          end
        end

        if m["status"] & 1 == 1 || mapped[:raw].blank?
          mapped[:post_create_action] = lambda do |action_post|
            PostDestroyer.new(Discourse.system_user, action_post).perform_delete
          end
        elsif (m["status"] & 2) >> 1 == 1 # waiting for approve
          mapped[:post_create_action] = lambda do |action_post|
            PostActionCreator.notify_user(Discourse.system_user, action_post)
          end
        end
        skip ? nil : mapped
      end
    end
  end

  def import_bookmarks
    puts "", "creating bookmarks"
    favorites_table = table_name "home_favorite"
    posts_table = table_name "forum_post"

    total_count =
      mysql_query("SELECT count(*) count FROM #{favorites_table} WHERE idtype = 'tid'").first[
        "count"
      ]
    batches(BATCH_SIZE) do |offset|
      results =
        mysql_query(
          "
        SELECT p.pid post_id, f.uid user_id
          FROM #{favorites_table} f
          JOIN #{posts_table} p ON f.id = p.tid
          WHERE f.idtype = 'tid' AND p.first
             LIMIT #{BATCH_SIZE}
            OFFSET #{offset};",
        )

      break if results.size < 1

      # next if all_records_exist?

      create_bookmarks(results, total: total_count, offset: offset) do |row|
        { user_id: row["user_id"], post_id: row["post_id"] }
      end
    end
  end

  def import_private_messages
    puts "", "creating private messages"

    pm_indexes = table_name "ucenter_pm_indexes"
    pm_messages = table_name "ucenter_pm_messages"
    total_count = mysql_query("SELECT count(*) count FROM #{pm_indexes}").first["count"]

    batches(BATCH_SIZE) do |offset|
      results =
        mysql_query(
          "
            SELECT pmid id, plid thread_id, authorid user_id, message, dateline created_at
              FROM #{pm_messages}_1
      UNION SELECT pmid id, plid thread_id, authorid user_id, message, dateline created_at
              FROM #{pm_messages}_2
      UNION SELECT pmid id, plid thread_id, authorid user_id, message, dateline created_at
              FROM #{pm_messages}_3
      UNION SELECT pmid id, plid thread_id, authorid user_id, message, dateline created_at
              FROM #{pm_messages}_4
      UNION SELECT pmid id, plid thread_id, authorid user_id, message, dateline created_at
              FROM #{pm_messages}_5
      UNION SELECT pmid id, plid thread_id, authorid user_id, message, dateline created_at
              FROM #{pm_messages}_6
      UNION SELECT pmid id, plid thread_id, authorid user_id, message, dateline created_at
              FROM #{pm_messages}_7
      UNION SELECT pmid id, plid thread_id, authorid user_id, message, dateline created_at
              FROM #{pm_messages}_8
      UNION SELECT pmid id, plid thread_id, authorid user_id, message, dateline created_at
              FROM #{pm_messages}_9
          ORDER BY thread_id ASC, id ASC
             LIMIT #{BATCH_SIZE}
            OFFSET #{offset};",
        )

      break if results.size < 1

      # next if all_records_exist? :posts, results.map {|m| "pm:#{m['id']}"}

      create_posts(results, total: total_count, offset: offset) do |m|
        skip = false
        mapped = {}

        mapped[:id] = "pm:#{m["id"]}"
        mapped[:user_id] = user_id_from_imported_user_id(m["user_id"]) || -1
        mapped[:raw] = process_discuzx_post(m["message"], m["id"])
        mapped[:created_at] = Time.zone.at(m["created_at"])
        thread_id = "pm_#{m["thread_id"]}"

        if is_first_pm(m["id"], m["thread_id"])
          # find the title from list table
          pm_thread =
            mysql_query(
              "
                SELECT plid thread_id, subject
                  FROM #{table_name "ucenter_pm_lists"}
                 WHERE plid = #{m["thread_id"]};",
            ).first
          mapped[:title] = pm_thread["subject"]
          mapped[:archetype] = Archetype.private_message

          # Find the users who are part of this private message.
          import_user_ids =
            mysql_query(
              "
                SELECT plid thread_id, uid user_id
                  FROM #{table_name "ucenter_pm_members"}
                 WHERE plid = #{m["thread_id"]};
              ",
            ).map { |r| r["user_id"] }.uniq

          mapped[:target_usernames] = import_user_ids
            .map! do |import_user_id|
              if import_user_id.to_s == m["user_id"].to_s
                nil
              else
                User.find_by(id: user_id_from_imported_user_id(import_user_id)).try(:username)
              end
            end
            .compact

          if mapped[:target_usernames].empty? # pm with yourself?
            skip = true
            puts "Skipping pm:#{m["id"]} due to no target"
          else
            @first_post_id_by_topic_id[thread_id] = mapped[:id]
          end
        else
          parent = topic_lookup_from_imported_post_id(@first_post_id_by_topic_id[thread_id])
          if parent
            mapped[:topic_id] = parent[:topic_id]
          else
            puts "Parent post pm thread:#{thread_id} doesn't exist. Skipping #{m["id"]}: #{m["message"][0..40]}"
            skip = true
          end
        end

        skip ? nil : mapped
      end
    end
  end

  # search for first pm id for the series of pm
  def is_first_pm(pm_id, thread_id)
    result =
      mysql_query(
        "
          SELECT pmid id
            FROM #{table_name "ucenter_pm_indexes"}
           WHERE plid = #{thread_id}
        ORDER BY id",
      )
    result.first["id"].to_s == pm_id.to_s
  end

  def process_and_upload_inline_images(raw)
    inline_image_regex = %r{\[img\]([\s\S]*?)\[/img\]}

    s = raw.dup

    s.gsub!(inline_image_regex) do |d|
      matches = inline_image_regex.match(d)
      data = matches[1]

      upload, filename = upload_inline_image data
      upload ? html_for_upload(upload, filename) : nil
    end
  end

  def process_discuzx_post(raw, import_id)
    # raw = process_and_upload_inline_images(raw)
    s = raw.dup

    # Strip the quote
    # [quote] quotation includes the topic which is the same as reply to in Discourse
    # We get the pid to find the post number the post reply to. So it can be stripped
    s =
      s.gsub(
        %r{\[b\]回复 \[url=forum.php\?mod=redirect&goto=findpost&pid=\d+&ptid=\d+\].* 的帖子\[/url\]\[/b\]}i,
        "",
      ).strip
    s =
      s.gsub(
        %r{\[b\]回复 \[url=https?://#{ORIGINAL_SITE_PREFIX}/redirect.php\?goto=findpost&pid=\d+&ptid=\d+\].*?\[/url\].*?\[/b\]}i,
        "",
      ).strip

    s.gsub!(%r{\[quote\](.*)?\[/quote\]}im) do |matched|
      content = $1
      post_import_id = find_post_id_by_quote_number(content)
      if post_import_id
        post_id = post_id_from_imported_post_id(post_import_id.to_i)
        if (post = Post.find_by(id: post_id))
          "[quote=\"#{post.user.username}\", post: #{post.post_number}, topic: #{post.topic_id}]\n#{content}\n[/quote]"
        else
          puts "post #{import_id} quote to not exists post #{post_import_id}, skip reply"
          matched[0]
        end
      else
        matched[0]
      end
    end

    s.gsub!(
      %r{\[size=2\]\[color=#999999\].*? 发表于 [\d\-\: ]*\[/color\] \[url=forum.php\?mod=redirect&goto=findpost&pid=\d+&ptid=\d+\].*?\[/url\]\[/size\]}i,
      "",
    )
    s.gsub!(
      %r{\[size=2\]\[color=#999999\].*? 发表于 [\d\-\: ]*\[/color\] \[url=https?://#{ORIGINAL_SITE_PREFIX}/redirect.php\?goto=findpost&pid=\d+&ptid=\d+\].*?\[/url\]\[/size\]}i,
      "",
    )

    # convert quote
    s.gsub!(%r{\[quote\](.*?)\[/quote\]}m) { "\n" + ($1.strip).gsub(/^/, "> ") + "\n" }

    # truncate line space, preventing line starting with many blanks to be parsed as code blocks
    s.gsub!(/^ {4,}/, "   ")

    # TODO: Much better to use bbcode-to-md gem
    # Convert image bbcode with width and height
    s.gsub!(
      %r{\[img[^\]]*\]https?://#{ORIGINAL_SITE_PREFIX}/(.*)\[/img\]}i,
      '[x-attach]\1[/x-attach]',
    ) # dont convert attachment
    s.gsub!(
      %r{<img[^>]*src="https?://#{ORIGINAL_SITE_PREFIX}/(.*)".*?>}i,
      '[x-attach]\1[/x-attach]',
    ) # dont convert attachment
    s.gsub!(
      %r{\[img[^\]]*\]https?://www\.touhou\.cc/blog/(.*)\[/img\]}i,
      '[x-attach]../blog/\1[/x-attach]',
    ) # 私货
    s.gsub!(
      %r{\[img[^\]]*\]https?://www\.touhou\.cc/ucenter/avatar.php\?uid=(\d+)[^\]]*\[/img\]}i,
    ) { "[x-attach]#{discuzx_avatar_fullpath($1, false)[0]}[/x-attach]" } # 私货
    s.gsub!(%r{\[img=(\d+),(\d+)\]([^\]]*)\[/img\]}i, '<img width="\1" height="\2" src="\3">')
    s.gsub!(%r{\[img\]([^\]]*)\[/img\]}i, '<img src="\1">')

    s.gsub!(
      %r{\[qq\]([^\]]*)\[/qq\]}i,
      '<a href="http://wpa.qq.com/msgrd?V=3&Uin=\1&Site=[Discuz!]&from=discuz&Menu=yes" target="_blank"><!--<img src="static/image/common/qq_big.gif" border="0">-->QQ 交谈</a>',
    )

    s.gsub!(%r{\[email\]([^\]]*)\[/email\]}i, '[url=mailto:\1]\1[/url]') # bbcode-to-md can convert it
    s.gsub!(%r{\[s\]([^\]]*)\[/s\]}i, '<s>\1</s>')
    s.gsub!(%r{\[sup\]([^\]]*)\[/sup\]}i, '<sup>\1</sup>')
    s.gsub!(%r{\[sub\]([^\]]*)\[/sub\]}i, '<sub>\1</sub>')
    s.gsub!(/\[hr\]/i, "\n---\n")

    # remove the media tag
    s.gsub!(%r{\[/?media[^\]]*\]}i, "\n")
    s.gsub!(%r{\[/?flash[^\]]*\]}i, "\n")
    s.gsub!(%r{\[/?audio[^\]]*\]}i, "\n")
    s.gsub!(%r{\[/?video[^\]]*\]}i, "\n")

    # Remove the font, p and backcolor tag
    # Discourse doesn't support the font tag
    s.gsub!(/\[font=[^\]]*?\]/i, "")
    s.gsub!(%r{\[/font\]}i, "")
    s.gsub!(/\[p=[^\]]*?\]/i, "")
    s.gsub!(%r{\[/p\]}i, "")
    s.gsub!(/\[backcolor=[^\]]*?\]/i, "")
    s.gsub!(%r{\[/backcolor\]}i, "")

    # Remove the size tag
    # I really have no idea what is this
    s.gsub!(/\[size=[^\]]*?\]/i, "")
    s.gsub!(%r{\[/size\]}i, "")

    # Remove the color tag
    s.gsub!(/\[color=[^\]]*?\]/i, "")
    s.gsub!(%r{\[/color\]}i, "")

    # Remove the hide tag
    s.gsub!(%r{\[/?hide\]}i, "")
    s.gsub!(%r{\[/?free[^\]]*\]}i, "\n")

    # Remove the align tag
    # still don't know what it is
    s.gsub!(/\[align=[^\]]*?\]/i, "\n")
    s.gsub!(%r{\[/align\]}i, "\n")
    s.gsub!(/\[float=[^\]]*?\]/i, "\n")
    s.gsub!(%r{\[/float\]}i, "\n")

    # Convert code
    s.gsub!(%r{\[/?code\]}i, "\n```\n")

    # The edit notice should be removed
    # example: 本帖最后由 Helloworld 于 2015-1-28 22:05 编辑
    s.gsub!(%r{\[i=s\] 本帖最后由[\s\S]*?编辑 \[/i\]}, "")

    # Convert the custom smileys to emojis
    # `{:cry:}` to `:cry`
    s.gsub!(/\{(\:\S*?\:)\}/, '\1')

    # Replace internal forum links that aren't in the <!-- l --> format
    # convert list tags to ul and list=1 tags to ol
    # (basically, we're only missing list=a here...)
    s.gsub!(%r{\[list\](.*?)\[/list:u\]}m, '[ul]\1[/ul]')
    s.gsub!(%r{\[list=1\](.*?)\[/list:o\]}m, '[ol]\1[/ol]')
    # convert *-tags to li-tags so bbcode-to-md can do its magic on phpBB's lists:
    s.gsub!(%r{\[\*\](.*?)\[/\*:m\]}, '[li]\1[/li]')

    # Discuz can create PM out of a post, which will generates like
    # [url=http://example.com/forum.php?mod=redirect&goto=findpost&pid=111&ptid=11][b]关于您在“主题名称”的帖子[/b][/url]
    s.gsub!(pm_url_regexp) { |discuzx_link| replace_internal_link(discuzx_link, $1) }

    # [url][b]text[/b][/url] to **[url]text[/url]**
    s.gsub!(%r{(\[url=[^\[\]]*?\])\[b\](\S*)\[/b\](\[/url\])}, '**\1\2\3**')

    @internal_url_regexps.each do |internal_url_regexp|
      s.gsub!(internal_url_regexp) do |discuzx_link|
        replace_internal_link(
          discuzx_link,
          (
            begin
              $~[:tid].to_i
            rescue StandardError
              nil
            end
          ),
          (
            begin
              $~[:pid].to_i
            rescue StandardError
              nil
            end
          ),
          (
            begin
              $~[:fid].to_i
            rescue StandardError
              nil
            end
          ),
          (
            begin
              $~[:action]
            rescue StandardError
              nil
            end
          ),
        )
      end
    end

    # @someone without the url
    s.gsub!(%r{@\[url=[^\[\]]*?\](\S*)\[/url\]}i, '@\1')

    s.scan(%r{http(?:s)?://#{ORIGINAL_SITE_PREFIX.gsub(".", '\.')}/[^\[\]\s]*}) do |link|
      puts "WARNING: post #{import_id} can't replace internal url #{link}"
    end

    s.strip
  end

  def replace_internal_link(
    discuzx_link,
    import_topic_id,
    import_post_id,
    import_category_id,
    action
  )
    if import_post_id
      post_id = post_id_from_imported_post_id import_post_id
      if post_id
        post = Post.find post_id
        return post.full_url if post
      end
    end

    if import_topic_id
      results =
        mysql_query(
          "SELECT pid
                               FROM #{table_name "forum_post"}
                              WHERE tid = #{import_topic_id} AND first
                              LIMIT 1",
        )

      return discuzx_link if results.size.zero?

      linked_post_id = results.first["pid"]
      lookup = topic_lookup_from_imported_post_id(linked_post_id)

      if lookup
        return "#{NEW_SITE_PREFIX}#{lookup[:url]}"
      else
        return discuzx_link
      end
    end

    if import_category_id
      category_id = category_id_from_imported_category_id import_category_id
      if category_id
        category = Category.find category_id
        return category.url if category
      end
    end

    case action
    when "index"
      return "#{NEW_SITE_PREFIX}/"
    when "stat", "stats", "ranklist"
      return "#{NEW_SITE_PREFIX}/users"
    end

    discuzx_link
  end

  def pm_url_regexp
    @pm_url_regexp ||=
      Regexp.new(
        "http(?:s)?://#{ORIGINAL_SITE_PREFIX.gsub(".", '\.')}/forum\\.php\\?mod=redirect&goto=findpost&pid=\\d+&ptid=(\\d+)",
      )
  end

  # This step is done separately because it can take multiple attempts to get right (because of
  # missing files, wrong paths, authorized extensions, etc.).
  def import_attachments
    setting = AUTHORIZED_EXTENSIONS.join("|")
    SiteSetting.authorized_extensions = setting if setting != SiteSetting.authorized_extensions

    attachment_regex = %r{\[attach\](\d+)\[/attach\]}
    attachment_link_regex = %r{\[x-attach\](.+)\[/x-attach\]}

    current_count = 0
    total_count =
      mysql_query("SELECT count(*) count FROM #{table_name "forum_post"};").first["count"]

    success_count = 0
    fail_count = 0

    puts "", "Importing attachments...", ""

    Post.find_each do |post|
      next unless post.custom_fields["import_id"] == post.custom_fields["import_id"].to_i.to_s

      user = post.user

      current_count += 1
      print_status current_count, total_count

      new_raw = post.raw.dup

      inline_attachments = []

      new_raw.gsub!(attachment_regex) do |s|
        attachment_id = $1.to_i
        inline_attachments.push attachment_id

        upload, filename = find_upload(user, post, attachment_id)
        unless upload
          fail_count += 1
          next
        end

        html_for_upload(upload, filename)
      end
      new_raw.gsub!(attachment_link_regex) do |s|
        attachment_file = $1

        filename = File.basename(attachment_file)
        upload = create_upload(user.id, File.join(DISCUZX_BASE_DIR, attachment_file), filename)
        unless upload
          fail_count += 1
          next
        end

        html_for_upload(upload, filename)
      end

      sql =
        "SELECT aid
          FROM #{table_name "forum_attachment"}
          WHERE pid = #{post.custom_fields["import_id"]}"
      sql = "#{sql} AND aid NOT IN (#{inline_attachments.join(",")})" if !inline_attachments.empty?

      results = mysql_query(sql)

      results.each do |attachment|
        attachment_id = attachment["aid"]
        upload, filename = find_upload(user, post, attachment_id)
        unless upload
          fail_count += 1
          next
        end
        html = html_for_upload(upload, filename)
        if new_raw.exclude? html
          new_raw << "\n"
          new_raw << html
        end
      end

      if new_raw != post.raw
        PostRevisor.new(post).revise!(
          post.user,
          { raw: new_raw },
          bypass_bump: true,
          edit_reason: "从 Discuz 中导入附件",
        )
      end

      success_count += 1
    end

    puts "", ""
    puts "succeeded: #{success_count}"
    puts "   failed: #{fail_count}" if fail_count > 0
    puts ""
  end

  # Create the full path to the discuz avatar specified from user id
  def discuzx_avatar_fullpath(user_id, absolute = true)
    padded_id = user_id.to_s.rjust(9, "0")

    part_1 = padded_id[0..2]
    part_2 = padded_id[3..4]
    part_3 = padded_id[5..6]
    part_4 = padded_id[-2..-1]
    file_name = "#{part_4}_avatar_big.jpg"

    if absolute
      [File.join(DISCUZX_BASE_DIR, AVATAR_DIR, part_1, part_2, part_3, file_name), file_name]
    else
      [File.join(AVATAR_DIR, part_1, part_2, part_3, file_name), file_name]
    end
  end

  # post id is in the quote block
  def find_post_id_by_quote_number(raw)
    case raw
    when /\[url=forum.php\?mod=redirect&goto=findpost&pid=(\d+)&ptid=\d+\]/ #standard
      $1
    when %r{\[url=https?://#{ORIGINAL_SITE_PREFIX}/redirect.php\?goto=findpost&pid=(\d+)&ptid=\d+\]} # old discuz 7 format
      $1
    when %r{\[quote\][\S\s]*pid=(\d+)[\S\s]*\[/quote\]} # quote
      $1
    end
  end

  # for some reason, discuz inlined some png file
  # the corresponding image stored is broken in a way
  def upload_inline_image(data)
    return unless data

    puts "Creating inline image"

    encoded_photo = data["data:image/png;base64,".length..-1]
    if encoded_photo
      raw_file = Base64.decode64(encoded_photo)
    else
      puts "Error parsed inline photo", data[0..20]
      return
    end

    real_filename = "#{SecureRandom.hex}.png"
    filename = Tempfile.new(%w[inline .png])
    begin
      filename.binmode
      filename.write(raw_file)
      filename.rewind

      upload = create_upload(Discourse::SYSTEM_USER_ID, filename, real_filename)
    ensure
      begin
        filename.close
      rescue StandardError
        nil
      end
      begin
        filename.unlink
      rescue StandardError
        nil
      end
    end

    if upload.nil? || !upload.valid?
      puts "Upload not valid :("
      puts upload.errors.inspect if upload
      return nil
    end

    [upload, real_filename]
  end

  # find the uploaded file and real name from the db
  def find_upload(user, post, upload_id)
    attachment_table = table_name "forum_attachment"
    # search for table id
    sql =
      "SELECT a.pid post_id,
                  a.aid upload_id,
                  a.tableid table_id
             FROM #{attachment_table} a
            WHERE a.pid = #{post.custom_fields["import_id"]}
              AND a.aid = #{upload_id};"
    results = mysql_query(sql)

    unless (meta_data = results.first)
      puts "Couldn't find forum_attachment record meta data for post.id = #{post.id}, import_id = #{post.custom_fields["import_id"]}"
      return nil
    end

    # search for uploaded file meta data
    sql =
      "SELECT a.pid post_id,
                  a.aid upload_id,
                  a.tid topic_id,
                  a.uid user_id,
                  a.dateline uploaded_time,
                  a.filename real_filename,
                  a.attachment attachment_path,
                  a.remote is_remote,
                  a.description description,
                  a.isimage is_image,
                  a.thumb is_thumb
             FROM #{attachment_table}_#{meta_data["table_id"]} a
            WHERE a.aid = #{upload_id};"
    results = mysql_query(sql)

    unless (row = results.first)
      puts "Couldn't find attachment record for post.id = #{post.id}, import_id = #{post.custom_fields["import_id"]}"
      return nil
    end

    filename = File.join(DISCUZX_BASE_DIR, ATTACHMENT_DIR, row["attachment_path"])
    unless File.exist?(filename)
      puts "Attachment file doesn't exist: #{filename}"
      return nil
    end
    real_filename = row["real_filename"]
    real_filename.prepend SecureRandom.hex if real_filename[0] == "."
    upload = create_upload(user.id, filename, real_filename)

    if upload.nil? || !upload.valid?
      puts "Upload not valid :("
      puts upload.errors.inspect if upload
      return nil
    end

    [upload, real_filename]
  rescue Mysql2::Error => e
    puts "SQL Error"
    puts e.message
    puts sql
    nil
  end

  def first_exists(*items)
    items.find { |item| !item.blank? } || ""
  end

  def mysql_query(sql)
    @client.query(sql, cache_rows: false)
  end
end

ImportScripts::DiscuzX.new.perform
