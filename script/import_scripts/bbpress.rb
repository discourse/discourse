# frozen_string_literal: true

require 'mysql2'
require File.expand_path(File.dirname(__FILE__) + "/base.rb")

class ImportScripts::Bbpress < ImportScripts::Base

  BB_PRESS_HOST            ||= ENV['BBPRESS_HOST'] || "localhost"
  BB_PRESS_DB              ||= ENV['BBPRESS_DB'] || "bbpress"
  BATCH_SIZE               ||= 1000
  BB_PRESS_PW              ||= ENV['BBPRESS_PW'] || ""
  BB_PRESS_USER            ||= ENV['BBPRESS_USER'] || "root"
  BB_PRESS_PREFIX          ||= ENV['BBPRESS_PREFIX'] || "wp_"
  BB_PRESS_ATTACHMENTS_DIR ||= ENV['BBPRESS_ATTACHMENTS_DIR'] || "/path/to/attachments"

  def initialize
    super

    @he = HTMLEntities.new

    @client = Mysql2::Client.new(
      host: BB_PRESS_HOST,
      username: BB_PRESS_USER,
      database: BB_PRESS_DB,
      password: BB_PRESS_PW,
    )
  end

  def execute
    import_users
    import_anonymous_users
    import_categories
    import_topics_and_posts
    import_private_messages
    import_attachments
    create_permalinks
  end

  def import_users
    puts "", "importing users..."

    last_user_id = -1
    total_users = bbpress_query(<<-SQL
      SELECT COUNT(DISTINCT(u.id)) AS cnt
      FROM #{BB_PRESS_PREFIX}users u
      LEFT JOIN #{BB_PRESS_PREFIX}posts p ON p.post_author = u.id
      WHERE p.post_type IN ('forum', 'reply', 'topic')
        AND user_email LIKE '%@%'
    SQL
    ).first["cnt"]

    batches(BATCH_SIZE) do |offset|
      users = bbpress_query(<<-SQL
        SELECT u.id, user_nicename, display_name, user_email, user_registered, user_url, user_pass
          FROM #{BB_PRESS_PREFIX}users u
          LEFT JOIN #{BB_PRESS_PREFIX}posts p ON p.post_author = u.id
         WHERE user_email LIKE '%@%'
           AND p.post_type IN ('forum', 'reply', 'topic')
           AND u.id > #{last_user_id}
      GROUP BY u.id
      ORDER BY u.id
         LIMIT #{BATCH_SIZE}
      SQL
      ).to_a

      break if users.empty?

      last_user_id = users[-1]["id"]
      user_ids = users.map { |u| u["id"].to_i }

      next if all_records_exist?(:users, user_ids)

      user_ids_sql = user_ids.join(",")

      users_description = {}
      bbpress_query(<<-SQL
        SELECT user_id, meta_value description
          FROM #{BB_PRESS_PREFIX}usermeta
         WHERE user_id IN (#{user_ids_sql})
           AND meta_key = 'description'
      SQL
      ).each { |um| users_description[um["user_id"]] = um["description"] }

      users_last_activity = {}
      bbpress_query(<<-SQL
        SELECT user_id, meta_value last_activity
          FROM #{BB_PRESS_PREFIX}usermeta
         WHERE user_id IN (#{user_ids_sql})
           AND meta_key = 'last_activity'
      SQL
      ).each { |um| users_last_activity[um["user_id"]] = um["last_activity"] }

      create_users(users, total: total_users, offset: offset) do |u|
        {
          id: u["id"].to_i,
          username: u["user_nicename"],
          password: u["user_pass"],
          email: u["user_email"].downcase,
          name: u["display_name"].presence || u['user_nicename'],
          created_at: u["user_registered"],
          website: u["user_url"],
          bio_raw: users_description[u["id"]],
          last_seen_at: users_last_activity[u["id"]],
        }
      end
    end
  end

  def import_anonymous_users
    puts "", "importing anonymous users..."

    anon_posts = Hash.new
    anon_names = Hash.new
    emails = Array.new

    # gather anonymous users via postmeta table
    bbpress_query(<<-SQL
      SELECT post_id, meta_key, meta_value
        FROM #{BB_PRESS_PREFIX}postmeta
       WHERE meta_key LIKE '_bbp_anonymous%'
    SQL
    ).each do |pm|
      anon_posts[pm['post_id']] = Hash.new if not anon_posts[pm['post_id']]

      if pm['meta_key'] == '_bbp_anonymous_email'
        anon_posts[pm['post_id']]['email'] = pm['meta_value']
      end
      if pm['meta_key'] == '_bbp_anonymous_name'
        anon_posts[pm['post_id']]['name'] = pm['meta_value']
      end
      if pm['meta_key'] == '_bbp_anonymous_website'
        anon_posts[pm['post_id']]['website'] = pm['meta_value']
      end
    end

    # gather every existent username
    anon_posts.each do |id, post|
      anon_names[post['name']] = Hash.new if not anon_names[post['name']]
      # overwriting email address, one user can only use one email address
      anon_names[post['name']]['email'] = post['email']
      anon_names[post['name']]['website'] = post['website'] if post['website'] != ''
    end

    # make sure every user name has a unique email address
    anon_names.each do |k, name|
      if not emails.include? name['email']
        emails.push ( name['email'])
      else
        name['email'] = "anonymous_#{SecureRandom.hex}@no-email.invalid"
      end
    end

    create_users(anon_names) do |k, n|
      {
        id: k,
        email: n["email"].downcase,
        name: k,
        website: n["website"]
      }
    end
  end

  def import_categories
    puts "", "importing categories..."

    categories = bbpress_query(<<-SQL
      SELECT id, post_name, post_parent
        FROM #{BB_PRESS_PREFIX}posts
       WHERE post_type = 'forum'
         AND LENGTH(COALESCE(post_name, '')) > 0
    ORDER BY post_parent, id
    SQL
    )

    create_categories(categories) do |c|
      category = { id: c['id'], name: c['post_name'] }
      if (parent_id = c['post_parent'].to_i) > 0
        category[:parent_category_id] = category_id_from_imported_category_id(parent_id)
      end
      category
    end
  end

  def import_topics_and_posts
    puts "", "importing topics and posts..."

    last_post_id = -1
    total_posts = bbpress_query(<<-SQL
      SELECT COUNT(*) count
        FROM #{BB_PRESS_PREFIX}posts
       WHERE post_status <> 'spam'
         AND post_type IN ('topic', 'reply')
    SQL
    ).first["count"]

    batches(BATCH_SIZE) do |offset|
      posts = bbpress_query(<<-SQL
        SELECT id,
               post_author,
               post_date,
               post_content,
               post_title,
               post_type,
               post_parent
          FROM #{BB_PRESS_PREFIX}posts
         WHERE post_status <> 'spam'
           AND post_type IN ('topic', 'reply')
           AND id > #{last_post_id}
      ORDER BY id
         LIMIT #{BATCH_SIZE}
      SQL
      ).to_a

      break if posts.empty?

      last_post_id = posts[-1]["id"].to_i
      post_ids = posts.map { |p| p["id"].to_i }

      next if all_records_exist?(:posts, post_ids)

      post_ids_sql = post_ids.join(",")

      posts_likes = {}
      bbpress_query(<<-SQL
        SELECT post_id, meta_value likes
          FROM #{BB_PRESS_PREFIX}postmeta
         WHERE post_id IN (#{post_ids_sql})
           AND meta_key = 'Likes'
      SQL
      ).each { |pm| posts_likes[pm["post_id"]] = pm["likes"].to_i }

      anon_names = {}
      bbpress_query(<<-SQL
        SELECT post_id, meta_value
          FROM #{BB_PRESS_PREFIX}postmeta
         WHERE post_id IN (#{post_ids_sql})
           AND meta_key = '_bbp_anonymous_name'
      SQL
      ).each { |pm| anon_names[pm["post_id"]] = pm["meta_value"] }

      create_posts(posts, total: total_posts, offset: offset) do |p|
        skip = false

        user_id = user_id_from_imported_user_id(p["post_author"]) ||
                  find_user_by_import_id(p["post_author"]).try(:id) ||
                  user_id_from_imported_user_id(anon_names[p['id']]) ||
                  find_user_by_import_id(anon_names[p['id']]).try(:id) ||
                  -1

        post = {
          id: p["id"],
          user_id: user_id,
          raw: p["post_content"],
          created_at: p["post_date"],
          like_count: posts_likes[p["id"]],
        }

        if post[:raw].present?
          post[:raw].gsub!(/\<pre\>\<code(=[a-z]*)?\>(.*?)\<\/code\>\<\/pre\>/im) { "```\n#{@he.decode($2)}\n```" }
        end

        if p["post_type"] == "topic"
          post[:category] = category_id_from_imported_category_id(p["post_parent"])
          post[:title] = CGI.unescapeHTML(p["post_title"])
        else
          if parent = topic_lookup_from_imported_post_id(p["post_parent"])
            post[:topic_id] = parent[:topic_id]
            post[:reply_to_post_number] = parent[:post_number] if parent[:post_number] > 1
          else
            puts "Skipping #{p["id"]}: #{p["post_content"][0..40]}"
            skip = true
          end
        end

        skip ? nil : post
      end
    end
  end

  def import_attachments
    import_attachments_from_postmeta
    import_attachments_from_bb_attachments
  end

  def import_attachments_from_postmeta
    puts "", "Importing attachments from 'postmeta'..."

    count = 0
    last_attachment_id = -1

    total_attachments = bbpress_query(<<-SQL
      SELECT COUNT(*) count
        FROM #{BB_PRESS_PREFIX}postmeta pm
        JOIN #{BB_PRESS_PREFIX}posts p ON p.id = pm.post_id
       WHERE pm.meta_key = '_wp_attached_file'
         AND p.post_parent > 0
    SQL
    ).first["count"]

    batches(BATCH_SIZE) do |offset|
      attachments = bbpress_query(<<-SQL
        SELECT pm.meta_id id, pm.meta_value, p.post_parent post_id
          FROM #{BB_PRESS_PREFIX}postmeta pm
          JOIN #{BB_PRESS_PREFIX}posts p ON p.id = pm.post_id
         WHERE pm.meta_key = '_wp_attached_file'
           AND p.post_parent > 0
           AND pm.meta_id > #{last_attachment_id}
      ORDER BY pm.meta_id
         LIMIT #{BATCH_SIZE}
      SQL
      ).to_a

      break if attachments.empty?
      last_attachment_id = attachments[-1]["id"].to_i

      attachments.each do |a|
        print_status(count += 1, total_attachments, get_start_time("attachments_from_postmeta"))
        path = File.join(BB_PRESS_ATTACHMENTS_DIR, a["meta_value"])
        if File.exist?(path)
          if post = Post.find_by(id: post_id_from_imported_post_id(a["post_id"]))
            filename = File.basename(a["meta_value"])
            upload = create_upload(post.user.id, path, filename)
            if upload&.persisted?
              html = html_for_upload(upload, filename)
              if !post.raw[html]
                post.raw << "\n\n" << html
                post.save!
                PostUpload.create!(post: post, upload: upload) unless PostUpload.where(post: post, upload: upload).exists?
              end
            end
          end
        end
      end
    end
  end

  def import_attachments_from_bb_attachments
    puts "", "Importing attachments from 'bb_attachments'..."

    count = 0
    last_attachment_id = -1

    total_attachments = bbpress_query(<<-SQL
      SELECT COUNT(*) count
        FROM #{BB_PRESS_PREFIX}bb_attachments
       WHERE post_id IN (SELECT id FROM #{BB_PRESS_PREFIX}posts WHERE post_status <> 'spam' AND post_type IN ('topic', 'reply'))
    SQL
    ).first["count"]

    batches(BATCH_SIZE) do |offset|
      attachments = bbpress_query(<<-SQL
        SELECT id, filename, post_id
          FROM #{BB_PRESS_PREFIX}bb_attachments
         WHERE post_id IN (SELECT id FROM #{BB_PRESS_PREFIX}posts WHERE post_status <> 'spam' AND post_type IN ('topic', 'reply'))
           AND id > #{last_attachment_id}
      ORDER BY id
         LIMIT #{BATCH_SIZE}
      SQL
      ).to_a

      break if attachments.empty?
      last_attachment_id = attachments[-1]["id"].to_i

      attachments.each do |a|
        print_status(count += 1, total_attachments, get_start_time("attachments_from_bb_attachments"))
        if path = find_attachment(a["filename"], a["id"])
          if post = Post.find_by(id: post_id_from_imported_post_id(a["post_id"]))
            upload = create_upload(post.user.id, path, a["filename"])
            if upload&.persisted?
              html = html_for_upload(upload, a["filename"])
              if !post.raw[html]
                post.raw << "\n\n" << html
                post.save!
                PostUpload.create!(post: post, upload: upload) unless PostUpload.where(post: post, upload: upload).exists?
              end
            end
          end
        end
      end
    end
  end

  def find_attachment(filename, id)
    @attachments ||= Dir[File.join(BB_PRESS_ATTACHMENTS_DIR, "vf-attachs", "**", "*.*")]
    @attachments.find { |p| p.end_with?("/#{id}.#{filename}") }
  end

  def create_permalinks
    puts "", "creating permalinks..."

    last_topic_id = -1

    batches(BATCH_SIZE) do |offset|
      topics = bbpress_query(<<-SQL
        SELECT id,
               guid
          FROM #{BB_PRESS_PREFIX}posts
         WHERE post_status <> 'spam'
           AND post_type IN ('topic')
           AND id > #{last_topic_id}
      ORDER BY id
         LIMIT #{BATCH_SIZE}
      SQL
      ).to_a

      break if topics.empty?
      last_topic_id = topics[-1]["id"].to_i

      topics.each do |t|
        topic = topic_lookup_from_imported_post_id(t['id'])
        Permalink.create(url: URI.parse(t['guid']).path.chomp('/'), topic_id: topic[:topic_id]) rescue nil
      end
    end
  end

  def import_private_messages
    puts "", "importing private messages..."

    last_post_id = -1
    total_posts = bbpress_query("SELECT COUNT(*) count FROM #{BB_PRESS_PREFIX}bp_messages_messages").first["count"]

    threads = {}

    total_count = bbpress_query("SELECT COUNT(*) count FROM #{BB_PRESS_PREFIX}bp_messages_recipients").first["count"]
    current_count = 0

    batches(BATCH_SIZE) do |offset|
      rows = bbpress_query(<<-SQL
        SELECT thread_id, user_id
          FROM #{BB_PRESS_PREFIX}bp_messages_recipients
      ORDER BY id
         LIMIT #{BATCH_SIZE}
        OFFSET #{offset}
      SQL
      ).to_a

      break if rows.empty?

      rows.each do |row|
        current_count += 1
        print_status(current_count, total_count, get_start_time('private_messages'))

        threads[row['thread_id']] ||= {
          target_user_ids: [],
          imported_topic_id: nil
        }
        user_id = user_id_from_imported_user_id(row['user_id'])
        if user_id && !threads[row['thread_id']][:target_user_ids].include?(user_id)
          threads[row['thread_id']][:target_user_ids] << user_id
        end
      end
    end

    batches(BATCH_SIZE) do |offset|
      posts =  bbpress_query(<<-SQL
        SELECT id,
               thread_id,
               date_sent,
               sender_id,
               subject,
               message
          FROM wp_bp_messages_messages
         WHERE id > #{last_post_id}
      ORDER BY thread_id, date_sent
         LIMIT #{BATCH_SIZE}
      SQL
      ).to_a

      break if posts.empty?

      last_post_id = posts[-1]["id"].to_i

      create_posts(posts, total: total_posts, offset: offset) do |post|
        if tcf = TopicCustomField.where(name: 'bb_thread_id', value: post['thread_id']).first
          {
            id: "pm#{post['id']}",
            topic_id: threads[post['thread_id']][:imported_topic_id],
            user_id: user_id_from_imported_user_id(post['sender_id']) || find_user_by_import_id(post['sender_id'])&.id || -1,
            raw: post['message'],
            created_at: post['date_sent'],
          }
        else
          # First post of the thread
          {
            id: "pm#{post['id']}",
            archetype: Archetype.private_message,
            user_id: user_id_from_imported_user_id(post['sender_id']) || find_user_by_import_id(post['sender_id'])&.id || -1,
            title: post['subject'],
            raw: post['message'],
            created_at: post['date_sent'],
            target_usernames: User.where(id: threads[post['thread_id']][:target_user_ids]).pluck(:username),
            post_create_action: proc do |new_post|
              if topic = new_post.topic
                threads[post['thread_id']][:imported_topic_id] = topic.id
                TopicCustomField.create(topic_id: topic.id, name: 'bb_thread_id', value: post['thread_id'])
              else
                puts "Error in post_create_action! Can't find topic!"
              end
            end
          }
        end
      end
    end
  end

  def bbpress_query(sql)
    @client.query(sql, cache_rows: false)
  end

end

ImportScripts::Bbpress.new.perform
