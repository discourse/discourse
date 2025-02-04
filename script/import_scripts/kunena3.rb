# frozen_string_literal: true

require "mysql2"
require File.expand_path(File.dirname(__FILE__) + "/base.rb")

# If you change this script's functionality, please consider making a note here:
# https://meta.discourse.org/t/importing-from-kunena-3/43776

# Before running this script, paste these lines into your shell,
# then use arrow keys to edit the values
=begin
export DB_HOST="localhost"
export DB_NAME="kunena"
export DB_USER="kunena"
export DB_PW="kunena"
export KUNENA_PREFIX="jos_" # "iff_" sometimes
export IMAGE_PREFIX="http://EXAMPLE.com/media/kunena/attachments"
export PARENT_FIELD="parent_id" # "parent" in some versions
=end

class ImportScripts::Kunena < ImportScripts::Base
  DB_HOST = ENV["DB_HOST"] || "localhost"
  DB_NAME = ENV["DB_NAME"] || "kunena"
  DB_USER = ENV["DB_USER"] || "kunena"
  DB_PW = ENV["DB_PW"] || "kunena"
  KUNENA_PREFIX = ENV["KUNENA_PREFIX"] || "jos_" # "iff_" sometimes
  IMAGE_PREFIX = ENV["IMAGE_PREFIX"] || "http://EXAMPLE.com/media/kunena/attachments"
  PARENT_FIELD = ENV["PARENT_FIELD"] || "parent_id" # "parent" in some versions

  def initialize
    super

    @users = {}

    @client =
      Mysql2::Client.new(host: DB_HOST, username: DB_USER, password: DB_PW, database: DB_NAME)
  end

  def execute
    parse_users

    puts "creating users"

    create_users(@users) do |id, user|
      {
        id: id,
        email: user[:email],
        username: user[:username],
        created_at: user[:created_at],
        bio_raw: user[:bio],
        moderator: user[:moderator] ? true : false,
        admin: user[:admin] ? true : false,
        suspended_at: user[:suspended] ? Time.zone.now : nil,
        suspended_till: user[:suspended] ? 100.years.from_now : nil,
      }
    end

    @users = nil

    create_categories(
      @client.query(
        "SELECT id, #{PARENT_FIELD} as parent_id, name, description, ordering FROM #{KUNENA_PREFIX}kunena_categories ORDER BY #{PARENT_FIELD}, id;",
      ),
    ) do |c|
      h = {
        id: c["id"],
        name: c["name"],
        description: c["description"],
        position: c["ordering"].to_i,
      }
      if c["parent_id"].to_i > 0
        h[:parent_category_id] = category_id_from_imported_category_id(c["parent_id"])
      end
      h
    end

    import_posts

    begin
      create_admin(email: "CHANGE@ME.COM", username: UserNameSuggester.suggest("CHAMGEME"))
    rescue => e
      puts "", "Failed to create admin user"
      puts e.message
    end
  end

  def parse_users
    # Need to merge data from joomla with kunena

    puts "fetching Joomla users data from mysql"
    results =
      @client.query(
        "SELECT id, username, email, registerDate FROM #{KUNENA_PREFIX}users;",
        cache_rows: false,
      )
    results.each do |u|
      next if u["id"].to_i <= (0) || u["username"].blank? || u["email"].blank?
      username = u["username"].gsub(" ", "_").gsub(/[^A-Za-z0-9_]/, "")[0, User.username_length.end]
      if username.length < User.username_length.first
        username = username * User.username_length.first
      end
      @users[u["id"].to_i] = {
        id: u["id"].to_i,
        username: username,
        email: u["email"],
        created_at: u["registerDate"],
      }
    end

    puts "fetching Kunena user data from mysql"
    results =
      @client.query(
        "SELECT userid, signature, moderator, banned FROM #{KUNENA_PREFIX}kunena_users;",
        cache_rows: false,
      )
    results.each do |u|
      next if u["userid"].to_i <= 0
      user = @users[u["userid"].to_i]
      if user
        user[:bio] = u["signature"]
        user[:moderator] = (u["moderator"].to_i == 1)
        user[:suspended] = u["banned"].present?
      end
    end
  end

  def import_posts
    puts "", "creating topics and posts"

    total_count =
      @client.query("SELECT COUNT(*) count FROM #{KUNENA_PREFIX}kunena_messages m;").first["count"]

    batch_size = 1000

    batches(batch_size) do |offset|
      results =
        @client.query(
          "
        SELECT m.id id,
               m.thread thread,
               m.parent parent,
               m.catid catid,
               m.userid userid,
               m.subject subject,
               m.time time,
               t.message message
        FROM #{KUNENA_PREFIX}kunena_messages m,
             #{KUNENA_PREFIX}kunena_messages_text t
        WHERE m.id = t.mesid
        ORDER BY m.id
        LIMIT #{batch_size}
        OFFSET #{offset};
      ",
          cache_rows: false,
        )

      break if results.size < 1

      next if all_records_exist? :posts, results.map { |p| p["id"].to_i }

      create_posts(results, total: total_count, offset: offset) do |m|
        skip = false
        mapped = {}

        mapped[:id] = m["id"]
        mapped[:user_id] = user_id_from_imported_user_id(m["userid"]) || -1

        id = m["userid"]
        mapped[:raw] = m["message"].gsub(
          %r{\[attachment=[0-9]+\](.+?)\[/attachment\]},
          "\n#{IMAGE_PREFIX}/#{id}/\\1",
        )
        mapped[:created_at] = Time.zone.at(m["time"])

        if m["parent"] == 0
          mapped[:category] = category_id_from_imported_category_id(m["catid"])
          mapped[:title] = m["subject"]
        else
          parent = topic_lookup_from_imported_post_id(m["parent"])
          if parent
            mapped[:topic_id] = parent[:topic_id]
            mapped[:reply_to_post_number] = parent[:post_number] if parent[:post_number] > 1
          else
            puts "Parent post #{m["parent"]} doesn't exist. Skipping #{m["id"]}: #{m["subject"][0..40]}"
            skip = true
          end
        end

        skip ? nil : mapped
      end
    end
  end
end

ImportScripts::Kunena.new.perform
