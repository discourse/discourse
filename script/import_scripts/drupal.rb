require "mysql2"
require File.expand_path(File.dirname(__FILE__) + "/base.rb")

class ImportScripts::Drupal < ImportScripts::Base

  BATCH_SIZE = 1000

  VID = ENV['DRUPAL_VID'] || 1
  DB_HOST ||= ENV['DB_HOST'] || "localhost"
  DB_NAME ||= ENV['DB_NAME'] || "drupal"
  DB_PW ||= ENV['DB_PW'] || ""
  DB_USER ||= ENV['DB_USER'] || "root"
  TABLE_PREFIX ||= ENV['TABLE_PREFIX'] || "drupal_"

  def initialize
    super

#    IMPORT_AFTER ||= ENV['IMPORT_AFTER'] || '1970-01-01'
#    QUIET = false
#    DEBUG = false

    puts "Opening #{DB_NAME} for #{DB_USER}@#{DB_HOST} with #{DB_PW}"


    @client = Mysql2::Client.new(
      host: DB_HOST,
      username: DB_USER,
      password: DB_PW,
      database: DB_NAME
    )
  end

  def categories_query
    @client.query("SELECT tid, name, description FROM #{TABLE_PREFIX}taxonomy_term_data WHERE vid = #{VID}")
  end


  def execute

    import_users

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

  end

  def import_users
    puts "importing users"
    user_count = @client.query("SELECT COUNT(uid) count FROM #{TABLE_PREFIX}users").first["count"]
    puts "Found #{user_count} users"

    batches(BATCH_SIZE) do |offset|
      users = @client.query("SELECT uid id, name, mail email, created
                             FROM #{TABLE_PREFIX}users
                             ORDER BY uid ASC
                             LIMIT #{BATCH_SIZE}
                             OFFSET #{offset};").to_a

      break if users.count < 1

      users.reject! { |u| @lookup.user_already_imported?(u["id"].to_i) }

      create_users(users, total: user_count, offset: offset) do |row|
        row['email'] = row['name'].gsub(/ /,'_') + '@nowhere.invalid'
        if row['name'].empty?
          next
        end
        { id: row['id'],
          username: row['name'],
          email: row['email'],
          created_at: Time.zone.at(row['created'])
        }
      end
    end
    puts "importing users done."
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
        FROM #{TABLE_PREFIX}node n,
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
          FROM #{TABLE_PREFIX}forum_index fi, #{TABLE_PREFIX}node n
         WHERE n.type = 'forum'
           AND fi.nid = n.nid
           AND n.status = 1;").first['count']

    batches(BATCH_SIZE) do |offset|
      results = @client.query("
        SELECT fi.nid nid,
               fi.title title,
               fi.tid tid,
               n.uid uid,
               fi.created created,
               fi.sticky sticky,
               f.body_value body
          FROM #{TABLE_PREFIX}forum_index fi,
               #{TABLE_PREFIX}node n,
               #{TABLE_PREFIX}field_data_body f
         WHERE n.type = 'forum'
           AND fi.nid = n.nid
           AND n.nid = f.entity_id
           AND n.status = 1
        ORDER BY fi.nid ASC
         LIMIT #{BATCH_SIZE}
        OFFSET #{offset};
      ", cache_rows: false)

      break if results.size < 1

      puts "before goes. #{offset}. . "
      last = 0
      results.each do |r|
        if last == r['nid']
          puts "FOUDN!!! #{last}"
          #printf("#{r['nid']} ")
          last = r['nid']
        end
      end
      puts ". . . done."

#      next if all_records_exist? :posts, results.map { |p| "nid:#{p['nid']}" }
      puts "after goes. . #{offset}. "

      create_posts(results, total: total_count, offset: offset) do |row|
        next if post_id_from_imported_post_id(row['nid'])
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
          FROM #{TABLE_PREFIX}comment c,
               #{TABLE_PREFIX}node n
         WHERE n.nid = c.nid
           AND c.status = 1
           AND n.type IN ('blog', 'forum')
           AND n.status = 1;").first['count']

    batches(BATCH_SIZE) do |offset|
      results = @client.query("
        SELECT c.cid, c.pid, c.nid, c.uid, c.created,
               f.comment_body_value body
          FROM #{TABLE_PREFIX}comment c,
               #{TABLE_PREFIX}field_data_comment_body f,
               #{TABLE_PREFIX}node n
         WHERE c.cid = f.entity_id
           AND n.nid = c.nid
           AND c.status = 1
           AND n.type IN ('blog', 'forum')
           AND n.status = 1
         LIMIT #{BATCH_SIZE}
        OFFSET #{offset};
      ", cache_rows: false)

      puts "#{results.size} found."
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
