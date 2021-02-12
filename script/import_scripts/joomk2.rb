# frozen_string_literal: true
require "mysql2"
require 'uri'
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

  DB_HOST ||= ENV['DB_HOST'] || "localhost"
  DB_NAME ||= ENV['DB_NAME'] || "kunena"
  DB_USER ||= ENV['DB_USER'] || "kunena"
  DB_PW   ||= ENV['DB_PW'] || "kunena"
  KUNENA_PREFIX ||= ENV['KUNENA_PREFIX'] || "jos_" # "iff_" sometimes
  IMAGE_PREFIX ||= ENV['IMAGE_PREFIX'] || "http://EXAMPLE.com/media/kunena/attachments"
  PARENT_FIELD ||= ENV['PARENT_FIELD'] || "parent_id" # "parent" in some versions

  def initialize

    super

    @users = {}

    @client = Mysql2::Client.new(
      host: DB_HOST,
      username: DB_USER,
      password: DB_PW,
      database: DB_NAME
    )
  end

  def execute
    parse_users

    puts "creating users"

    create_users(@users) do |id, user|
      { id: id,
        email: user[:email],
        username: user[:username],
        created_at: user[:created_at],
        bio_raw: user[:bio],
        moderator: user[:moderator] ? true : false,
        admin: user[:admin] ? true : false,
        suspended_at: user[:suspended] ? Time.zone.now : nil,
        suspended_till: user[:suspended] ? 100.years.from_now : nil }
    end

    #deleted_user = User.create(username: "Slettet bruger")

    @users = nil

    puts "Importing Historier"
    parentK2CategoryID = 84
    parentDisCategory = "Historier"
    parentDisCategoryID = Category.find_by(name: parentDisCategory).id
    create_categories(@client.query("SELECT id, name, alias, description, ordering FROM #{KUNENA_PREFIX}k2_categories where parent = #{parentK2CategoryID} ORDER BY id;")) do |c|
      h = { id: c['id'], name: c['name'], description: c['description'], position: c['ordering'].to_i, parent_category_id: parentDisCategoryID}
      h
    end
    import_posts(parentK2CategoryID)


    puts "Importing info"
    parentK2CategoryID = 80
    parentDisCategory = "Om infantilisme"
    parentDisCategoryID = Category.find_by(name: parentDisCategory).id
    create_categories(@client.query("SELECT id, name, alias, description, ordering FROM #{KUNENA_PREFIX}k2_categories where parent = #{parentK2CategoryID} ORDER BY id;")) do |c|
        h = { id: c['id'], name: c['name'], description: c['description'], position: c['ordering'].to_i, parent_category_id: parentDisCategoryID}
        h
      end
   
    import_posts(parentK2CategoryID)


  end

  def parse_users
    # Need to merge data from joomla with kunena

    puts "fetching Joomla users data from mysql"
    results = @client.query("SELECT id, username, email, registerDate FROM #{KUNENA_PREFIX}users where lastvisitDate > DATE_SUB(now(), INTERVAL 6 MONTH) and block = 0;", cache_rows: false)
    results.each do |u|
      next unless u['id'].to_i > (0) && u['username'].present? && u['email'].present?
      username = u['username'].gsub(' ', '_').gsub(/[^A-Za-z0-9_]/, '')[0, User.username_length.end]
      if username.length < User.username_length.first
        username = username * User.username_length.first
      end
      @users[u['id'].to_i] = { id: u['id'].to_i, username: username, email: u['email'], created_at: u['registerDate'] }
    end

    puts "fetching Kunena user data from mysql"
    results = @client.query("SELECT userid, signature, moderator, banned FROM #{KUNENA_PREFIX}kunena_users;", cache_rows: false)
    results.each do |u|
      next unless u['userid'].to_i > 0
      user = @users[u['userid'].to_i]
      if user
        user[:bio] = u['signature']
        user[:moderator] = (u['moderator'].to_i == 1)
        user[:suspended] = u['banned'].present?
      end
    end
  end

  def import_posts(parentIDtoImport)
    puts '', "creating topics and posts"

    total_count = @client.query("SELECT COUNT(*) count FROM #{KUNENA_PREFIX}k2_items m WHERE catid IN (SELECT id FROM #{KUNENA_PREFIX}k2_categories WHERE parent = #{parentIDtoImport});").first['count']

    batch_size = 1000

    batches(batch_size) do |offset|
      results = @client.query("
        SELECT m.id id,
               m.title title,
               m.introtext intro,
               m.fulltext full,
               m.created_by userid,
               m.created time,
               m.catid catid,
               c.name catname
        FROM #{KUNENA_PREFIX}k2_items m, #{KUNENA_PREFIX}k2_categories c
        WHERE c.parent = #{parentIDtoImport}
          AND c.id = m.catid
        ORDER BY m.catid
        LIMIT #{batch_size}
        OFFSET #{offset};
      ", cache_rows: false)    

      break if results.size < 1

      #next if all_records_exist? :posts, results.map { |p| p['id'].to_i }

      create_posts(results, total: total_count, offset: offset) do |m|

        #break if Skip_Cats.include?(m['catid'] )

        skip = false
        mapped = {}

        #mapped[:id] = m['id']
        mapped[:user_id] = user_id_from_imported_user_id(m['created_by']) || -1

        id = m['userid']
        mapped[:raw] = m["intro"] + "<br/>" + m["full"]
        mapped[:created_at] = Time.zone.at(m['time'])

        mapped[:category] = Category.find_by(name: m["catname"]).id
        mapped[:title] = m['title']
        skip ? nil : mapped
      end
    end
  end
end

ImportScripts::Kunena.new.perform
