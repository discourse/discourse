# frozen_string_literal: true

require "mysql2"
require "htmlentities"
require File.expand_path(File.dirname(__FILE__) + "/base.rb")

class ImportScripts::Drupal < ImportScripts::Base

  DRUPAL_DB = ENV['DRUPAL_DB'] || "drupal"
  VID = ENV['DRUPAL_VID'] || 1
  BATCH_SIZE = 1000
  ATTACHMENT_DIR = "/root/files/upload"

  def initialize
    super

    @htmlentities = HTMLEntities.new

    @client = Mysql2::Client.new(
      host: "localhost",
      username: "root",
      #password: "password",
      database: DRUPAL_DB
    )
  end

  def execute

    import_users
    import_categories

    # "Nodes" in Drupal are divided into types. Here we import two types,
    # and will later import all the comments/replies for each node.
    # You will need to figure out what the type names are on your install and edit the queries to match.
    if ENV['DRUPAL_IMPORT_BLOG']
      import_blog_topics
    end

    import_forum_topics

    import_replies
    import_likes
    mark_topics_as_solved
    import_sso_records
    import_attachments
    postprocess_posts
    create_permalinks
    import_gravatars
  end

  def import_users
    puts "", "importing users"

    user_count = mysql_query("SELECT count(uid) count FROM users").first["count"]

    last_user_id = -1

    batches(BATCH_SIZE) do |offset|
      users = mysql_query(<<-SQL
          SELECT uid,
                 name username,
                 mail email,
                 created
            FROM users
           WHERE uid > #{last_user_id}
        ORDER BY uid
           LIMIT #{BATCH_SIZE}
      SQL
      ).to_a

      break if users.empty?

      last_user_id = users[-1]["uid"]

      users.reject! { |u| @lookup.user_already_imported?(u["uid"]) }

      create_users(users, total: user_count, offset: offset) do |user|
        email = user["email"].presence || fake_email
        email = fake_email unless email[EmailValidator.email_regex]

        username = @htmlentities.decode(user["username"]).strip

        {
          id: user["uid"],
          name: username,
          email: email,
          created_at: Time.zone.at(user["created"])
        }
      end
    end
  end

  def import_categories
    # You'll need to edit the following query for your Drupal install:
    #
    #   * Drupal allows duplicate category names, so you may need to exclude some categories or rename them here.
    #   * Table name may be term_data.
    #   * May need to select a vid other than 1

    puts "", "importing categories"

    categories = mysql_query(<<-SQL
        SELECT tid,
               name,
               description
          FROM taxonomy_term_data
         WHERE vid = #{VID}
    SQL
    ).to_a

    create_categories(categories) do |category|
      {
        id: category['tid'],
        name: @htmlentities.decode(category['name']).strip,
        description: @htmlentities.decode(category['description']).strip
      }
    end
  end

  def import_blog_topics
    puts '', "importing blog topics"

    create_category(
      {
        name: 'Blog',
        description: "Articles from the blog"
      },
    nil) unless Category.find_by_name('Blog')

    blogs = mysql_query(<<-SQL
      SELECT n.nid nid, n.title title, n.uid uid, n.created created, n.sticky sticky,
             f.body_value body
        FROM node n,
             field_data_body f
       WHERE n.type = 'article'
         AND n.nid = f.entity_id
         AND n.status = 1
    SQL
    ).to_a

    category_id = Category.find_by_name('Blog').id

    create_posts(blogs) do |topic|
      {
        id: "nid:#{topic['nid']}",
        user_id: user_id_from_imported_user_id(topic['uid']) || -1,
        category: category_id,
        raw: topic['body'],
        created_at: Time.zone.at(topic['created']),
        pinned_at: topic['sticky'].to_i == 1 ? Time.zone.at(topic['created']) : nil,
        title: topic['title'].try(:strip),
        custom_fields: { import_id: "nid:#{topic['nid']}" }
      }
    end
  end

  def import_forum_topics
    puts '', "importing forum topics"

    total_count = mysql_query(<<-SQL
        SELECT COUNT(*) count
          FROM forum_index fi, node n
         WHERE n.type = 'forum'
           AND fi.nid = n.nid
           AND n.status = 1
    SQL
    ).first['count']

    batches(BATCH_SIZE) do |offset|
      results = mysql_query(<<-SQL
        SELECT fi.nid nid,
               fi.title title,
               fi.tid tid,
               n.uid uid,
               fi.created created,
               fi.sticky sticky,
               f.body_value body,
	       nc.totalcount views,
	       fl.timestamp solved
          FROM forum_index fi
	 LEFT JOIN node n ON fi.nid = n.nid
	 LEFT JOIN field_data_body f ON f.entity_id = n.nid
	 LEFT JOIN flagging fl ON fl.entity_id = n.nid
	     AND fl.fid = 7
	 LEFT JOIN node_counter nc ON nc.nid = n.nid
         WHERE n.type = 'forum'
           AND n.status = 1
         LIMIT #{BATCH_SIZE}
        OFFSET #{offset};
      SQL
      ).to_a

      break if results.size < 1

      next if all_records_exist? :posts, results.map { |p| "nid:#{p['nid']}" }

      create_posts(results, total: total_count, offset: offset) do |row|
        raw = preprocess_raw(row['body'])
        topic = {
          id: "nid:#{row['nid']}",
          user_id: user_id_from_imported_user_id(row['uid']) || -1,
          category: category_id_from_imported_category_id(row['tid']),
          raw: raw,
          created_at: Time.zone.at(row['created']),
          pinned_at: row['sticky'].to_i == 1 ? Time.zone.at(row['created']) : nil,
          title: row['title'].try(:strip),
          views: row['views']
        }
        topic[:custom_fields] = { import_solved: true } if row['solved'].present?
        topic
      end
    end
  end

  def import_replies
    puts '', "creating replies in topics"

    total_count = mysql_query(<<-SQL
        SELECT COUNT(*) count
          FROM comment c,
               node n
         WHERE n.nid = c.nid
           AND c.status = 1
           AND n.type IN ('article', 'forum')
           AND n.status = 1
    SQL
    ).first['count']

    batches(BATCH_SIZE) do |offset|
      results = mysql_query(<<-SQL
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
         LIMIT #{BATCH_SIZE}
        OFFSET #{offset}
      SQL
      ).to_a

      break if results.size < 1

      next if all_records_exist? :posts, results.map { |p| "cid:#{p['cid']}" }

      create_posts(results, total: total_count, offset: offset) do |row|
        topic_mapping = topic_lookup_from_imported_post_id("nid:#{row['nid']}")
        if topic_mapping && topic_id = topic_mapping[:topic_id]
          raw = preprocess_raw(row['body'])
          h = {
            id: "cid:#{row['cid']}",
            topic_id: topic_id,
            user_id: user_id_from_imported_user_id(row['uid']) || -1,
            raw: raw,
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

  def import_likes
    puts "", "importing post likes"

    batches(BATCH_SIZE) do |offset|
      likes = mysql_query(<<-SQL
        SELECT flagging_id,
               fid,
	       entity_id,
	       uid
	  FROM flagging
	 WHERE fid = 5
	    OR fid = 6
	 LIMIT #{BATCH_SIZE}
	OFFSET #{offset}
      SQL
      ).to_a

      break if likes.empty?

      likes.each do |l|
        identifier = l['fid'] == 5 ? 'nid' : 'cid'
        next unless user_id = user_id_from_imported_user_id(l['uid'])
        next unless post_id = post_id_from_imported_post_id("#{identifier}:#{l['entity_id']}")
        next unless user = User.find_by(id: user_id)
        next unless post = Post.find_by(id: post_id)
        PostActionCreator.like(user, post) rescue nil
      end
    end
  end

  def mark_topics_as_solved
    puts "", "marking topics as solved"

    solved_topics = TopicCustomField.where(name: "import_solved").where(value: true).pluck(:topic_id)

    solved_topics.each do |topic_id|
      next unless topic = Topic.find(topic_id)
      next unless post = topic.posts.last
      post_id = post.id

      PostCustomField.create!(post_id: post_id, name: "is_accepted_answer", value: true)
      TopicCustomField.create!(topic_id: topic_id, name: "accepted_answer_post_id", value: post_id)
    end
  end

  def import_sso_records
    puts "", "importing sso records"

    start_time = Time.now
    current_count = 0

    users = UserCustomField.where(name: "import_id")

    total_count = users.count

    return if users.empty?

    users.each do |ids|
      user_id = ids.user_id
      external_id = ids.value
      next unless user = User.find(user_id)

      begin
        current_count += 1
        print_status(current_count, total_count, start_time)
        SingleSignOnRecord.create!(user_id: user.id, external_id: external_id, external_email: user.email, last_payload: '')
      rescue
        next
      end
    end
  end

  def import_attachments
    puts "", "importing attachments"

    current_count = 0
    success_count = 0
    fail_count = 0

    total_count = mysql_query(<<-SQL
      SELECT count(field_post_attachment_fid) count
        FROM field_data_field_post_attachment
    SQL
    ).first["count"]

    batches(BATCH_SIZE) do |offset|
      attachments = mysql_query(<<-SQL
          SELECT *
            FROM field_data_field_post_attachment fp
       LEFT JOIN file_managed fm
              ON fp.field_post_attachment_fid = fm.fid
           LIMIT #{BATCH_SIZE}
          OFFSET #{offset}
      SQL
      ).to_a

      break if attachments.size < 1

      attachments.each do |attachment|
        current_count += 1
        print_status current_count, total_count

        identifier = attachment['entity_type'] == "comment" ? "cid" : "nid"
        next unless user_id = user_id_from_imported_user_id(attachment['uid'])
        next unless post_id = post_id_from_imported_post_id("#{identifier}:#{attachment['entity_id']}")
        next unless user = User.find(user_id)
        next unless post = Post.find(post_id)

        begin
          new_raw = post.raw.dup
          upload, filename = find_upload(post, attachment)

          unless upload
            fail_count += 1
            next
          end

          upload_html = html_for_upload(upload, filename)
          new_raw = "#{new_raw}\n\n#{upload_html}" unless new_raw.include?(upload_html)

          if new_raw != post.raw
            PostRevisor.new(post).revise!(post.user, { raw: new_raw }, bypass_bump: true, edit_reason: "Import attachment from Drupal")
          else
            puts '', 'Skipped upload: already imported'
          end

          success_count += 1
        rescue => e
          puts e
        end
      end
    end
  end

  def create_permalinks
    puts '', 'creating permalinks...'

    Topic.listable_topics.find_each do |topic|
      begin
        tcf = topic.custom_fields
        if tcf && tcf['import_id']
          node_id = tcf['import_id'][/nid:(\d+)/, 1]
          slug = "/topic/#{node_id}"
          Permalink.create(url: slug, topic_id: topic.id)
        end
      rescue => e
        puts e.message
        puts "Permalink creation failed for id #{topic.id}"
      end
    end
  end

  def find_upload(post, attachment)
    uri = attachment['uri'][/public:\/\/upload\/(.+)/, 1]
    real_filename = CGI.unescapeHTML(uri)
    file = File.join(ATTACHMENT_DIR, real_filename)

    unless File.exist?(file)
      puts "Attachment file #{attachment['filename']} doesn't exist"

      tmpfile = "attachments_failed.txt"
      filename = File.join('/tmp/', tmpfile)
      File.open(filename, 'a') { |f|
        f.puts attachment['filename']
      }
    end

    upload = create_upload(post.user.id || -1, file, real_filename)

    if upload.nil? || upload.errors.any?
      puts "Upload not valid"
      puts upload.errors.inspect if upload
      return
    end

    [upload, real_filename]
  end

  def preprocess_raw(raw)
    return if raw.blank?
    # quotes on new lines
    raw.gsub!(/\[quote\](.+?)\[\/quote\]/im) { |quote|
      quote.gsub!(/\[quote\](.+?)\[\/quote\]/im) { "\n#{$1}\n" }
      quote.gsub!(/\n(.+?)/) { "\n> #{$1}" }
    }

    # [QUOTE=<username>]...[/QUOTE]
    raw.gsub!(/\[quote=([^;\]]+)\](.+?)\[\/quote\]/im) do
      username, quote = $1, $2
      "\n[quote=\"#{username}\"]\n#{quote}\n[/quote]\n"
    end

    raw.strip!
    raw
  end

  def postprocess_posts
    puts '', 'postprocessing posts'

    current = 0
    max = Post.count

    Post.find_each do |post|
      begin
        raw = post.raw
        new_raw = raw.dup

        # replace old topic to new topic links
        new_raw.gsub!(/https:\/\/site.com\/forum\/topic\/(\d+)/im) do
          post_id = post_id_from_imported_post_id("nid:#{$1}")
          next unless post_id
          topic = Post.find(post_id).topic
          "https://community.site.com/t/-/#{topic.id}"
        end

        # replace old comment to reply links
        new_raw.gsub!(/https:\/\/site.com\/comment\/(\d+)#comment-\d+/im) do
          post_id = post_id_from_imported_post_id("cid:#{$1}")
          next unless post_id
          post_ref = Post.find(post_id)
          "https://community.site.com/t/-/#{post_ref.topic_id}/#{post_ref.post_number}"
        end

        if raw != new_raw
          post.raw = new_raw
          post.save
        end
      rescue
        puts '', "Failed rewrite on post: #{post.id}"
      ensure
        print_status(current += 1, max)
      end
    end
  end

  def import_gravatars
    puts '', 'importing gravatars'
    current = 0
    max = User.count
    User.find_each do |user|
      begin
        user.create_user_avatar(user_id: user.id) unless user.user_avatar
        user.user_avatar.update_gravatar!
      rescue
        puts '', 'Failed avatar update on user #{user.id}'
      ensure
        print_status(current += 1, max)
      end
    end
  end

  def parse_datetime(time)
    DateTime.strptime(time, '%s')
  end

  def mysql_query(sql)
    @client.query(sql, cache_rows: true)
  end

end

if __FILE__ == $0
  ImportScripts::Drupal.new.perform
end
