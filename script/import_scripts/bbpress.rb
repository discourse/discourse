require 'mysql2'
require File.expand_path(File.dirname(__FILE__) + "/base.rb")

class ImportScripts::Bbpress < ImportScripts::Base

  BB_PRESS_DB ||= ENV['BBPRESS_DB'] || "bbpress"
  BATCH_SIZE  ||= 1000

  def initialize
    super

    @client = Mysql2::Client.new(
      host: "localhost",
      username: "root",
      database: BB_PRESS_DB,
    )
  end

  def execute
    import_users
    import_categories
    import_topics_and_posts
  end

  def import_users
    puts "", "importing users..."

    last_user_id = -1
    total_users = bbpress_query("SELECT COUNT(*) count FROM wp_users WHERE user_email LIKE '%@%'").first["count"]

    batches(BATCH_SIZE) do |offset|
      users = bbpress_query(<<-SQL
        SELECT id, user_nicename, display_name, user_email, user_registered, user_url
          FROM wp_users
         WHERE user_email LIKE '%@%'
           AND id > #{last_user_id}
      ORDER BY id
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
          FROM wp_usermeta
         WHERE user_id IN (#{user_ids_sql})
           AND meta_key = 'description'
      SQL
      ).each { |um| users_description[um["user_id"]] = um["description"] }

      users_last_activity = {}
      bbpress_query(<<-SQL
        SELECT user_id, meta_value last_activity
          FROM wp_usermeta
         WHERE user_id IN (#{user_ids_sql})
           AND meta_key = 'last_activity'
      SQL
      ).each { |um| users_last_activity[um["user_id"]] = um["last_activity"] }

      create_users(users, total: total_users, offset: offset) do |u|
        {
          id: u["id"].to_i,
          username: u["user_nicename"],
          email: u["user_email"].downcase,
          name: u["display_name"],
          created_at: u["user_registered"],
          website: u["user_url"],
          bio_raw: users_description[u["id"]],
          last_seen_at: users_last_activity[u["id"]],
        }
      end
    end
  end

  def import_categories
    puts "", "importing categories..."

    categories = bbpress_query(<<-SQL
      SELECT id, post_name, post_parent
        FROM wp_posts
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
        FROM wp_posts
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
          FROM wp_posts
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
          FROM wp_postmeta
         WHERE post_id IN (#{post_ids_sql})
           AND meta_key = 'Likes'
      SQL
      ).each { |pm| posts_likes[pm["post_id"]] = pm["likes"].to_i }

      create_posts(posts, total: total_posts, offset: offset) do |p|
        skip = false

        post = {
          id: p["id"],
          user_id: user_id_from_imported_user_id(p["post_author"]) || find_user_by_import_id(p["post_author"]).try(:id) || -1,
          raw: p["post_content"],
          created_at: p["post_date"],
          like_count: posts_likes[p["id"]],
        }

        if post[:raw].present?
          post[:raw].gsub!("<pre><code>", "```\n")
          post[:raw].gsub!("</code></pre>", "\n```")
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

  def bbpress_query(sql)
    @client.query(sql, cache_rows: false)
  end

end

ImportScripts::Bbpress.new.perform
