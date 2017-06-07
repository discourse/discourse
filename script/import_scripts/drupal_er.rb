require "mysql2"
require File.expand_path(File.dirname(__FILE__) + "/base.rb")
require File.expand_path(File.dirname(__FILE__) + "/drupal.rb")

class ImportScripts::DrupalER < ImportScripts::Drupal


  def execute

    # # You'll need to edit the following query for your Drupal install:
    # #
    # #   * Drupal allows duplicate category names, so you may need to exclude some categories or rename them here.
    # #   * Table name may be term_data.
    # #   * May need to select a vid other than 1.
    # create_categories(categories_query) do |c|
    #   {id: c['tid'], name: c['name'], description: c['description']}
    # end

    create_users

    create_post_and_wiki_topics

    create_challenge_response_topics

    create_replies


    begin
      create_admin(email: 'admin@example.com', username: UserNameSuggester.suggest('admin'))
    rescue => e
      puts '', "Failed to create admin user"
      puts e.message
    end
  end


  def create_users
    sql = <<-SQL
      SELECT u.uid id, u.name, u.mail email, u.created, fb.field_bio_value bio_raw, fa.field_agegroup_value agegroup,
        bi.field_i_m_based_in_value location, fu.field_facebook_url_url facebook_url, tu.field_twitter_url_url twitter_url,
        lu.field_linkedin_url_url linkedin_url, wu.field_website_url_url website_url, fc.field_first_contact_value first_contact,
        co.field_consent_opencare_value consent_opencare_date
      FROM users AS u
        LEFT JOIN field_data_field_bio AS fb on u.uid = fb.entity_id
        LEFT JOIN field_data_field_agegroup AS fa on u.uid = fa.entity_id
        LEFT JOIN field_data_field_i_m_based_in AS bi on u.uid = bi.entity_id
        LEFT JOIN field_data_field_facebook_url AS fu on u.uid = fu.entity_id
        LEFT JOIN field_data_field_twitter_url AS tu on u.uid = tu.entity_id
        LEFT JOIN field_data_field_linkedin_url AS lu on u.uid = lu.entity_id
        LEFT JOIN field_data_field_website_url AS wu on u.uid = wu.entity_id
        LEFT JOIN field_data_field_first_contact AS fc on u.uid = fc.entity_id
        LEFT JOIN field_data_field_consent_opencare AS co on u.uid = co.entity_id
      WHERE
        u.uid != 0 AND
        (fb.entity_type = 'user' or fb.entity_type is null) AND
        (fa.entity_type = 'user' or fa.entity_type is null) AND
        (bi.entity_type = 'user' or bi.entity_type is null) AND
        (fu.entity_type = 'user' or fu.entity_type is null) AND
        (tu.entity_type = 'user' or tu.entity_type is null) AND
        (lu.entity_type = 'user' or lu.entity_type is null) AND
        (wu.entity_type = 'user' or wu.entity_type is null) AND
        (fc.entity_type = 'user' or fc.entity_type is null) AND
        (co.entity_type = 'user' or co.entity_type is null)
    SQL
    super(@client.query(sql)) do |row|
      {
        id: row['id'],
        username: row['name'],
        #email: row['email'],
        email: "#{rand(36**12).to_s(36)}@example.com",
        created_at: Time.zone.at(row['created']),
        bio_raw: row['bio_raw'],
        website: row['website_url'],
        location: row['location'],
        # avatar_url: ,
        custom_fields: {
          agegroup: row['agegroup'],
          facebook_url: row['facebook_url'],
          twitter_url: row['twitter_url'],
          linkedin_url: row['linkedin_url'],
          first_contact: row['first_contact'],
          consent_opencare: row['consent_opencare_date']
        }
      }
    end
  end


  def create_post_and_wiki_topics
    puts '', 'creating post and wiki topics'

    # create_category({
    #                   name: 'Post',
    #                   user_id: -1,
    #                   description: "Articles from the blog"
    #                 }, nil) unless Category.find_by_name('Blog')

    sql = <<-SQL
      SELECT
        n.nid nid,
        n.type type,
        n.uid user_id,
        n.status status,
        n.created created,
        n.changed changed,
        tf.title_field_value title,
        db.body_value content
      FROM node AS n
        LEFT JOIN field_data_title_field AS tf on n.nid = tf.entity_id
        LEFT JOIN field_data_body AS db on n.nid = db.entity_id
      WHERE
        n.type IN('post', 'wiki')
    SQL

    results = @client.query(sql, cache_rows: false)

    create_posts(results) do |row|
      {
        id: "nid:#{row['nid']}",
        user_id: user_id_from_imported_user_id(row['uid']) || -1,
        title: row['title'].try(:strip),
        raw: row['content'],
        created_at: Time.zone.at(row['created']),
        updated_at: Time.zone.at(row['changed']),
        custom_fields: {import_id: "nid:#{row['nid']}"}
        # category: 'Blog',
        # visible: row['status'].to_i == 0 ? false : true
        # pinned_at: row['sticky'].to_i == 1 ? Time.zone.at(row['created']) : nil,
      }
    end
  end



  def create_challenge_response_topics
    puts '', 'creating challenge response topics'

    # create_category({
    #                   name: 'Post',
    #                   user_id: -1,
    #                   description: "Articles from the blog"
    #                 }, nil) unless Category.find_by_name('Blog')

    sql = <<-SQL
      SELECT
        n.nid nid,
        n.uid user_id,
        tf.title_field_value title,
        db.body_value content,
        n.status status,
        n.created created,
        n.changed changed,
        n.type type
      FROM node AS n
        LEFT JOIN field_data_title_field AS tf on n.nid = tf.entity_id
        LEFT JOIN field_data_body AS db on n.nid = db.entity_id
      WHERE
        n.type IN('post', 'wiki')
    SQL

    results = @client.query(sql, cache_rows: false)


    create_posts(results) do |row|
      {
        id: "nid:#{row['nid']}",
        user_id: user_id_from_imported_user_id(row['uid']) || -1,
        title: row['title'].try(:strip),
        raw: row['content'],
        created_at: Time.zone.at(row['created']),
        updated_at: Time.zone.at(row['changed']),
        custom_fields: {import_id: "nid:#{row['nid']}"}
        # category: 'Blog',
        # visible: row['status'].to_i == 0 ? false : true
        # pinned_at: row['sticky'].to_i == 1 ? Time.zone.at(row['created']) : nil,
      }
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
           AND n.type IN ('challenge_response', 'post', 'wiki');").first['count']

    batch_size = 1000

    batches(batch_size) do |offset|
      results = @client.query("
        SELECT c.cid, c.pid, c.nid, c.uid, c.created, c.subject,
               f.comment_body_value body
          FROM comment c,
               field_data_comment_body f,
               node n
         WHERE c.cid = f.entity_id
           AND n.nid = c.nid
           AND c.status = 1
           AND n.type IN ('challenge_response', 'post', 'wiki')
         LIMIT #{batch_size}
        OFFSET #{offset};
      ", cache_rows: false)

      break if results.size < 1

      next if all_records_exist? :posts, results.map {|p| "cid:#{p['cid']}"}

      create_posts(results, total: total_count, offset: offset) do |row|
        topic_mapping = topic_lookup_from_imported_post_id("nid:#{row['nid']}")
        if topic_mapping && topic_id = topic_mapping[:topic_id]
          h = {
            id: "cid:#{row['cid']}",
            topic_id: topic_id,
            user_id: user_id_from_imported_user_id(row['uid']) || -1,
            title: row['title'].try(:subject),
            raw: row['body'],
            created_at: Time.zone.at(row['created']),
          }
          if row['pid']
            parent = topic_lookup_from_imported_post_id("cid:#{row['pid']}")
            h[:reply_to_post_number] = parent[:post_number] if parent and parent[:post_number] > 1
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

if __FILE__==$0
  ImportScripts::DrupalER.new.perform
end
