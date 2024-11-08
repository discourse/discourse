# frozen_string_literal: true

require "mysql2"
require "htmlentities"
require File.expand_path(File.dirname(__FILE__) + "/base.rb")

class ImportScripts::Smf1 < ImportScripts::Base
  BATCH_SIZE = 5000
  UPLOADS_DIR = ENV["UPLOADS_DIR"].presence
  FORUM_URL = ENV["FORUM_URL"].presence

  def initialize
    fail "UPLOADS_DIR env variable is required (example: '/path/to/attachments')" unless UPLOADS_DIR
    fail "FORUM_URL env variable is required (example: 'https://domain.com/forum')" unless FORUM_URL

    @client =
      Mysql2::Client.new(
        host: ENV["DB_HOST"] || "localhost",
        username: ENV["DB_USER"] || "root",
        password: ENV["DB_PW"],
        database: ENV["DB_NAME"],
      )

    check_version!

    super

    @htmlentities = HTMLEntities.new

    puts "Loading existing usernames..."

    @old_to_new_usernames =
      UserCustomField
        .joins(:user)
        .where(name: "import_username")
        .pluck("value", "users.username")
        .to_h

    puts "Loading pm mapping..."

    @pm_mapping = {}

    Topic
      .joins(:topic_allowed_users)
      .where(archetype: Archetype.private_message)
      .where("title NOT ILIKE 'Re: %'")
      .group(:id)
      .order(:id)
      .pluck(
        "string_agg(topic_allowed_users.user_id::text, ',' ORDER BY topic_allowed_users.user_id), title, topics.id",
      )
      .each do |users, title, topic_id|
        @pm_mapping[users] ||= {}
        @pm_mapping[users][title] ||= []
        @pm_mapping[users][title] << topic_id
      end
  end

  def execute
    SiteSetting.permalink_normalizations = "/(.+)\\?.*/\\1"

    import_groups
    import_users

    import_categories
    import_posts
    import_personal_posts

    import_attachments

    import_likes
    import_feedbacks

    import_banned_domains
    import_banned_emails
    import_banned_ips
  end

  def check_version!
    version =
      mysql_query("SELECT value FROM smf_settings WHERE variable = 'smfVersion' LIMIT 1").first[
        "value"
      ]
    fail "Incompatible version (#{version})" unless version&.start_with?("1.")
  end

  def import_groups
    puts "", "Importing groups..."

    # skip administrators/moderators
    groups = mysql_query("SELECT id_group, groupName FROM smf_membergroups WHERE id_group > 3").to_a

    create_groups(groups) do |g|
      next if g["groupName"].blank?

      { id: g["id_group"], full_name: g["groupName"] }
    end
  end

  def import_users
    puts "", "Importing users..."

    last_user_id = -1
    total = mysql_query("SELECT COUNT(*) count FROM smf_members").first["count"]

    batches(BATCH_SIZE) do |offset|
      users = mysql_query(<<~SQL).to_a
        SELECT m.id_member
             , memberName
             , dateRegistered
             , id_group
             , lastLogin
             , realName
             , emailAddress
             , personalText
             , CASE WHEN birthdate > '1900-01-01' THEN birthdate ELSE NULL END birthdate
             , websiteUrl
             , location
             , usertitle
             , memberIP
             , memberIP2
             , is_activated
             , additionalGroups
             , avatar
             , id_attach
             , attachmentType
             , filename
          FROM smf_members m
     LEFT JOIN smf_attachments a ON a.id_member = m.id_member
         WHERE m.id_member > #{last_user_id}
         ORDER BY m.id_member
         LIMIT #{BATCH_SIZE}
      SQL

      break if users.empty?

      last_user_id = users[-1]["id_member"]
      user_ids = users.map { |u| u["id_member"] }

      next if all_records_exist?(:users, user_ids)

      create_users(users, total: total, offset: offset) do |u|
        created_at = Time.zone.at(u["dateRegistered"])
        group_ids = [u["id_group"], *u["additionalGroups"].split(",").map(&:to_i)].uniq

        {
          id: u["id_member"],
          username: u["memberName"],
          created_at: created_at,
          first_seen_at: created_at,
          primary_group_id: group_id_from_imported_group_id(u["id_group"]),
          admin: group_ids.include?(1),
          moderator: group_ids.include?(2) || group_ids.include?(3),
          last_seen_at: Time.zone.at(u["lastLogin"]),
          name: u["realName"].presence,
          email: u["emailAddress"],
          bio_raw: pre_process_raw(u["personalText"].presence),
          date_of_birth: u["birthdate"],
          website: u["website"].presence,
          location: u["location"].presence,
          title: u["usertitle"].presence,
          registration_ip_address: u["memberIP"],
          ip_address: u["memberIP2"],
          active: u["is_activated"] == 1,
          approved: u["is_activated"] == 1,
          post_create_action:
            proc do |user|
              # usernames
              @old_to_new_usernames[u["memberName"]] = user.username

              # groups
              GroupUser.transaction do
                group_ids.each do |gid|
                  (group_id = group_id_from_imported_group_id(gid)) &&
                    GroupUser.find_or_create_by(user: user, group_id: group_id)
                end
              end

              # avatar
              avatar_url = nil

              if u["avatar"].present?
                if u["avatar"].start_with?("http")
                  avatar_url = u["avatar"]
                elsif u["avatar"].start_with?("avatar_")
                  avatar_url = "#{FORUM_URL}/avatar-members/#{u["avatar"]}"
                end
              end

              avatar_url ||=
                if u["attachmentType"] == 0 && u["id_attach"].present?
                  "#{FORUM_URL}/index.php?action=dlattach;attach=#{u["id_attach"]};type=avatar"
                elsif u["attachmentType"] == 1 && u["filename"].present?
                  "#{FORUM_URL}/avatar-members/#{u["filename"]}"
                end

              if avatar_url.present?
                begin
                  UserAvatar.import_url_for_user(avatar_url, user)
                rescue StandardError
                  nil
                end
              end
            end,
        }
      end
    end
  end

  def import_categories
    puts "", "Importing categories..."

    categories = mysql_query(<<~SQL).to_a
      SELECT id_board
           , id_parent
           , boardOrder
           , name
           , description
       FROM smf_boards
      ORDER BY id_parent, id_board
    SQL

    parent_categories = categories.select { |c| c["id_parent"] == 0 }
    children_categories = categories.select { |c| c["id_parent"] != 0 }

    create_categories(parent_categories) do |c|
      {
        id: c["id_board"],
        name: c["name"],
        description: pre_process_raw(c["description"].presence),
        position: c["boardOrder"],
        post_create_action:
          proc do |category|
            Permalink.find_or_create_by(
              url: "forums/index.php/board,#{c["id_board"]}.0.html",
              category_id: category.id,
            )
          end,
      }
    end

    create_categories(children_categories) do |c|
      {
        id: c["id_board"],
        parent_category_id: category_id_from_imported_category_id(c["id_parent"]),
        name: c["name"],
        description: pre_process_raw(c["description"].presence),
        position: c["boardOrder"],
        post_create_action:
          proc do |category|
            Permalink.find_or_create_by(
              url: "forums/index.php/board,#{c["id_board"]}.0.html",
              category_id: category.id,
            )
          end,
      }
    end
  end

  def import_posts
    puts "", "Importing posts..."

    last_post_id = -1
    total = mysql_query("SELECT COUNT(*) count FROM smf_messages").first["count"]

    batches(BATCH_SIZE) do |offset|
      posts = mysql_query(<<~SQL).to_a
        SELECT m.id_msg
             , m.id_topic
             , m.id_board
             , m.posterTime
             , m.id_member
             , m.subject
             , m.body
             , t.isSticky
             , t.id_first_msg
             , t.numViews
         FROM smf_messages m
         JOIN smf_topics t ON t.id_topic = m.id_topic
        WHERE m.id_msg > #{last_post_id}
        ORDER BY m.id_msg
        LIMIT #{BATCH_SIZE}
      SQL

      break if posts.empty?

      last_post_id = posts[-1]["id_msg"]
      post_ids = posts.map { |p| p["id_msg"] }

      next if all_records_exist?(:post, post_ids)

      create_posts(posts, total: total, offset: offset) do |p|
        created_at = Time.at(p["posterTime"])

        post = {
          id: p["id_msg"],
          created_at: created_at,
          user_id: user_id_from_imported_user_id(p["id_member"]) || -1,
          raw: pre_process_raw(p["body"]),
        }

        if p["id_msg"] == p["id_first_msg"]
          post[:category] = category_id_from_imported_category_id(p["id_board"])
          post[:title] = @htmlentities.decode(p["subject"])
          post[:views] = p["numViews"]
          post[:pinned_at] = created_at if p["isSticky"] == 1
          post[:post_create_action] = proc do |pp|
            Permalink.find_or_create_by(
              url: "forums/index.php/topic,#{p["id_topic"]}.0.html",
              topic_id: pp.topic_id,
            )
          end
        elsif parent = topic_lookup_from_imported_post_id(p["id_first_msg"])
          post[:topic_id] = parent[:topic_id]
          post[:post_create_action] = proc do |pp|
            Permalink.find_or_create_by(
              url: "forums/index.php/topic,#{p["id_topic"]}.msg#{p["id_msg"]}.html",
              post_id: pp.id,
            )
          end
        else
          next
        end

        post
      end
    end
  end

  def import_personal_posts
    puts "", "Importing personal posts..."

    last_post_id = -1
    total =
      mysql_query(
        "SELECT COUNT(*) count FROM smf_personal_messages WHERE deletedBySender = 0",
      ).first[
        "count"
      ]

    batches(BATCH_SIZE) do |offset|
      posts = mysql_query(<<~SQL).to_a
        SELECT id_pm
             , id_member_from
             , msgtime
             , subject
             , body
             , (SELECT GROUP_CONCAT(id_member) FROM smf_pm_recipients r WHERE r.id_pm = pm.id_pm) recipients
          FROM smf_personal_messages pm
         WHERE deletedBySender = 0
           AND id_pm > #{last_post_id}
         ORDER BY id_pm
         LIMIT #{BATCH_SIZE}
      SQL

      break if posts.empty?

      last_post_id = posts[-1]["id_pm"]
      post_ids = posts.map { |p| "pm-#{p["id_pm"]}" }

      next if all_records_exist?(:post, post_ids)

      create_posts(posts, total: total, offset: offset) do |p|
        next unless user_id = user_id_from_imported_user_id(p["id_member_from"])
        next if p["recipients"].blank?
        recipients =
          p["recipients"].split(",").map { |id| user_id_from_imported_user_id(id) }.compact.uniq
        next if recipients.empty?

        id = "pm-#{p["id_pm"]}"
        next if post_id_from_imported_post_id(id)

        post = {
          id: id,
          created_at: Time.at(p["msgtime"]),
          user_id: user_id,
          raw: pre_process_raw(p["body"]),
        }

        users = (recipients + [user_id]).sort.uniq.join(",")
        title = @htmlentities.decode(p["subject"])

        if topic_id = find_pm_topic_id(users, title)
          post[:topic_id] = topic_id
        else
          post[:archetype] = Archetype.private_message
          post[:title] = title
          post[:target_usernames] = User.where(id: recipients).pluck(:username)
          post[:post_create_action] = proc do |action_post|
            @pm_mapping[users] ||= {}
            @pm_mapping[users][title] ||= []
            @pm_mapping[users][title] << action_post.topic_id
          end
        end

        post
      end
    end
  end

  def find_pm_topic_id(users, title)
    return unless title.start_with?("Re: ")

    return unless @pm_mapping[users]

    title = title.gsub(/^(Re: )+/i, "")
    return unless @pm_mapping[users][title]

    @pm_mapping[users][title][-1]
  end

  def import_attachments
    puts "", "Importing attachments..."

    count = 0
    last_upload_id = -1
    total =
      mysql_query("SELECT COUNT(*) count FROM smf_attachments WHERE id_msg IS NOT NULL").first[
        "count"
      ]

    batches(BATCH_SIZE) do |offset|
      uploads = mysql_query(<<~SQL).to_a
        SELECT id_attach
             , id_msg
             , filename
             , file_hash
          FROM smf_attachments
         WHERE id_msg IS NOT NULL
           AND id_attach > #{last_upload_id}
         ORDER BY id_attach
         LIMIT #{BATCH_SIZE}
      SQL

      break if uploads.empty?

      last_upload_id = uploads[-1]["id_attach"]

      uploads.each do |u|
        count += 1

        unless post =
                 PostCustomField
                   .joins(:post)
                   .find_by(name: "import_id", value: u["id_msg"].to_s)
                   &.post
          next
        end

        path = File.join(UPLOADS_DIR, "#{u["id_attach"]}_#{u["file_hash"]}")
        next unless File.exist?(path) && File.size(path) > 0

        if upload = create_upload(post.user_id, path, u["filename"])
          html = html_for_upload(upload, u["filename"])
          unless post.raw[html] || UploadReference.where(upload: upload, target: post).exists?
            post.raw += "\n\n#{html}\n\n"
            post.save
            UploadReference.ensure_exist!(upload_ids: [upload.id], target: post)
          end
        end

        print_status(count, total, get_start_time("attachments"))
      end
    end
  end

  def import_likes
    return if mysql_query("SHOW TABLES LIKE 'smf_thank_you_post'").first.nil?

    puts "", "Importing likes..."

    count = 0
    total =
      mysql_query("SELECT COUNT(*) count FROM smf_thank_you_post WHERE thx_time > 0").first["count"]
    like = PostActionType.types[:like]

    mysql_query(
      "SELECT id_msg, id_member, thx_time FROM smf_thank_you_post WHERE thx_time > 0 ORDER BY id_thx_post",
    ).each do |l|
      print_status(count += 1, total, get_start_time("likes"))
      next unless post_id = post_id_from_imported_post_id(l["id_msg"])
      next unless user_id = user_id_from_imported_user_id(l["id_member"])
      if PostAction.where(post_action_type_id: like, post_id: post_id, user_id: user_id).exists?
        next
      end
      PostAction.create(
        post_action_type_id: like,
        post_id: post_id,
        user_id: user_id,
        created_at: Time.at(l["thx_time"]),
      )
    end
  end

  FEEDBACKS = -"feedbacks"

  def import_feedbacks
    return if mysql_query("SHOW TABLES LIKE 'smf_feedback'").first.nil?

    puts "", "Importing feedbacks..."

    User.register_custom_field_type(FEEDBACKS, :json)

    count = 0
    total = mysql_query("SELECT COUNT(*) count FROM smf_feedback WHERE approved").first["count"]

    mysql_query(<<~SQL).each do |f|
      SELECT feedbackid
           , id_member
           , feedbackmember_id
           , saledate
           , saletype
           , salevalue
           , comment_short
           , comment_long
        FROM smf_feedback
       WHERE approved
       ORDER BY feedbackid
    SQL
      print_status(count += 1, total, get_start_time("feedbacks"))
      next unless user_id_from = user_id_from_imported_user_id(f["feedbackmember_id"])
      next unless user_id_to = user_id_from_imported_user_id(f["id_member"])
      next unless user = User.find_by(id: user_id_to)

      feedbacks = user.custom_fields[FEEDBACKS] || []
      next if feedbacks.find { |ff| ff["id"] == f["feedbackid"] }

      feedbacks << {
        id: f["feedbackid"],
        created_at: Time.at(f["saledate"]),
        from: user_id_from,
        type: f["saletype"],
        value: f["salevalue"],
        comment_short: @htmlentities.decode(f["comment_short"]).strip.presence,
        comment_long: @htmlentities.decode(f["comment_long"]).strip.presence,
      }

      user.custom_fields[FEEDBACKS] = feedbacks.to_json
      user.save_custom_fields
    end
  end

  def import_banned_domains
    puts "", "Importing banned email domains..."

    blocklist = SiteSetting.blocked_email_domains.split("|")
    banned_domains =
      mysql_query(
        "SELECT SUBSTRING(email_address, 3) domain FROM smf_ban_items WHERE email_address RLIKE '^%@[^%]+$' GROUP BY email_address",
      ).map { |r| r["domain"] }

    SiteSetting.blocked_email_domains = (blocklist + banned_domains).uniq.sort.join("|")
  end

  def import_banned_emails
    puts "", "Importing banned emails..."

    count = 0

    banned_emails =
      mysql_query(
        "SELECT email_address FROM smf_ban_items WHERE email_address RLIKE '^[^%]+@[^%]+$' GROUP BY email_address",
      ).map { |r| r["email_address"] }
    banned_emails.each do |email|
      print_status(count += 1, banned_emails.size, get_start_time("banned_emails"))
      ScreenedEmail.find_or_create_by(email: email)
    end
  end

  def import_banned_ips
    puts "", "Importing banned IPs..."

    count = 0

    banned_ips = mysql_query(<<~SQL).to_a
      SELECT CONCAT_WS('.', ip_low1, ip_low2, ip_low3, ip_low4) low
           , CONCAT_WS('.', ip_high1, ip_high2, ip_high3, ip_high4) high
           , hits
        FROM smf_ban_items
       WHERE (ip_low1 + ip_low2 + ip_low3 + ip_low4 + ip_high1 + ip_high2 + ip_high3 + ip_high4) > 0
       GROUP BY low, high, hits;
    SQL

    banned_ips.each do |r|
      print_status(count += 1, banned_ips.size, get_start_time("banned_ips"))
      if r["low"] == r["high"]
        if !ScreenedIpAddress.where("? <<= ip_address", r["low"]).exists?
          ScreenedIpAddress.create(ip_address: r["low"], match_count: r["hits"])
        end
      else
        low_values = r["low"].split(".").map(&:to_i)
        high_values = r["high"].split(".").map(&:to_i)
        first_diff = low_values.zip(high_values).count { |a, b| a == b }
        first_diff -= 1 if low_values[first_diff] == 0 && high_values[first_diff] == 255
        prefix = low_values[0...first_diff]
        suffix = [0] * (3 - first_diff)
        mask = 8 * (first_diff + 1)
        values = (low_values[first_diff]..high_values[first_diff])
        hits = (r["hits"] / [1, values.count].max).floor
        values.each do |v|
          range_values = prefix + [v] + suffix
          ip_address = "#{range_values.join(".")}/#{mask}"
          if !ScreenedIpAddress.where("? <<= ip_address", ip_address).exists?
            ScreenedIpAddress.create(ip_address: ip_address, match_count: hits)
          end
        end
      end
    end

    ScreenedIpAddress.where(last_match_at: nil).update_all(last_match_at: Time.new(2000, 01, 01))

    puts "", "Rolling up..."
    ScreenedIpAddress.roll_up
  end

  IGNORED_BBCODE = %w[
    black
    blue
    center
    color
    email
    flash
    font
    glow
    green
    iurl
    left
    list
    move
    red
    right
    shadown
    size
    table
    time
    white
  ].freeze

  def pre_process_raw(raw)
    return "" if raw.blank?

    raw = @htmlentities.decode(raw)

    # [acronym]
    raw.gsub!(%r{\[acronym=([^\]]+)\](.*?)\[/acronym\]}im) { %{<abbr title="#{$1}">#{$2}</abbr>} }

    # [br]
    raw.gsub!(/\[br\]/i, "\n")
    raw.gsub!(%r{<br\s*/?>}i, "\n")
    # [hr]
    raw.gsub!(/\[hr\]/i, "<hr/>")

    # [sub]
    raw.gsub!(%r{\[sub\](.*?)\[/sub\]}im) { "<sub>#{$1}</sub>" }
    # [sup]
    raw.gsub!(%r{\[sup\](.*?)\[/sup\]}im) { "<sup>#{$1}</sup>" }

    # [html]
    raw.gsub!(/\[html\]/i, "\n```html\n")
    raw.gsub!(%r{\[/html\]}i, "\n```\n")

    # [php]
    raw.gsub!(/\[php\]/i, "\n```php\n")
    raw.gsub!(%r{\[/php\]}i, "\n```\n")

    # [code]
    raw.gsub!(%r{\[/?code\]}i, "\n```\n")

    # [pre]
    raw.gsub!(%r{\[/?pre\]}i, "\n```\n")

    # [tt]
    raw.gsub!(%r{\[/?tt\]}i, "`")

    # [ftp]
    raw.gsub!(/\[ftp/i, "[url")
    raw.gsub!(%r{\[/ftp\]}i, "[/url]")

    # [me]
    raw.gsub!(%r{\[me=([^\]]*)\](.*?)\[/me\]}im) { "_\\* #{$1} #{$2}_" }

    # [li]
    raw.gsub!(%r{\[li\](.*?)\[/li\]}im) { "- #{$1}" }

    # puts [img] on their own line
    raw.gsub!(%r{\[img[^\]]*\](.*?)\[/img\]}im) { "\n#{$1}\n" }

    # puts [youtube] on their own line
    raw.gsub!(%r{\[youtube\](.*?)\[/youtube\]}im) { "\n#{$1}\n" }

    IGNORED_BBCODE.each { |code| raw.gsub!(%r{\[#{code}[^\]]*\](.*?)\[/#{code}\]}im, '\1') }

    # ensure [/quote] are on their own line
    raw.gsub!(%r{\s*\[/quote\]\s*}im, "\n[/quote]\n")

    # [quote]
    raw.gsub!(/\s*\[quote (.+?)\]\s/im) do
      params = $1
      post_id = params[/msg(\d+)/, 1]
      username = params[/author=(.+) link=/, 1]
      username = @old_to_new_usernames[username] if @old_to_new_usernames.has_key?(username)

      if t = topic_lookup_from_imported_post_id(post_id)
        %{\n[quote="#{username},post:#{t[:post_number]},topic:#{t[:topic_id]}"]\n}
      else
        %{\n[quote="#{username}"]\n}
      end
    end

    # remove tapatalk mess
    raw.gsub!(%r{Sent from .+? using \[url=.*?\].+?\[/url\]}i, "")
    raw.gsub!(/Sent from .+? using .+?\z/i, "")

    # clean URLs
    raw.gsub!(%r{\[url=(.+?)\]\1\[/url\]}i, '\1')

    raw
  end

  def mysql_query(sql)
    @client.query(sql)
  end
end

ImportScripts::Smf1.new.perform
