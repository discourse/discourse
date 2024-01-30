# frozen_string_literal: true

require "pg"

require File.expand_path(File.dirname(__FILE__) + "/base.rb")

# Call it like this:
#   RAILS_ENV=production bundle exec ruby script/import_scripts/fusionforge.rb
class ImportScripts::FusionForge < ImportScripts::Base
  FUSIONFORGE = "fusionforge"
  BATCH_SIZE = 1000

  def initialize
    super

    @client =
      PG.connect(
        host: "localhost",
        user: "fusionforge",
        password: "fusionforge",
        dbname: FUSIONFORGE,
      )
  end

  def execute
    import_users
    import_categories
    import_posts
    import_attachments
  end

  def import_users
    puts "", "creating users"

    total_count =
      @client.exec(
        "
        WITH relevant_posts AS (
          SELECT DISTINCT posted_by FROM forum
        )
        SELECT
          COUNT(DISTINCT user_id) AS count
        FROM users u
        JOIN relevant_posts f on u.user_id = f.posted_by
        ",
      ).first[
        "count"
      ]

    batches(BATCH_SIZE) do |offset|
      results =
        @client.exec(
          # Only select users which have some content
          "WITH relevant_posts AS (
            SELECT DISTINCT posted_by FROM forum
            )
          SELECT
            DISTINCT user_id, email, user_name, add_date, status, unix_pw
          FROM users u
          JOIN relevant_posts f on u.user_id = f.posted_by
          LIMIT #{BATCH_SIZE}
          OFFSET #{offset};",
        )

      break if results.ntuples < 1

      next if all_records_exist? :users, results.map { |u| u["user_id"].to_i }
      puts "Creating users"

      create_users(results, total: total_count, offset: offset) do |user|
        {
          id: user["user_id"],
          email: user["email"],
          username: user["user_name"],
          name: user["name"],
          active: user["status"] == "A" && user["unix_pw"] != "deleted",
          created_at: Time.zone.at(user["add_date"].to_i),
          last_emailed_at: nil, # default is "now", which is not true
          approved: true,
          # for https://github.com/communiteq/discourse-migratepassword/
          # this field results in custom_fields['import_pass']. This also activates the accounts, see base.rb on `u.activate`.
          password: user["unix_pw"] != "deleted" ? user["unix_pw"] : nil,
        }
      end
    end
  end

  def import_categories
    puts "", "importing groups..."

    categories =
      @client.exec(
        "
          SELECT group_id, group_name
          FROM groups
          WHERE use_forum = 1 AND (SELECT COUNT(*) FROM forum_group_list WHERE forum_group_list.group_id = groups.group_id) > 0
          ORDER BY group_id ASC
        ",
      ).to_a

    create_categories(categories) do |category|
      { id: category["group_id"], name: category["group_name"] }
    end

    puts "", "importing forums..."

    children_categories =
      @client.exec(
        "
          SELECT group_forum_id, group_id, forum_name, description
          FROM forum_group_List
          ORDER BY group_id, group_forum_id
        ",
      ).to_a

    create_categories(children_categories) do |category|
      {
        id: "child##{category["group_forum_id"]}",
        name: category["forum_name"],
        description: category["description"],
        parent_category_id: category_id_from_imported_category_id(category["group_id"]),
      }
    end
  end

  def import_posts
    puts "", "creating topics and posts"

    total_count = @client.exec("SELECT count(*) as count from forum").first["count"]

    batches(BATCH_SIZE) do |offset|
      results =
        @client.exec(
          "
        SELECT msg_id,
               group_forum_id,
               subject,
               thread_id,
               posted_by,
               body,
               post_date,
               is_followup_to,
               has_followups
        FROM forum
        ORDER BY thread_id, post_date
        LIMIT #{BATCH_SIZE}
        OFFSET #{offset};
        ",
        ).to_a

      break if results.length < 1
      next if all_records_exist? :posts, results.map { |m| m["msg_id"].to_i }

      create_posts(results, total: total_count, offset: offset) do |m|
        skip = false
        mapped = {}

        mapped[:id] = m["msg_id"]
        mapped[:user_id] = user_id_from_imported_user_id(m["posted_by"]) || -1
        mapped[:raw] = CGI.unescapeHTML(m["body"])
        mapped[:created_at] = Time.zone.at(m["post_date"].to_i)

        if m["is_followup_to"] == "0"
          # if is not a follow up, then it's a thread
          mapped[:category] = category_id_from_imported_category_id(m["group_forum_id"])
          mapped[:title] = CGI.unescapeHTML(m["subject"])
        else
          parent = topic_lookup_from_imported_post_id(m["is_followup_to"].to_i)
          if parent
            mapped[:topic_id] = parent[:topic_id]
          else
            skip = true
          end
        end
        skip ? nil : mapped
      end
    end
  end

  def import_attachments
    puts "", "importing attachments..."

    uploads =
      @client.exec(
        "
      SELECT msg_id, filename, attachmentid
      FROM forum_attachment
      order by msg_id
    ",
      ).to_a

    current_count = 0
    total_count = uploads.count

    uploads.each do |upload|
      post_id = post_id_from_imported_post_id(upload["msg_id"])

      if post_id.nil?
        puts "Post #{upload["msg_id"]} for attachment #{upload["attachmentid"]} not found"
        next
      end

      post = Post.find(post_id)

      real_filename = upload["filename"]
      real_filename.prepend SecureRandom.hex if real_filename[0] == "."

      file_hex = sprintf("%x", upload["attachmentid"])
      prefix = file_hex[-2..-1]
      prefix = file_hex if not prefix
      postfix = file_hex[0..-3].to_s
      postfix = "0" if postfix == ""
      filename = File.join("/tmp/var/lib/fusionforge/forum/", prefix, "/", postfix)

      upl_obj = create_upload(post.user.id, filename, real_filename)

      if upl_obj&.persisted?
        html = html_for_upload(upl_obj, real_filename)
        if !post.raw[html]
          post.raw += "\n\n#{html}\n\n"
          post.save!
          if PostUpload.where(post: post, upload: upl_obj).exists?
            puts "skipping creating uploaded for previously uploaded file #{upload["attachmentid"]}"
          else
            PostUpload.create!(post: post, upload: upl_obj)
          end
        else
          puts "Skipping attachment #{upload["attachmentid"]}"
        end
      else
        puts "Failed to upload attachment #{upload["attachmentid"]}"
        exit
      end

      current_count += 1
      print_status(current_count, total_count)
    end
  end
end

ImportScripts::FusionForge.new.perform
