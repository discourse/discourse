# encoding: utf-8
#
# Author: Erick Guan <fantasticfears@gmail.com>
#
# This script import the data from latest Discuz! X
# Should work among Discuz! X3.x
# This script is tested only on Simplified Chinese Discuz! X instances
# If you want to import data other than Simplified Chinese, email me.

require 'mysql2'
require File.expand_path(File.dirname(__FILE__) + "/base.rb")

class ImportScripts::DiscuzX < ImportScripts::Base

  DISCUZX_DB = "ultrax"
  DB_TABLE_PREFIX = 'pre_'
  BATCH_SIZE = 1000
  ORIGINAL_SITE_PREFIX = "oldsite.example.com/forums" # without http(s)://
  NEW_SITE_PREFIX      = "http://discourse.example.com"  # with http:// or https://

  # Set DISCUZX_BASE_DIR to the base directory of your discuz installation.
  DISCUZX_BASE_DIR      = '/var/www/discuz/upload'
  AVATAR_DIR            = '/uc_server/data/avatar'
  ATTACHMENT_DIR        = '/data/attachment/forum'
  AUTHORIZED_EXTENSIONS = ['jpg', 'jpeg', 'png', 'gif', 'zip', 'rar', 'pdf']

  def initialize
    super

    @client = Mysql2::Client.new(
      host: "localhost",
      username: "root",
      #password: "password",
      database: DISCUZX_DB
    )
    @first_post_id_by_topic_id = {}
  end

  def execute
    import_users
    import_categories
    import_posts
    import_private_messages
    import_attachments
  end

  # add the prefix to the table name
  def table_name(name = nil)
    DB_TABLE_PREFIX + name
  end

  # find which group members can be granted as admin
  def get_knowledge_about_group
    group_table = table_name 'common_usergroup'
    result = mysql_query(
      "SELECT groupid group_id, radminid role_id, type, grouptitle title
             FROM #{group_table};")
    @moderator_group_id = -1
    @admin_group_id = -1

    result.each do |group|
      role_id = group['role_id']
      group_id = group['group_id']
      case group['title'].strip
        when '管理员'
          @admin_admin_id = role_id
        when '超级版主'
          @moderator_admin_id = role_id
      end
    end
  end

  def import_users
    puts '', "creating users"

    get_knowledge_about_group

    sensitive_user_table = table_name 'ucenter_members'
    user_table = table_name 'common_member'
    profile_table = table_name 'common_member_profile'
    status_table = table_name 'common_member_status'
    total_count = mysql_query("SELECT count(*) count FROM #{user_table};").first['count']

    batches(BATCH_SIZE) do |offset|
      results = mysql_query(
        "SELECT u.uid id, u.username username, u.email email, u.adminid admin_id, su.regdate regdate, s.regip regip,
                    u.emailstatus email_confirmed, u.avatarstatus avatar_exists, p.site website, p.resideprovince	province,
                    p.residecity city, p.residedist country, p.residecommunity community, p.residesuite apartment,
                    p.bio bio, s.lastip last_visit_ip, s.lastvisit last_visit_time, s.lastpost last_posted_at,
                    s.lastsendmail last_emailed_at
               FROM #{user_table} u
               JOIN #{sensitive_user_table} su ON su.uid = u.uid
               JOIN #{profile_table} p ON p.uid = u.uid
               JOIN #{status_table} s ON s.uid = u.uid
              ORDER BY u.uid ASC
              LIMIT #{BATCH_SIZE}
             OFFSET #{offset};")

      break if results.size < 1

      next if all_records_exist? :users, users.map {|u| u["id"].to_i}

      create_users(results, total: total_count, offset: offset) do |user|
        { id: user['id'],
          email: user['email'],
          username: user['username'],
          name: user['username'],
          created_at: Time.zone.at(user['regdate']),
          registration_ip_address: user['regip'],
          ip_address: user['last_visit_ip'],
          last_seen_at: user['last_visit_time'],
          last_emailed_at: user['last_emailed_at'],
          last_posted_at: user['last_posted_at'],
          moderator: user['admin_id'] == @moderator_admin_id,
          admin: user['admin_id'] == @admin_admin_id,
          active: true,
          website: user['website'],
          bio_raw: user['bio'],
          location: "#{user['province']}#{user['city']}#{user['country']}#{user['community']}#{user['apartment']}",
          post_create_action: lambda do |newmember|
            if user['avatar_exists'] == 1 and newmember.uploaded_avatar_id.blank?
              path, filename = discuzx_avatar_fullpath(user['id'])
              if path
                begin
                  upload = create_upload(newmember.id, path, filename)
                  if upload.persisted?
                    newmember.import_mode = false
                    newmember.create_user_avatar
                    newmember.import_mode = true
                    newmember.user_avatar.update(custom_upload_id: upload.id)
                    newmember.update(uploaded_avatar_id: upload.id)
                  else
                    puts "Error: Upload did not persist!"
                  end
                rescue SystemCallError => err
                  puts "Could not import avatar: #{err.message}"
                end
              end
            end

            # we don't send email to the unconfirmed user
            newmember.update(email_digests: user['email_confirmed'] == 1) if newmember.email_digests
          end
        }
      end
    end
  end

  def import_categories
    puts '', "creating categories"

    forums_table = table_name 'forum_forum'
    forums_data_table = table_name 'forum_forumfield'

    results = mysql_query("
          SELECT f.fid id, f.fup parent_id, f.name, f.type type, f.status status, f.displayorder position,
                 d.description description
            FROM #{forums_table} f
            JOIN #{forums_data_table} d ON f.fid = d.fid
           ORDER BY parent_id ASC, id ASC
        ")

    max_position = Category.all.max_by(&:position).position
    create_categories(results) do |row|
      next if row['type'] == 'group' || row['status'].to_i == 3

      Category.all.max_by(&:position).position
      h = {
        id: row['id'],
        name: row['name'],
        description: row['description'],
        position: row['position'].to_i + max_position
      }
      if row['parent_id'].to_i > 0
        h[:parent_category_id] = category_id_from_imported_category_id(row['parent_id'])
      end
      h
    end
  end

  def import_posts
    puts "", "creating topics and posts"

    posts_table = table_name 'forum_post'
    topics_table = table_name 'forum_thread'

    total_count = mysql_query("SELECT count(*) count FROM #{posts_table}").first['count']

    batches(BATCH_SIZE) do |offset|
      results = mysql_query("
            SELECT p.pid id,
                   p.tid topic_id,
                   t.fid category_id,
                   t.subject title,
                   p.authorid user_id,
                   p.message raw,
                   p.dateline post_time,
                   p.first is_first_post,
                   p.invisible status
              FROM #{posts_table} p,
                   #{topics_table} t
             WHERE p.tid = t.tid
             ORDER BY id ASC, topic_id ASC
             LIMIT #{BATCH_SIZE}
            OFFSET #{offset};
          ")

      break if results.size < 1

      next if all_records_exist? :posts, results.map {|p| p["id"].to_i}

      create_posts(results, total: total_count, offset: offset) do |m|
        skip = false
        mapped = {}

        mapped[:id] = m['id']
        mapped[:user_id] = user_id_from_imported_user_id(m['user_id']) || -1
        mapped[:raw] = process_discuzx_post(m['raw'], m['id'])
        mapped[:created_at] = Time.zone.at(m['post_time'])

        if m['is_first_post'] == 1
          mapped[:category] = category_id_from_imported_category_id(m['category_id'])
          mapped[:title] = CGI.unescapeHTML(m['title'])
          @first_post_id_by_topic_id[m['topic_id']] = m['id']
        else
          parent = topic_lookup_from_imported_post_id(@first_post_id_by_topic_id[m['topic_id']])

          if parent
            mapped[:topic_id] = parent[:topic_id]
            post_id = post_id_from_imported_post_id(find_post_id_by_quote_number(m['raw']).to_i)
            if (post = Post.find_by(id: post_id))
              mapped[:reply_to_post_number] = post.post_number
            end
          else
            puts "Parent topic #{m['topic_id']} doesn't exist. Skipping #{m['id']}: #{m['title'][0..40]}"
            skip = true
          end
        end

        if [-5, -3, -1].include? m['status'] || mapped[:raw].blank?
          mapped[:post_create_action] = lambda do |post|
            PostDestroyer.new(Discourse.system_user, post).perform_delete
          end
        elsif m['status'] == -2# waiting for approve
          mapped[:post_create_action] = lambda do |post|
            PostAction.act(Discourse.system_user, post, 6, {take_action: false})
          end
        end

        skip ? nil : mapped
      end
    end
  end

  def import_private_messages
    puts '', 'creating private messages'

    pm_indexes = table_name 'ucenter_pm_indexes'
    pm_messages = table_name 'ucenter_pm_messages'
    total_count = mysql_query("SELECT count(*) count FROM #{pm_indexes}").first['count']

    batches(BATCH_SIZE) do |offset|
      results = mysql_query("
            SELECT pmid id, plid thread_id, authorid user_id, message, dateline created_at
              FROM #{pm_messages}_1
      UNION SELECT pmid id, plid thread_id, authorid user_id, message, dateline created_at
              FROM #{pm_messages}_2
      UNION SELECT pmid id, plid thread_id, authorid user_id, message, dateline created_at
              FROM #{pm_messages}_3
      UNION SELECT pmid id, plid thread_id, authorid user_id, message, dateline created_at
              FROM #{pm_messages}_4
      UNION SELECT pmid id, plid thread_id, authorid user_id, message, dateline created_at
              FROM #{pm_messages}_5
      UNION SELECT pmid id, plid thread_id, authorid user_id, message, dateline created_at
              FROM #{pm_messages}_6
      UNION SELECT pmid id, plid thread_id, authorid user_id, message, dateline created_at
              FROM #{pm_messages}_7
      UNION SELECT pmid id, plid thread_id, authorid user_id, message, dateline created_at
              FROM #{pm_messages}_8
      UNION SELECT pmid id, plid thread_id, authorid user_id, message, dateline created_at
              FROM #{pm_messages}_9
          ORDER BY thread_id ASC, id ASC
             LIMIT #{BATCH_SIZE}
            OFFSET #{offset};")

      break if results.size < 1

      next if all_records_exist? :posts, results.map {|m| "pm:#{m['id']}"}

      create_posts(results, total: total_count, offset: offset) do |m|
        skip = false
        mapped = {}

        mapped[:id] = "pm:#{m['id']}"
        mapped[:user_id] = user_id_from_imported_user_id(m['user_id']) || -1
        mapped[:raw] = process_discuzx_post(m['message'], m['id'])
        mapped[:created_at] = Time.zone.at(m['created_at'])
        thread_id = "pm_#{m['thread_id']}"

        if is_first_pm(m['id'], m['thread_id'])
          # find the title from list table
          pm_thread = mysql_query("
                SELECT plid thread_id, subject
                  FROM #{table_name 'ucenter_pm_lists'}
                 WHERE plid = #{m['thread_id']};").first
          mapped[:title] = pm_thread['subject']
          mapped[:archetype] = Archetype.private_message

          # Find the users who are part of this private message.
          import_user_ids = mysql_query("
                SELECT plid thread_id, uid user_id
                  FROM #{table_name 'ucenter_pm_members'}
                 WHERE plid = #{m['thread_id']};
              ").map {|r| r['user_id']}.uniq

          mapped[:target_usernames] = import_user_ids.map! do |import_user_id|
            import_user_id.to_s == m['user_id'].to_s ? nil : User.find_by(id: user_id_from_imported_user_id(import_user_id)).try(:username)
          end.compact

          if mapped[:target_usernames].empty? # pm with yourself?
            skip = true
            puts "Skipping pm:#{m['id']} due to no target"
          else
            @first_post_id_by_topic_id[thread_id] = mapped[:id]
          end
        else
          parent = topic_lookup_from_imported_post_id(@first_post_id_by_topic_id[thread_id])
          if parent
            mapped[:topic_id] = parent[:topic_id]
          else
            puts "Parent post pm thread:#{thread_id} doesn't exist. Skipping #{m["id"]}: #{m["message"][0..40]}"
            skip = true
          end
        end

        skip ? nil : mapped
      end

    end
  end

  # search for first pm id for the series of pm
  def is_first_pm(pm_id, thread_id)
    result = mysql_query("
          SELECT pmid id
            FROM #{table_name 'ucenter_pm_indexes'}
           WHERE plid = #{thread_id}
        ORDER BY id")
    result.first['id'].to_s == pm_id.to_s
  end

  def process_discuzx_post(raw, import_id)
    inline_image_regex = /\[img\]([\s\S]*?)\[\/img\]/
    s = raw.dup

    s.gsub!(inline_image_regex) do |d|
      matches = inline_image_regex.match(d)
      data = matches[1]

      upload, filename = upload_inline_image data
      upload ? html_for_upload(upload, filename) : nil
    end

    # Strip the quote
    # [quote] quotation includes the topic which is the same as reply to in Discourse
    # We get the pid to find the post number the post reply to. So it can be stripped
    s = s.gsub(/\[quote\][\s\S]*?\[\/quote\]/i, '').strip
    s = s.gsub(/\[b\]回复 \[url=forum.php\?mod=redirect&goto=findpost&pid=\d+&ptid=\d+\].* 的帖子\[\/url\]\[\/b\]/i, '').strip

    # Convert image bbcode
    s.gsub!(/\[img=(\d+),(\d+)\]([^\]]*)\[\/img\]/i, '<img width="\1" height="\2" src="\3">')

    # Remove the font, p and backcolor tag
    # Discourse doesn't support the font tag
    s.gsub!(/\[font=[^\]]*?\]/i, '')
    s.gsub!(/\[\/font\]/i, '')
    s.gsub!(/\[p=[^\]]*?\]/i, '')
    s.gsub!(/\[\/p\]/i, '')
    s.gsub!(/\[backcolor=[^\]]*?\]/i, '')
    s.gsub!(/\[\/backcolor\]/i, '')

    # Remove the size tag
    # I really have no idea what is this
    s.gsub!(/\[size=[^\]]*?\]/i, '')
    s.gsub!(/\[\/size\]/i, '')

    # Remove the color tag
    s.gsub!(/\[color=[^\]]*?\]/i, '')
    s.gsub!(/\[\/color\]/i, '')

    # Remove the hide tag
    s.gsub!(/\[\/?hide\]/i, '')

    # Remove the align tag
    # still don't know what it is
    s.gsub!(/\[align=[^\]]*?\]/i, '')
    s.gsub!(/\[\/align\]/i, "\n")

    # Convert code
    s.gsub!(/\[\/?code\]/i, "\n```\n")

    # The edit notice should be removed
    # example: 本帖最后由 Helloworld 于 2015-1-28 22:05 编辑
    s.gsub!(/\[i=s\] 本帖最后由[\s\S]*?编辑 \[\/i\]/, '')

    # Convert the custom smileys to emojis
    # `{:cry:}` to `:cry`
    s.gsub!(/\{(\:\S*?\:)\}/, '\1')

    # Replace internal forum links that aren't in the <!-- l --> format
    # convert list tags to ul and list=1 tags to ol
    # (basically, we're only missing list=a here...)
    s.gsub!(/\[list\](.*?)\[\/list:u\]/m, '[ul]\1[/ul]')
    s.gsub!(/\[list=1\](.*?)\[\/list:o\]/m, '[ol]\1[/ol]')
    # convert *-tags to li-tags so bbcode-to-md can do its magic on phpBB's lists:
    s.gsub!(/\[\*\](.*?)\[\/\*:m\]/, '[li]\1[/li]')

    # Discuz can create PM out of a post, which will generates like
    # [url=http://example.com/forum.php?mod=redirect&goto=findpost&pid=111&ptid=11][b]关于您在“主题名称”的帖子[/b][/url]
    s.gsub!(pm_url_regexp) do |discuzx_link|
      replace_internal_link(discuzx_link, $1)
    end

    # [url][b]text[/b][/url] to **[url]text[/url]**
    s.gsub!(/(\[url=[^\[\]]*?\])\[b\](\S*)\[\/b\](\[\/url\])/, '**\1\2\3**')

    s.gsub!(internal_url_regexp) do |discuzx_link|
      replace_internal_link(discuzx_link, $1)
    end

    # @someone without the url
    s.gsub!(/@\[url=[^\[\]]*?\](\S*)\[\/url\]/i, '@\1')

    s.strip
  end

  def replace_internal_link(discuzx_link, import_topic_id)
    results = mysql_query("SELECT pid
                             FROM #{table_name 'forum_post'}
                            WHERE tid = #{import_topic_id}
                         ORDER BY pid ASC
                            LIMIT 1")

    return discuzx_link unless results.size > 0

    linked_topic_id = results.first['pid']
    lookup = topic_lookup_from_imported_post_id(linked_topic_id)

    return discuzx_link unless lookup

    if (t = Topic.find_by(id: lookup[:topic_id]))
      "#{NEW_SITE_PREFIX}/t/#{t.slug}/#{t.id}"
    else
      discuzx_link
    end
  end

  def internal_url_regexp
    @internal_url_regexp ||= Regexp.new("http(?:s)?://#{ORIGINAL_SITE_PREFIX.gsub('.', '\.')}/forum\\.php\\?mod=viewthread&tid=(\\d+)(?:[^\\]\\[]*)")
  end

  def pm_url_regexp
    @pm_url_regexp ||= Regexp.new("http(?:s)?://#{ORIGINAL_SITE_PREFIX.gsub('.', '\.')}/forum\\.php\\?mod=redirect&goto=findpost&pid=\\d+&ptid=(\\d+)")
  end

  # This step is done separately because it can take multiple attempts to get right (because of
  # missing files, wrong paths, authorized extensions, etc.).
  def import_attachments
    setting = AUTHORIZED_EXTENSIONS.join('|')
    SiteSetting.authorized_extensions = setting if setting != SiteSetting.authorized_extensions

    attachment_regex = /\[attach\](\d+)\[\/attach\]/

    user = Discourse.system_user

    current_count = 0
    total_count = mysql_query("SELECT count(*) count FROM #{table_name 'forum_post'};").first['count']

    success_count = 0
    fail_count = 0

    puts '', "Importing attachments...", ''

    Post.find_each do |post|
      current_count += 1
      print_status current_count, total_count

      new_raw = post.raw.dup
      new_raw.gsub!(attachment_regex) do |s|
        matches = attachment_regex.match(s)
        attachment_id = matches[1]

        upload, filename = find_upload(user, post, attachment_id)
        unless upload
          fail_count += 1
          next
        end

        html_for_upload(upload, filename)
      end

      if new_raw != post.raw
        PostRevisor.new(post).revise!(post.user, { raw: new_raw }, { bypass_bump: true, edit_reason: '从 Discuz 中导入附件' })
      end

      success_count += 1
    end

    puts '', ''
    puts "succeeded: #{success_count}"
    puts "   failed: #{fail_count}" if fail_count > 0
    puts ''
  end

  # Create the full path to the discuz avatar specified from user id
  def discuzx_avatar_fullpath(user_id)
    padded_id = user_id.to_s.rjust(9, '0')

    part_1 = padded_id[0..2]
    part_2 = padded_id[3..4]
    part_3 = padded_id[5..6]
    part_4 = padded_id[-2..-1]
    file_name = "#{part_4}_avatar_big.jpg"

    return File.join(DISCUZX_BASE_DIR, AVATAR_DIR, part_1, part_2, part_3, file_name), file_name
  end

  # post id is in the quote block
  def find_post_id_by_quote_number(raw)
    s = raw.dup
    quote_reply = s.match(/\[quote\][\S\s]*pid=(\d+)[\S\s]*\[\/quote\]/)
    reply = s.match(/url=forum.php\?mod=redirect&goto=findpost&pid=(\d+)&ptid=\d+/)

    quote_reply ? quote_reply[1] : (reply ? reply[1] : nil)
  end

  # for some reason, discuz inlined some png file
  # the corresponding image stored is broken in a way
  def upload_inline_image(data)
    return unless data

    puts 'Creating inline image'

    encoded_photo = data['data:image/png;base64,'.length .. -1]
    if encoded_photo
      raw_file = Base64.decode64(encoded_photo)
    else
      puts 'Error parsed inline photo', data[0..20]
      return
    end

    real_filename = "#{SecureRandom.hex}.png"
    filename = Tempfile.new(['inline', '.png'])
    begin
      filename.binmode
      filename.write(raw_file)
      filename.rewind

      upload = create_upload(Discourse::SYSTEM_USER_ID, filename, real_filename)
    ensure
      filename.close rescue nil
      filename.unlink rescue nil
    end

    if upload.nil? || !upload.valid?
      puts "Upload not valid :("
      puts upload.errors.inspect if upload
      return nil
    end

    return upload, real_filename
  end

  # find the uploaded file and real name from the db
  def find_upload(user, post, upload_id)
    attachment_table = table_name 'forum_attachment'
    # search for table id
    sql = "SELECT a.pid post_id,
                  a.aid upload_id,
                  a.tableid table_id
             FROM #{attachment_table} a
            WHERE a.pid = #{post.custom_fields['import_id']}
              AND a.aid = #{upload_id};"
    results = mysql_query(sql)

    unless (meta_data = results.first)
      puts "Couldn't find forum_attachment record meta data for post.id = #{post.id}, import_id = #{post.custom_fields['import_id']}"
      return nil
    end

    # search for uploaded file meta data
    sql = "SELECT a.pid post_id,
                  a.aid upload_id,
                  a.tid topic_id,
                  a.uid user_id,
                  a.dateline uploaded_time,
                  a.filename real_filename,
                  a.attachment attachment_path,
                  a.remote is_remote,
                  a.description description,
                  a.isimage is_image,
                  a.thumb is_thumb
             FROM #{attachment_table}_#{meta_data['table_id']} a
            WHERE a.aid = #{upload_id};"
    results = mysql_query(sql)

    unless (row = results.first)
      puts "Couldn't find attachment record for post.id = #{post.id}, import_id = #{post.custom_fields['import_id']}"
      return nil
    end

    filename = File.join(DISCUZX_BASE_DIR, ATTACHMENT_DIR, row['attachment_path'])
    unless File.exists?(filename)
      puts "Attachment file doesn't exist: #{filename}"
      return nil
    end
    real_filename = row['real_filename']
    real_filename.prepend SecureRandom.hex if real_filename[0] == '.'
    upload = create_upload(user.id, filename, real_filename)

    if upload.nil? || !upload.valid?
      puts "Upload not valid :("
      puts upload.errors.inspect if upload
      return nil
    end

    return upload, real_filename
  rescue Mysql2::Error => e
    puts "SQL Error"
    puts e.message
    puts sql
    return nil
  end

  def mysql_query(sql)
    @client.query(sql, cache_rows: false)
  end
end

ImportScripts::DiscuzX.new.perform
