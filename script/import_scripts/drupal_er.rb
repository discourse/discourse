require 'nokogiri'

require "mysql2"
require File.expand_path(File.dirname(__FILE__) + "/base.rb")
require File.expand_path(File.dirname(__FILE__) + "/drupal.rb")


# Edit the constants and initialize method for your import data.

class ImportScripts::DrupalER < ImportScripts::Drupal

  DRUPAL_FILES_DIR = ENV['DRUPAL_FILES_DIR']


  def execute

    # site_settings = {
    #   # Basic Setup
    #   enable_badges: false,
    #   # Login
    #   invite_only: true,
    #   login_required: true,
    #   # Posting
    #   allow_duplicate_topic_titles: true,
    #   allow_html_tables: true,
    #   suppress_reply_directly_below: false,
    #   suppress_reply_directly_above: false,
    #   # Email
    #   disable_emails: true,
    #   # Plugins
    #   discourse_narrative_bot_enabled: false
    # }
    # site_settings.each { |key, value| SiteSetting.set(key, value) }


    # if Rails.env.development?
    #   # User.where.not("email = 'admin@example.com' or id = -1 or id = -2").delete_all
    #   # UserCustomField.delete_all
    #   Category.delete_all
    #   CategoryCustomField.delete_all
    #   Topic.delete_all
    #   TopicCustomField.delete_all
    #   Post.delete_all
    #   PostCustomField.delete_all
    #   Permalink.delete_all
    # end


    # import_users
    # import_categories
    # import_topics
    # import_replies
    # import_likes
    # import_tags
    # create_permalinks
    # normalize_urls
    post_process_posts


    # Reset "New" topics counter for all users.
    # User.find_each {|u| u.user_stat.update_column(:new_since, Time.now) }

    # Reset "Unread" topics counter for all users.
    # Topic.exec_sql("UPDATE topic_users tu SET highest_seen_post_number = t.highest_post_number , last_read_post_number = highest_post_number FROM topics t WHERE t.id = tu.topic_id")

    # begin
    #   create_admin(email: 'admin@example.com', username: UserNameSuggester.suggest('admin'))
    # rescue => e
    #   puts '', "Failed to create admin user"
    #   puts e.message
    # end
  end


  def import_users
    puts '', 'creating users...'

    sql = <<-SQL
      SELECT u.uid id, u.name, u.mail email, u.pass, u.created, fb.field_bio_value bio_raw, fa.field_agegroup_value agegroup,
        bi.field_i_m_based_in_value location, fu.field_facebook_url_url facebook_url, tu.field_twitter_url_url twitter_url,
        lu.field_linkedin_url_url linkedin_url, wu.field_website_url_url website_url, fc.field_first_contact_value first_contact,
        co.field_consent_opencare_value consent_opencare_date, fm.filename profile_picture
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
        LEFT JOIN file_managed AS fm on u.picture = fm.fid
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
    create_users(@client.query(sql)) do |row|
      next if UserCustomField.exists?(name: 'import_id', value: row['id'])

      {
        id: row['id'],
        username: row['name'].parameterize.underscore,
        email: (row['email'].present? ? row['email'] : "#{rand(36**12).to_s(36)}@example.com"),
        created_at: Time.zone.at(row['created']),
        bio_raw: row['bio_raw'],
        website: row['website_url'],
        location: row['location'],
        active: true,
        custom_fields: {
          agegroup: row['agegroup'],
          facebook_url: row['facebook_url'],
          twitter_url: row['twitter_url'],
          linkedin_url: row['linkedin_url'],
          first_contact: row['first_contact'],
          consent_opencare: row['consent_opencare_date'],
          import_id: row['id'],
          import_pass: row['pass']
        },
        post_create_action: proc do |user|
          if row['profile_picture'].present? && user.uploaded_avatar_id.blank?
            begin
              path = "#{DRUPAL_FILES_DIR}/pictures/#{row['profile_picture']}"
              upload = create_upload(user.id, path, row['profile_picture'])
              if upload.present? && upload.persisted?
                user.import_mode = false
                user.create_user_avatar
                user.user_avatar.update(custom_upload_id: upload.id)
                user.update(uploaded_avatar_id: upload.id)
                user.refresh_avatar
              else
                puts 'Upload failed!'
              end
            rescue SystemCallError => err
              puts "Could not import avatar: #{err.message}"
            end
          end
        end
      }
    end

    # Remove automatically suggested names.
    # User.update_all(name: nil)
  end


  def import_topics
    puts '', 'creating topics...'

    sql = <<-SQL
      SELECT
      # General
        n.nid nid,
        n.uid uid,
        n.status status,
        n.created created,
        n.changed changed,
        tf.title_field_value title,
        db.body_value content,
        n.type type,
      # Document
        df.field_document_file_description doc_description,
        df.field_document_file_fid doc_fid,
      # Journal
        fc.field_client_value j_client,
        fce.field_client_s_email_value j_client_email,
        fm.field_manager_target_id j_manager_uid,
        fas.field_activity_state_value j_activity_state,
        fa.field_attention_value j_attention,
        ff.field_file_fid j_file_fid,
        ff.field_file_description j_file_description,
      # Events
        fd.field_date_value e_date1,
        fd.field_date_value2 e_date2,
        fd.field_date_timezone e_timezone,
        fou.field_offsite_url_value e_url,
      # Category
        om.gid category_nid,
        cref.og_challenge_ref_target_id challenge_category_nid
      FROM node AS n
      # General
        LEFT JOIN field_data_title_field AS tf on n.nid = tf.entity_id
        LEFT JOIN field_data_body AS db on n.nid = db.entity_id
      # Document
        LEFT JOIN field_data_field_document_file AS df on n.nid = df.entity_id
		  # Journal
        LEFT JOIN field_data_field_client AS fc on n.nid = fc.entity_id
        LEFT JOIN field_data_field_client_s_email AS fce on n.nid = fce.entity_id
        LEFT JOIN field_data_field_manager AS fm on n.nid = fm.entity_id
        LEFT JOIN field_data_field_activity_state AS fas on n.nid = fas.entity_id
        LEFT JOIN field_data_field_attention AS fa on n.nid = fa.entity_id
        LEFT JOIN field_data_field_file AS ff on n.nid = ff.entity_id
      # Event
        LEFT JOIN field_data_field_date AS fd on n.nid = fd.entity_id
        LEFT JOIN field_data_field_offsite_url AS fou on n.nid = fou.entity_id
      # Category
        LEFT JOIN (
                  SELECT id, etid, gid
                  FROM og_membership
                  WHERE og_membership.entity_type = 'node' AND og_membership.group_type = 'node'
              ) om on n.nid = om.etid
        LEFT JOIN field_data_og_challenge_ref AS cref on n.nid = cref.entity_id
      WHERE
        n.type IN('challenge_response', 'post', 'wiki', 'document', 'group', 'minisite_page', 'page', 'task', 'infopage',
                  'event', 'document', 'journal')
      ORDER BY om.id ASC
    SQL

    results = @client.query(sql, cache_rows: false)

    create_posts(results) do |row|

      content = row['content'] || ''

      if row['type'] == 'event'
        content+= "\nDate: #{row['e_date1'].gsub!(/T/, ' ')} - #{row['e_date2'].gsub!(/T/, ' ')}, #{row['e_timezone']} Time." if row['e_date1'].present?
        content+= "\nURL: #{row['e_url']}" if row['e_url'].present?
      elsif row['type'] == 'document'
        content+= "\n\nfile_fid:#{row['doc_fid']} - #{row['doc_description']}"
      elsif row['type'] == 'journal'
        content+= "\nClient: #{row['j_client']}" if row['j_client'].present?

        content+= "\nEmail: #{row['j_client_email']}" if row['j_client_email'].present?

        if row['j_manager_uid'].present? && (cf = UserCustomField.find_by(name: 'import_id', value: row['j_manager_uid']))
          content+= "\nUser: @#{cf.user.username}"
        end

        content+= "\nActivity State: #{row['j_activity_state']}" if row['j_activity_state'].present?

        attention_values = {
          1 => 'none',
          2 => 'awareness',
          3 => 'awareness and monitoring',
          4 => 'management (light)',
          5 => 'management (normal)',
          6 => 'management (attentive)',
          9 => 'management (CRISIS MODE)'
        }
        content+= "\nAttention: #{attention_values[row['j_attention'].to_i]}" if row['j_attention'].present?

        content+= "\nFile: file_fid:#{row['j_file_fid']} - #{row['j_file_description']}" if row['j_file_fid'].present?
      end

      category_nid = (row['type'] == 'challenge_response') ? row['challenge_category_nid'] : row['category_nid']

      {
        id: "nid:#{row['nid']}",
        user_id: user_id_from_imported_user_id(row['uid']) || -1,
        title: row['title'].try(:strip) || '--title missing--',
        raw: content,
        created_at: Time.zone.at(row['created']),
        updated_at: Time.zone.at(row['changed']),
        custom_fields: {import_id: "nid:#{row['nid']}"},
        category: CategoryCustomField.find_by(name: 'import_id', value: category_nid).try(:category).try(:name)
        # visible: row['status'].to_i == 0 ? false : true
        # pinned_at: row['sticky'].to_i == 1 ? Time.zone.at(row['created']) : nil,
      }
    end
  end


  def import_replies
    puts '', "creating replies in topics..."

    total_count = @client.query("
        SELECT COUNT(*) count
          FROM comment c,
               node n
         WHERE n.nid = c.nid
           AND c.status = 1
           AND n.type IN('challenge_response', 'post', 'wiki', 'document', 'group', 'minisite_page', 'page', 'task', 'infopage', 'event', 'document', 'journal');").first['count']

    batch_size = 1000

    batches(batch_size) do |offset|
      results = @client.query("
        SELECT c.cid, c.pid, c.nid, c.uid, c.created, c.subject,
               f.comment_body_value body, SUBSTRING(c.thread, 1, (LENGTH(c.thread) - 1)) torder
          FROM comment c,
               field_data_comment_body f,
               node n
         WHERE c.cid = f.entity_id
           AND n.nid = c.nid
           AND c.status = 1
           AND n.type IN('challenge_response', 'post', 'wiki', 'document', 'group', 'minisite_page', 'page', 'task', 'infopage', 'event', 'document', 'journal')
          ORDER BY torder ASC
         LIMIT #{batch_size}
        OFFSET #{offset};
      ", cache_rows: false)

      break if results.size < 1

      next if all_records_exist? :posts, results.map { |p| "cid:#{p['cid']}" }

      create_posts(results, total: total_count, offset: offset) do |row|
        topic_mapping = topic_lookup_from_imported_post_id("nid:#{row['nid']}")
        if topic_mapping && (topic_id = topic_mapping[:topic_id])
          content = if ActionView::Base.full_sanitizer.sanitize(row['body']).start_with?(row['subject'])
                      row['body']
                    else
                      "<b>#{row['subject']}</b>\n\n"+row['body']
                    end
          h = {
            id: "cid:#{row['cid']}",
            topic_id: topic_id,
            user_id: user_id_from_imported_user_id(row['uid']) || -1,
            raw: content,
            created_at: Time.zone.at(row['created']),
            custom_fields: {import_id: "cid:#{row['cid']}"}
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


  def import_likes
    puts "\nimporting likes..."

    sql = "select uid user_id, entity_type post_type, entity_id post_id, timestamp created_at FROM votingapi_vote"
    results = @client.query(sql, cache_rows: false)

    puts "loading unique id map"
    existing_map = {}
    PostCustomField.where(name: 'import_id').pluck(:post_id, :value).each do |post_id, import_id|
      existing_map[import_id] = post_id
    end


    puts "loading data into temp table"
    PostAction.exec_sql("create temp table like_data(user_id int, post_id int, created_at timestamp without time zone)")
    PostAction.transaction do
      results.each do |result|

        result["user_id"] = user_id_from_imported_user_id(result["user_id"].to_s)
        result["post_id"] = if result['post_type'] == 'comment'
                              existing_map["cid:#{result["post_id"]}"]
                            else
                              existing_map["nid:#{result["post_id"]}"]
                            end

        next unless result["user_id"] && result["post_id"]

        PostAction.exec_sql("INSERT INTO like_data VALUES (:user_id,:post_id,:created_at)",
                            user_id: result["user_id"],
                            post_id: result["post_id"],
                            created_at: Time.zone.at(result["created_at"])
        )

      end
    end

    puts "creating missing post actions"
    PostAction.exec_sql <<-SQL

    INSERT INTO post_actions (post_id, user_id, post_action_type_id, created_at, updated_at)
             SELECT l.post_id, l.user_id, 2, l.created_at, l.created_at FROM like_data l
             LEFT JOIN post_actions a ON a.post_id = l.post_id AND l.user_id = a.user_id AND a.post_action_type_id = 2
             WHERE a.id IS NULL
             ON CONFLICT DO NOTHING
    SQL

    puts "creating missing user actions"
    UserAction.exec_sql <<-SQL
    INSERT INTO user_actions (user_id, action_type, target_topic_id, target_post_id, acting_user_id, created_at, updated_at)
             SELECT pa.user_id, 1, p.topic_id, p.id, pa.user_id, pa.created_at, pa.created_at
             FROM post_actions pa
             JOIN posts p ON p.id = pa.post_id
             LEFT JOIN user_actions ua ON action_type = 1 AND ua.target_post_id = pa.post_id AND ua.user_id = pa.user_id

             WHERE ua.id IS NULL AND pa.post_action_type_id = 2
             ON CONFLICT DO NOTHING
    SQL


    # reverse action
    UserAction.exec_sql <<-SQL
    INSERT INTO user_actions (user_id, action_type, target_topic_id, target_post_id, acting_user_id, created_at, updated_at)
             SELECT p.user_id, 2, p.topic_id, p.id, pa.user_id, pa.created_at, pa.created_at
             FROM post_actions pa
             JOIN posts p ON p.id = pa.post_id
             LEFT JOIN user_actions ua ON action_type = 2 AND ua.target_post_id = pa.post_id AND
                ua.acting_user_id = pa.user_id AND ua.user_id = p.user_id

             WHERE ua.id IS NULL AND pa.post_action_type_id = 2
             ON CONFLICT DO NOTHING
    SQL
    puts "updating like counts on posts"

    Post.exec_sql <<-SQL
        UPDATE posts SET like_count = coalesce(cnt,0)
                  FROM (
        SELECT post_id, count(*) cnt
        FROM post_actions
        WHERE post_action_type_id = 2 AND deleted_at IS NULL
        GROUP BY post_id
    ) x
    WHERE posts.like_count <> x.cnt AND posts.id = x.post_id

    SQL

    puts "updating like counts on topics"

    Post.exec_sql <<-SQL
      UPDATE topics SET like_count = coalesce(cnt,0)
      FROM (
        SELECT topic_id, sum(like_count) cnt
        FROM posts
        WHERE deleted_at IS NULL
        GROUP BY topic_id
      ) x
      WHERE topics.like_count <> x.cnt AND topics.id = x.topic_id

    SQL
  end


  def post_process_posts
    puts '', 'processing posts...'

    Post.find_each do |post|
      next if post.raw.nil?
      puts "processing post: ##{post.id}..."

      doc = Nokogiri::HTML.fragment(post.raw)

      # # NOTE: The order is important.
      # # 1. Replace media divs.
      # doc.css('div.media_embed').each { |node| node.replace node.inner_html }
      #
      # # 2. Replace youtube and vimeo iframes with onebox links.
      # doc.css('iframe').each do |node|
      #   if 'youtube.com'.in?(node['src']) || 'player.vimeo.com'.in?(node['src'])
      #     u = URI.parse(node['src'])
      #     u.scheme = 'https'
      #     node.replace u.to_s
      #   end
      # end
      #
      # # 3. Replace twitter blockquotes with onebox links.
      # doc.css('blockquote.twitter-tweet').each { |node| node.replace node.css('a').last['href'] }


      # # 4. Upload images.
      # doc.css('img').each do |img|
      #   if img['src'].present?
      #     if '/sites/edgeryders.eu/files'.in?(img['src']) || '/sites/default/files'.in?(img['src'])
      #       filename = img['src'].gsub(/.*(#{Regexp.quote('/sites/edgeryders.eu/files')}|#{Regexp.quote('/sites/default/files')})/, DRUPAL_FILES_DIR).gsub(/\?.*/, '')
      #       # Decode URL characters.
      #       filename = URI.decode_www_form_component(filename)
      #
      #       if File.exists?(filename)
      #         upload = create_upload(post.user_id, filename, File.basename(filename))
      #         if upload.nil? || upload.invalid?
      #           puts "Upload not valid :(  #{filename}"
      #           puts upload.errors.inspect if upload
      #         else
      #           img.replace "\n" + embedded_image_html(upload)
      #         end
      #       else
      #         puts "Image doesn't exist: #{filename}"
      #       end
      #     end
      #   end
      # end

      # 5. Remap URLs.
      doc.css('a').each do |link|
        next unless link['href'].present?

        if link['href'].match(/^\/(?:en\/)?comment\/([0-9]*)/)
          # Comment URLs
          cid = link['href'].match(/comment\/([0-9]*)/).try(:captures).try(:first)
          if cf = PostCustomField.find_by(name: 'import_id', value: "cid:#{cid}")
            link.attributes['href'].value = cf.post.url
          end
        elsif pl = Permalink.find_by_url(link['href'].sub(/^\//, '').sub(/^en\//, ''))
          # Permalinks
          link.attributes['href'].value = pl.target_url if pl.target_url.present?
        elsif uid = link['href'].match(/^\/(?:en\/)?user\/([0-9]*)/).try(:captures).try(:first)
          # User URLs
          if uf = UserCustomField.find_by(name: 'import_id', value: "#{uid}")
            link.attributes['href'].value = "/u/#{uf.user.username}"
          end
        elsif uid = link['href'].match(/^\/(?:en\/)?users\/(.*)/).try(:captures).try(:first)
          # User URLs
          if u = User.find_by_username(uid.underscore)
            link.attributes['href'].value = "/u/#{u.username}"
          end
        end
      end

      post.raw = doc.to_s


      # # HTML cleanup.
      # post.raw.gsub!('<meta charset="utf-8">', '')
      # post.raw.gsub!('<script async src="//platform.twitter.com/widgets.js" charset="utf-8"></script>', '')
      # post.raw.gsub!(' dir="ltr"', '')
      # post.raw.gsub!('<p>&nbsp;</p>', '')
      # post.raw.gsub!('<li>&nbsp;</li>', '')
      # # Remove html attributes in opening tags.
      # post.raw.gsub!(/<ul.*?>/, '<ul>')
      # post.raw.gsub!(/<span.*?>/, '<span>')
      # post.raw.gsub!(/<li.*?>/, '<li>')
      # # Normalize line breaks.
      # post.raw.gsub!(/\r/, "\n")
      # post.raw.gsub!(%r~<br\s*\/?>~, "\n")
      # # Remove paragraphs.
      # post.raw.gsub!(/<p.*?>/, '')
      # post.raw.gsub!('</p>', "\n\n")
      # # Remove line breaks.
      # post.raw.gsub!(/<li>\n{1,}/, '<li>')
      # # NOTE: Do not use \s to also match non-breaking spaces.
      # # See: https://stackoverflow.com/questions/3473817/gsub-ascii-code-characters-from-a-string-in-ruby
      # post.raw.gsub!(/\n[[:space:]]*<\/li>/, '</li>')
      # # Replace three or more consecutive linebreaks with two.
      # post.raw.gsub!(/\n{3,}/, "\n\n")
      # # Remove trailing tabs.
      # post.raw.gsub!(/\n\t{1,}/, "\n")
      # # Remove trailing whitespaces.
      # post.raw.gsub!(/\n[[:space:]]{1,}/, "\n")
      # # Escape hash signs at the beginning of a line to prevent markdown interpreting it as a headline.
      # post.raw.gsub!(/\n#/, "\n\\#")
      # # Escape hash signs after a whitespace to prevent markdown messing up the html formatting.
      # post.raw.gsub!(/[[:space:]]#/, " \\#")

      post.save!(validate: false)
    end

  end


  def normalize_urls
    puts '', 'normalize urls...'

    # Normalize URLs
    ActiveRecord::Base.connection.execute("UPDATE posts SET raw = replace(raw, '=\"http://edgeryders.eu/', '=\"/')")
    ActiveRecord::Base.connection.execute("UPDATE posts SET raw = replace(raw, '=\"https://edgeryders.eu/', '=\"/')")
  end


  def create_permalinks
    puts '', 'creating permalinks...'

    Topic.find_each do |topic|
      if topic_nid = topic.ordered_posts.first.custom_fields['import_id']

        topic_nid = topic_nid.first if topic_nid.is_a?(Array)

        if result = @client.query("SELECT source, alias FROM url_alias WHERE source LIKE 'node/#{topic_nid.gsub(/nid:/, '')}'", cache_rows: false).first
          Permalink.create(url: result['alias'], topic_id: topic.id) rescue nil
          Permalink.create(url: result['source'], topic_id: topic.id) rescue nil
        end
      end
    end

    # Redirects
    results = @client.query("SELECT source, redirect FROM redirect WHERE redirect LIKE 'node%'", cache_rows: false)
    results.each do |row|
      nid = row['redirect'].gsub(/node\//, '')
      if cf = PostCustomField.find_by(name: 'import_id', value: "nid:#{nid}")
        Permalink.create(url: row['source'], topic_id: cf.topic_id) rescue nil
      end
    end
  end


  def import_categories
    puts '', 'creating categories...'

    sql = <<-SQL
      SELECT
        n.nid nid,
        tf.title_field_value name,
        db.body_value description
      FROM node AS n
        LEFT JOIN field_data_title_field AS tf on n.nid = tf.entity_id
        LEFT JOIN field_data_body AS db on n.nid = db.entity_id
      WHERE
        n.type IN('group', 'challenge')
      ORDER BY n.nid DESC
    SQL
    results = @client.query(sql, cache_rows: false)

    create_categories(results) do |c|
      {
        id: c['nid'],
        name: "#{c['name']} ##{c['nid']}",
        description: c['description']
      }
    end

    Category.find_each do |c|
      next if c.topic_id.blank?
      post = c.topic.ordered_posts.first
      post.raw = c.description
      post.save!(validate: false)
      # Update the category and topic excerpts.
      revisor = PostRevisor.new(post, post.topic)
      revisor.revise_topic
    end

  end


  def import_tags
    puts '', 'creating tags...'

    Topic.find_each do |topic|
      if topic_nid = topic.ordered_posts.first.custom_fields['import_id']
        topic_nid = topic_nid.first if topic_nid.is_a?(Array)
        topic_nid = topic_nid.gsub(/nid:/, '')

        results = @client.query("SELECT type FROM node WHERE nid = #{topic_nid}", cache_rows: false)
        topic_type = results.first['type']

        sql = "SELECT td.name
               FROM field_data_field_topics AS ft
               INNER JOIN taxonomy_term_data AS td ON ft.field_topics_tid = td.tid
               WHERE ft.entity_type = 'node' AND ft.entity_id = #{topic_nid}"
        results = @client.query(sql, cache_rows: false)

        DiscourseTagging.tag_topic_by_names(topic, Guardian.new(Discourse.system_user), [topic_type] + results.map { |row| row['name'] }, append: true)
      end
    end
  end


end

if __FILE__==$0
  ImportScripts::DrupalER.new.perform
end


