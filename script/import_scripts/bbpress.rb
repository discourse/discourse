# `dropdb bbpress`
# `createdb bbpress`
# `bundle exec rake db:migrate`

require 'mysql2'
require File.expand_path(File.dirname(__FILE__) + "/base.rb")

BB_PRESS_DB = ENV['BBPRESS_DB'] || "bbpress"
DB_TABLE_PREFIX = "wp_"

class ImportScripts::Bbpress < ImportScripts::Base

  def initialize
    super

    @client = Mysql2::Client.new(
      host: "localhost",
      username: "root",
      #password: "password",
      database: BB_PRESS_DB
    )
  end

  def table_name(name)
    DB_TABLE_PREFIX + name
  end

  def execute
    users_results = @client.query("
       SELECT id,
              user_login username,
              display_name name,
              user_url website,
              user_email email,
              user_registered created_at
         FROM #{table_name 'users'}", cache_rows: false)

    puts '', "creating users"

    create_users(users_results) do |u|
      ActiveSupport::HashWithIndifferentAccess.new(u)
    end


    puts '', '', "creating categories"

    create_categories(@client.query("SELECT id, post_name, post_parent from #{table_name 'posts'} WHERE post_type = 'forum' AND post_name != '' ORDER BY post_parent")) do |c|
      result = {id: c['id'], name: c['post_name']}
      parent_id = c['post_parent'].to_i
      if parent_id > 0
        result[:parent_category_id] = category_id_from_imported_category_id(parent_id)
      end
      result
    end

    import_posts
  end

  def import_posts
    puts '', "creating topics and posts"

    total_count = @client.query("
      SELECT count(*) count
        FROM #{table_name 'posts'}
       WHERE post_status <> 'spam'
         AND post_type IN ('topic', 'reply')").first['count']

    batch_size = 1000

    batches(batch_size) do |offset|
      results = @client.query("
                   SELECT id,
                          post_author,
                          post_date,
                          post_content,
                          post_title,
                          post_type,
                          post_parent
                     FROM #{table_name 'posts'}
                    WHERE post_status <> 'spam'
                      AND post_type IN ('topic', 'reply')
                 ORDER BY id
                    LIMIT #{batch_size}
                   OFFSET #{offset}", cache_rows: false)

      break if results.size < 1

      next if all_records_exist? :posts, results.map {|p| p["id"].to_i}

      create_posts(results, total: total_count, offset: offset) do |post|
        skip = false
        mapped = {}

        mapped[:id] = post["id"]
        mapped[:user_id] = user_id_from_imported_user_id(post["post_author"]) || find_user_by_import_id(post["post_author"]).try(:id) || -1
        mapped[:raw] = post["post_content"]
        if mapped[:raw]
          mapped[:raw] = mapped[:raw].gsub("<pre><code>", "```\n").gsub("</code></pre>", "\n```")
        end
        mapped[:created_at] = post["post_date"]
        mapped[:custom_fields] = {import_id: post["id"]}

        if post["post_type"] == "topic"
          mapped[:category] = category_id_from_imported_category_id(post["post_parent"])
          mapped[:title] = CGI.unescapeHTML post["post_title"]
        else
          parent = topic_lookup_from_imported_post_id(post["post_parent"])
          if parent
            mapped[:topic_id] = parent[:topic_id]
            mapped[:reply_to_post_number] = parent[:post_number] if parent[:post_number] > 1
          else
            puts "Skipping #{post["id"]}: #{post["post_content"][0..40]}"
            skip = true
          end
        end

        skip ? nil : mapped
      end
    end
  end

end

ImportScripts::Bbpress.new.perform
