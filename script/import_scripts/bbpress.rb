# `dropdb bbpress`
# `createdb bbpress`
# `bundle exec rake db:migrate`

require File.expand_path(File.dirname(__FILE__) + "/base.rb")

BB_PRESS_DB = "bbpress"

require 'mysql2'

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

  def execute
    users_results = @client.query("
       select id,
              user_login username,
              display_name name,
              user_url website,
              user_email email,
              user_registered created_at
         from wp_users
        where spam = 0
          and deleted = 0 limit 50", cache_rows: false)

    create_users(users_results) do |u|
      ActiveSupport::HashWithIndifferentAccess.new(u)
    end

    create_categories(@client.query("select id, post_name from wp_posts where post_type = 'forum' and post_name != ''")) do |c|
      {id: c['id'], name: c['post_name']}
    end

    import_posts
  end

  def import_posts
    puts '', "creating topics and posts"

    total_count = @client.query("
      select count(*) count
        from wp_posts
       where post_status <> 'spam'
         and post_type in ('topic', 'reply')").first['count']

    batch_size = 1000

    batches(batch_size) do |offset|
      results = @client.query("
                   select id,
                          post_author,
                          post_date,
                          post_content,
                          post_title,
                          post_type,
                          post_parent
                     from wp_posts
                    where post_status <> 'spam'
                      and post_type in ('topic', 'reply')
                 order by id
                    limit #{batch_size}
                   offset #{offset}", cache_rows: false)

      break if results.size < 1

      create_posts(results, total: total_count, offset: offset) do |post|
        skip = false
        mapped = {}

        mapped[:id] = post["id"]
        mapped[:user_id] = user_id_from_imported_user_id(post["post_author"]) || find_user_by_import_id(post["post_author"]).try(:id) || -1
        mapped[:raw] = post["post_content"]
        mapped[:created_at] = post["post_date"]
        mapped[:custom_fields] = {import_id: post["id"]}

        if post["post_type"] == "topic"
          mapped[:category] = category_from_imported_category_id(post["post_parent"]).try(:name)
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
