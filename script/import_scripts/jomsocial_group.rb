# frozen_string_literal: true

require "mysql2"
require "uri"
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

class ImportScripts::JomSocial_Group < ImportScripts::Base
  DB_HOST ||= ENV["DB_HOST"] || "localhost"
  DB_NAME ||= ENV["DB_NAME"] || "kunena"
  DB_USER ||= ENV["DB_USER"] || "kunena"
  DB_PW ||= ENV["DB_PW"] || "kunena"
  KUNENA_PREFIX ||= ENV["KUNENA_PREFIX"] || "jos_" # "iff_" sometimes
  JOMSOC_GID ||= ENV["JOMSOC_GID"] || 111
  DISCOR_CID ||= ENV["DISCOR_CID"] || 72
  IMAGE_PREFIX ||= ENV["IMAGE_PREFIX"] || "http://EXAMPLE.com/media/kunena/attachments"
  #PARENT_FIELD ||= ENV['PARENT_FIELD'] || "parent_id" # "parent" in some versions

  #Space IDs apart
  ALBUM_ID_SEED = 100000
  PHOTO_ID_SEED = 200000

  #  Skip_Cats = [2,3,16,18,19,519,528,532,550]

  # Pre requisites: Imports all albums from one JomSocial Group into one Discourse category, one album per thread, one picture per post
  def initialize
    super

    @users = {}

    @client = Mysql2::Client.new(
      host: DB_HOST,
      username: DB_USER,
      password: DB_PW,
      database: DB_NAME,
    )
  end

  def execute
    parse_users
    import_groups
    import_groupalbums
    import_groupphotos
  end

  def parse_users
    # Need to merge data from joomla with kunena

    puts "fetching Joomla users data from mysql"
    results = @client.query("SELECT id, username, email, registerDate FROM #{KUNENA_PREFIX}users where lastvisitDate > DATE_SUB(now(), INTERVAL 6 MONTH) and block = 0;", cache_rows: false)
    results.each do |u|
      next unless u["id"].to_i > (0) && u["username"].present? && u["email"].present?
      username = u["username"].gsub(" ", "_").gsub(/[^A-Za-z0-9_]/, "")[0, User.username_length.end]
      if username.length < User.username_length.first
        username = username * User.username_length.first
      end
      @users[u["id"].to_i] = { id: u["id"].to_i, username: username, email: u["email"], created_at: u["registerDate"] }
    end

    puts "fetching Kunena user data from mysql"
    results = @client.query("SELECT userid, signature, moderator, banned FROM #{KUNENA_PREFIX}kunena_users;", cache_rows: false)
    results.each do |u|
      next unless u["userid"].to_i > 0
      user = @users[u["userid"].to_i]
      if user
        user[:bio] = u["signature"]
        user[:moderator] = (u["moderator"].to_i == 1)
        user[:suspended] = u["banned"].present?
      end
    end
  end

  def import_groups
    puts "", "processing groups"
    total_count = @client.query("SELECT COUNT(*) count FROM #{KUNENA_PREFIX}community_groups g WHERE g.published=0;").first["count"]

    create_category({ id: "999999", name: "JomSocial Groups import", description: "Admin will correct" }, "999999")

    create_categories(@client.query("SELECT id, name, description FROM #{KUNENA_PREFIX}community_groups WHERE published=0 ORDER BY id;")) do |c|
      #break if Skip_Cats.include?(c['id'])
      h = {
        id: c["id"],
        name: c["name"],
        description: c["description"],
        position: c["ordering"].to_i,
        parent_category_id: category_id_from_imported_category_id("999999"),
      }
      h
    end
  end

  def import_groupalbums
    puts "", "creating topics from albums"

    total_count = @client.query("SELECT COUNT(*) count 
      FROM #{KUNENA_PREFIX}community_photos_albums a,  #{KUNENA_PREFIX}community_groups g
      WHERE g.published=0 and g.id = a.groupid;").first["count"]

    batch_size = 20

    batches(batch_size) do |offset|
      results = @client.query("
      SELECT 
        a.id + #{ALBUM_ID_SEED} aid,
        a.creator userid,
        a.name subject,
        a.description message,
        a.created time,
        a.groupid,
        a.hits 
      FROM #{KUNENA_PREFIX}community_photos_albums a, #{KUNENA_PREFIX}community_groups g
      WHERE g.published=0 and g.id = a.groupid
      ORDER BY a.created
      LIMIT  #{batch_size} 
      OFFSET #{offset};
    ", cache_rows: false)

      break if results.size < 1

      create_posts(results, total: total_count, offset: offset) do |m|
        skip = false
        mapped = {}

        mapped[:id] = m["aid"]
        mapped[:user_id] = user_id_from_imported_user_id(m["userid"]) || -1
        id = m["userid"]
        if m["message"] == ""
          mapped[:raw] = m["subject"]
        else
          mapped[:raw] = m["message"]
        end

        mapped[:created_at] = Time.zone.at(m["time"])
        mapped[:title] = m["subject"]
        mapped[:category] = category_id_from_imported_category_id(m["groupid"])
        mapped[:reads] = m["hits"]
        # puts mapped

        skip ? nil : mapped
      end
    end
  end

  def import_groupphotos
    puts "", "creating posts from photos"

    total_count = @client.query("SELECT COUNT(*) count 
      FROM #{KUNENA_PREFIX}community_photos p, #{KUNENA_PREFIX}community_photos_albums a,  #{KUNENA_PREFIX}community_groups g
      WHERE p.albumid = a.id AND g.published=0 AND g.id = a.groupid;").first["count"]

    batch_size = 200

    batches(batch_size) do |offset|
      results = @client.query("
      SELECT 
        p.id + #{PHOTO_ID_SEED} pid,
        a.id + #{ALBUM_ID_SEED} parent,
        p.creator userid,
        p.caption,
        p.original,
        a.created time,
        a.groupid,
        p.hits 
      FROM #{KUNENA_PREFIX}community_photos p, 
           #{KUNENA_PREFIX}community_photos_albums a, 
           #{KUNENA_PREFIX}community_groups g
      WHERE g.published=0 AND 
            g.id = a.groupid AND
            p.albumid = a.id
      ORDER BY p.created
      LIMIT  #{batch_size} 
      OFFSET #{offset};
    ", cache_rows: false)

      break if results.size < 1

      create_posts(results, total: total_count, offset: offset) do |m|
        skip = false
        mapped = {}

        mapped[:id] = m["pid"]
        mapped[:user_id] = user_id_from_imported_user_id(m["userid"]) || -1
        #id = m["userid"]
        mapped[:raw] = "#{IMAGE_PREFIX}/" + m["original"] + "\n\n" + m["caption"]

        mapped[:created_at] = Time.zone.at(m["time"])
        #mapped[:title] = m["caption"]
        mapped[:reads] = m["hits"]

        parent = topic_lookup_from_imported_post_id(m["parent"])
        if parent
          mapped[:topic_id] = parent[:topic_id]
          mapped[:reply_to_post_number] = parent[:post_number] if parent[:post_number] > 1
        else
          puts "Parent post #{m["parent"]} doesn't exist. Skipping #{m["id"]}: #{m["subject"][0..40]}"
          skip = true
        end

        #puts mapped
        #exit

        skip ? nil : mapped
      end
    end
  end
end

ImportScripts::JomSocial_Group.new.perform
