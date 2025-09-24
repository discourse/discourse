# frozen_string_literal: true

require "mysql2"
require_relative "base"

class ImportScripts::Drupal < ImportScripts::Base
  DRUPAL_DB = ENV["DRUPAL_DB"] || "newsite3"
  VID = ENV["DRUPAL_VID"] || 1

  def initialize
    super

    @client =
      Mysql2::Client.new(
        host: "localhost",
        username: "root",
        #password: "password",
        database: DRUPAL_DB,
      )
  end

  def categories_query
    @client.query("SELECT tid, name, description FROM term_data WHERE vid = #{VID}")
  end

  def execute
    create_users(@client.query("SELECT uid id, name, mail email, created FROM users;")) do |row|
      {
        id: row["id"],
        username: row["name"],
        email: row["email"],
        created_at: Time.zone.at(row["created"]),
      }
    end

    # You'll need to edit the following query for your Drupal install:
    #
    #   * Drupal allows duplicate category names, so you may need to exclude some categories or rename them here.
    #   * Table name may be term_data.
    #   * May need to select a vid other than 1.
    create_categories(categories_query) do |c|
      { id: c["tid"], name: c["name"], description: c["description"] }
    end

    # "Nodes" in Drupal are divided into types. Here we import two types,
    # and will later import all the comments/replies for each node.
    # You will need to figure out what the type names are on your install and edit the queries to match.
    create_blog_topics if ENV["DRUPAL_IMPORT_BLOG"]

    create_forum_topics

    create_replies

    begin
      create_admin(email: "neil.lalonde@discourse.org", username: UserNameSuggester.suggest("neil"))
    rescue => e
      puts "", "Failed to create admin user"
      puts e.message
    end
  end

  def create_blog_topics
    puts "", "creating blog topics"

    unless Category.find_by_name("Blog")
      create_category({ name: "Blog", user_id: -1, description: "Articles from the blog" }, nil)
    end

    results =
      @client.query(
        "
      SELECT n.nid nid,
	n.title title,
	n.uid uid,
	n.created created,
	n.sticky sticky,
	nr.body body
      FROM node n
      LEFT JOIN node_revisions nr ON nr.vid=n.vid
      WHERE n.type = 'blog'
        AND n.status = 1
    ",
        cache_rows: false,
      )

    create_posts(results) do |row|
      {
        id: "nid:#{row["nid"]}",
        user_id: user_id_from_imported_user_id(row["uid"]) || -1,
        category: "Blog",
        raw: row["body"],
        created_at: Time.zone.at(row["created"]),
        pinned_at: row["sticky"].to_i == 1 ? Time.zone.at(row["created"]) : nil,
        title: row["title"].try(:strip),
        custom_fields: {
          import_id: "nid:#{row["nid"]}",
        },
      }
    end
  end

  def create_forum_topics
    puts "", "creating forum topics"

    total_count =
      @client.query(
        "
      SELECT COUNT(*) count
      FROM node n
      LEFT JOIN forum f ON f.vid=n.vid
      WHERE n.type = 'forum'
        AND n.status = 1
    ",
      ).first[
        "count"
      ]

    batch_size = 1000

    batches(batch_size) do |offset|
      results =
        @client.query(
          "
        SELECT n.nid nid,
	       n.title title,
               f.tid tid,
               n.uid uid,
               n.created created,
               n.sticky sticky,
               nr.body body
        FROM node n
        LEFT JOIN forum f ON f.vid=n.vid
        LEFT JOIN node_revisions nr ON nr.vid=n.vid
        WHERE n.type = 'forum'
          AND n.status = 1
	LIMIT #{batch_size}
          OFFSET #{offset};
      ",
          cache_rows: false,
        )

      break if results.size < 1

      next if all_records_exist? :posts, results.map { |p| "nid:#{p["nid"]}" }

      create_posts(results, total: total_count, offset: offset) do |row|
        {
          id: "nid:#{row["nid"]}",
          user_id: user_id_from_imported_user_id(row["uid"]) || -1,
          category: category_id_from_imported_category_id(row["tid"]),
          raw: row["body"],
          created_at: Time.zone.at(row["created"]),
          pinned_at: row["sticky"].to_i == 1 ? Time.zone.at(row["created"]) : nil,
          title: row["title"].try(:strip),
        }
      end
    end
  end

  def create_replies
    puts "", "creating replies in topics"

    if ENV["DRUPAL_IMPORT_BLOG"]
      node_types = "('forum','blog')"
    else
      node_types = "('forum')"
    end

    total_count =
      @client.query(
        "
      SELECT COUNT(*) count
      FROM comments c
      LEFT JOIN node n ON n.nid=c.nid
      WHERE n.type IN #{node_types}
      AND n.status = 1
      AND c.status=0;
    ",
      ).first[
        "count"
      ]

    batch_size = 1000

    batches(batch_size) do |offset|
      results =
        @client.query(
          "
        SELECT c.cid,
               c.pid,
               c.nid,
               c.uid,
               c.timestamp,
               c.comment body
        FROM comments c
        LEFT JOIN node n ON n.nid=c.nid
        WHERE n.type IN #{node_types}
          AND n.status = 1
          AND c.status=0
        LIMIT #{batch_size}
          OFFSET #{offset};
      ",
          cache_rows: false,
        )

      break if results.size < 1

      next if all_records_exist? :posts, results.map { |p| "cid:#{p["cid"]}" }

      create_posts(results, total: total_count, offset: offset) do |row|
        topic_mapping = topic_lookup_from_imported_post_id("nid:#{row["nid"]}")
        if topic_mapping && topic_id = topic_mapping[:topic_id]
          h = {
            id: "cid:#{row["cid"]}",
            topic_id: topic_id,
            user_id: user_id_from_imported_user_id(row["uid"]) || -1,
            raw: row["body"],
            created_at: Time.zone.at(row["timestamp"]),
          }
          if row["pid"]
            parent = topic_lookup_from_imported_post_id("cid:#{row["pid"]}")
            h[:reply_to_post_number] = parent[:post_number] if parent && parent[:post_number] > (1)
          end
          h
        else
          puts "No topic found for comment #{row["cid"]}"
          nil
        end
      end
    end
  end
end

ImportScripts::Drupal.new.perform if __FILE__ == $0
