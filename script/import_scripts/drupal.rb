require "mysql2"
require File.expand_path(File.dirname(__FILE__) + "/base.rb")

class ImportScripts::Drupal < ImportScripts::Base

  DRUPAL_DB = ENV['DRUPAL_DB'] || "newsite3"
  VID = ENV['DRUPAL_VID'] || 1

  def initialize
    super

    @client = Mysql2::Client.new(
      host: "localhost",
      username: "root",
      #password: "password",
      database: DRUPAL_DB
    )
  end

  def categories_query
    @client.query("SELECT tid, name, description FROM taxonomy_term_data WHERE vid = #{VID}")
  end

  def execute
    create_users(@client.query("SELECT uid id, name, mail email, created FROM users;")) do |row|
      { id: row['id'], username: row['name'], email: row['email'], created_at: Time.zone.at(row['created']) }
    end

    # You'll need to edit the following query for your Drupal install:
    #
    #   * Drupal allows duplicate category names, so you may need to exclude some categories or rename them here.
    #   * Table name may be term_data.
    #   * May need to select a vid other than 1.
    create_categories(categories_query) do |c|
      { id: c['tid'], name: c['name'], description: c['description'] }
    end

    # "Nodes" in Drupal are divided into types. Here we import two types,
    # and will later import all the comments/replies for each node.
    # You will need to figure out what the type names are on your install and edit the queries to match.
    if ENV['DRUPAL_IMPORT_BLOG']
      create_blog_topics
    end

    create_forum_topics

    create_replies

    begin
      create_admin(email: 'neil.lalonde@discourse.org', username: UserNameSuggester.suggest('neil'))
    rescue => e
      puts '', "Failed to create admin user"
      puts e.message
    end
  end

  def create_blog_topics
    puts '', "creating blog topics"

    create_category({
      name: 'Blog',
      user_id: -1,
      description: "Articles from the blog"
    }, nil) unless Category.find_by_name('Blog')

    results = @client.query("
      SELECT n.nid nid, n.title title, n.uid uid, n.created created, n.sticky sticky,
             f.body_value body
        FROM node n,
             field_data_body f
       WHERE n.type = 'blog'
         AND n.nid = f.entity_id
         AND n.status = 1
    ", cache_rows: false)

    create_posts(results) do |row|
      {
        id: "nid:#{row['nid']}",
        user_id: user_id_from_imported_user_id(row['uid']) || -1,
        category: 'Blog',
        raw: row['body'],
        created_at: Time.zone.at(row['created']),
        pinned_at: row['sticky'].to_i == 1 ? Time.zone.at(row['created']) : nil,
        title: row['title'].try(:strip),
        custom_fields: { import_id: "nid:#{row['nid']}" }
      }
    end
  end

  def create_forum_topics
    puts '', "creating forum topics"

    total_count = @client.query("
        SELECT COUNT(*) count
          FROM forum_index fi, node n
         WHERE n.type = 'forum'
           AND fi.nid = n.nid
           AND n.status = 1;").first['count']

    batch_size = 1000

    batches(batch_size) do |offset|
      results = @client.query("
        SELECT fi.nid nid,
               fi.title title,
               fi.tid tid,
               n.uid uid,
               fi.created created,
               fi.sticky sticky,
               f.body_value body
          FROM forum_index fi,
               node n,
               field_data_body f
         WHERE n.type = 'forum'
           AND fi.nid = n.nid
           AND n.nid = f.entity_id
           AND n.status = 1
         LIMIT #{batch_size}
        OFFSET #{offset};
      ", cache_rows: false)

      break if results.size < 1

      next if all_records_exist? :posts, results.map { |p| "nid:#{p['nid']}" }

      create_posts(results, total: total_count, offset: offset) do |row|
        {
          id: "nid:#{row['nid']}",
          user_id: user_id_from_imported_user_id(row['uid']) || -1,
          category: category_id_from_imported_category_id(row['tid']),
          raw: row['body'],
          created_at: Time.zone.at(row['created']),
          pinned_at: row['sticky'].to_i == 1 ? Time.zone.at(row['created']) : nil,
          title: row['title'].try(:strip)
        }
      end
    end
  end

  def create_replies
    puts '', "creating replies in topics"

    total_count = @client.query("
        SELECT COUNT(*) count
          FROM comment c,
               node n
         WHERE n.nid = c.nid
           AND c.status = 1
           AND n.type IN ('blog', 'forum')
           AND n.status = 1;").first['count']

    batch_size = 1000

    batches(batch_size) do |offset|
      results = @client.query("
        SELECT c.cid, c.pid, c.nid, c.uid, c.created,
               f.comment_body_value body
          FROM comment c,
               field_data_comment_body f,
               node n
         WHERE c.cid = f.entity_id
           AND n.nid = c.nid
           AND c.status = 1
           AND n.type IN ('blog', 'forum')
           AND n.status = 1
         LIMIT #{batch_size}
        OFFSET #{offset};
      ", cache_rows: false)

      break if results.size < 1

      next if all_records_exist? :posts, results.map { |p| "cid:#{p['cid']}" }

      create_posts(results, total: total_count, offset: offset) do |row|
        topic_mapping = topic_lookup_from_imported_post_id("nid:#{row['nid']}")
        if topic_mapping && topic_id = topic_mapping[:topic_id]
          h = {
            id: "cid:#{row['cid']}",
            topic_id: topic_id,
            user_id: user_id_from_imported_user_id(row['uid']) || -1,
            raw: row['body'],
            created_at: Time.zone.at(row['created']),
          }
          if row['pid']
            parent = topic_lookup_from_imported_post_id("cid:#{row['pid']}")
            h[:reply_to_post_number] = parent[:post_number] if parent && parent[:post_number] > (1)
          end
          h
        else
          puts "No topic found for comment #{row['cid']}"
          nil
        end
      end
    end
  end

end

if __FILE__ == $0
  ImportScripts::Drupal.new.perform
end
