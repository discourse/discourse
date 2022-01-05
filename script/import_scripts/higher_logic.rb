# frozen_string_literal: true

require "mysql2"
require File.expand_path(File.dirname(__FILE__) + "/base.rb")

class ImportScripts::HigherLogic < ImportScripts::Base

  HIGHERLOGIC_DB = "higherlogic"
  BATCH_SIZE = 1000
  ATTACHMENT_DIR = "/shared/import/data/attachments"

  def initialize
    super

    @client = Mysql2::Client.new(
      host: "localhost",
      username: "root",
      database: HIGHERLOGIC_DB
    )
  end

  def execute
    import_groups
    import_users
    import_group_users
    import_categories
    import_posts
    import_attachments
  end

  def import_groups
    puts '', 'importing groups'

    groups = mysql_query <<-SQL
        SELECT CommunityKey, CommunityName
          FROM Community
      ORDER BY CommunityName
    SQL

    create_groups(groups) do |group|
      {
        id: group['CommunityKey'],
        name: group['CommunityName']
      }
    end
  end

  def import_users
    puts '', 'importing users'
    total_count = mysql_query("SELECT count(*) FROM Contact").first["count"]

    batches(BATCH_SIZE) do |offset|
      results = mysql_query <<-SQL
        SELECT ContactKey, FirstName, LastName, EmailAddress, HLAdminFlag, UserStatus, CreatedOn, Birthday, Bio
          FROM Contact
         LIMIT #{BATCH_SIZE}
        OFFSET #{offset}
      SQL

      break if results.size < 1

      next if all_records_exist? :users, results.map { |u| u['ContactKey'] }

      create_users(results, total: total_count, offset: offset) do |user|
        next if user['EmailAddress'].blank?
        {
          id: user['ContactKey'],
          email: user['EmailAddress'],
          name: "#{user['FirstName']} #{user['LastName']}",
          created_at: user['CreatedOn'] == nil ? 0 : Time.zone.at(user['CreatedOn']),
          bio_raw: user['Bio'],
          active: user['UserStatus'] == "Active",
          admin: user['HLAdminFlag'] == 1
        }
      end
    end
  end

  def import_group_users
    puts '', 'importing group users'

    group_users = mysql_query(<<-SQL
      SELECT CommunityKey, ContactKey
        FROM CommunityMember
    SQL
    ).to_a

    group_users.each do |row|
      next unless user_id = user_id_from_imported_user_id(row['ContactKey'])
      next unless group_id = group_id_from_imported_group_id(row['CommunityKey'])
      puts '', '.'

      GroupUser.find_or_create_by(user_id: user_id, group_id: group_id)
    end
  end

  def import_categories
    puts '', 'importing categories'

    categories = mysql_query <<-SQL
      SELECT DiscussionKey, DiscussionName
        FROM Discussion
    SQL

    create_categories(categories) do |category|
      {
        id: category['DiscussionKey'],
        name: category['DiscussionName']
      }
    end
  end

  def import_posts
    puts '', 'importing topics and posts'
    total_count = mysql_query("SELECT count(*) FROM DiscussionPost").first["count"]

    batches(BATCH_SIZE) do |offset|
      results = mysql_query <<-SQL
          SELECT MessageKey,
                 ParentMessageKey,
                 Subject,
                 ContactKey,
                 DiscussionKey,
                 PinnedFlag,
                 Body,
                 CreatedOn
            FROM DiscussionPost
           WHERE CreatedOn > '2020-01-01 00:00:00'
           LIMIT #{BATCH_SIZE}
          OFFSET #{offset}
      SQL

      break if results.size < 1
      next if all_records_exist? :posts, results.map { |p| p['MessageKey'] }

      create_posts(results, total: total_count, offset: offset) do |post|
        raw = preprocess_raw(post['Body'])
        mapped = {
          id: post['MessageKey'],
          user_id: user_id_from_imported_user_id(post['ContactKey']),
          raw: raw,
          created_at: Time.zone.at(post['CreatedOn']),
        }

        if post['ParentMessageKey'].nil?
          mapped[:category] = category_id_from_imported_category_id(post['DiscussionKey']).to_i
          mapped[:title] = CGI.unescapeHTML(post['Subject'])
          mapped[:pinned] = post['PinnedFlag'] == 1
        else
          topic = topic_lookup_from_imported_post_id(post['ParentMessageKey'])

          if topic.present?
            mapped[:topic_id] = topic[:topic_id]
          else
            puts "Parent post #{post['ParentMessageKey']} doesn't exist. Skipping."
            next
          end
        end

        mapped
      end
    end
  end

  def import_attachments
    puts '', 'importing attachments'

    count = 0

    total_attachments = mysql_query(<<-SQL
      SELECT COUNT(*) count
        FROM LibraryEntryFile l
        JOIN DiscussionPost p ON p.AttachmentDocumentKey = l.DocumentKey
       WHERE p.CreatedOn > '2020-01-01 00:00:00'
    SQL
    ).first['count']

    batches(BATCH_SIZE) do |offset|
      attachments = mysql_query(<<-SQL
           SELECT l.VersionName,
                  l.FileExtension,
                  p.MessageKey
             FROM LibraryEntryFile l
        LEFT JOIN DiscussionPost p ON p.AttachmentDocumentKey = l.DocumentKey
            WHERE p.CreatedOn > '2020-01-01 00:00:00'
            LIMIT #{BATCH_SIZE}
           OFFSET #{offset}
      SQL
      ).to_a

      break if attachments.empty?

      attachments.each do |a|
        print_status(count += 1, total_attachments, get_start_time("attachments"))
        original_filename = "#{a['VersionName']}.#{a['FileExtension']}"
        path = File.join(ATTACHMENT_DIR, original_filename)

        if File.exist?(path)
          if post = Post.find(post_id_from_imported_post_id(a['MessageKey']))
            filename = File.basename(original_filename)
            upload = create_upload(post.user.id, path, filename)

            if upload&.persisted?
              html = html_for_upload(upload, filename)

              post.raw << "\n\n" << html
              post.save!
              PostUpload.create!(post: post, upload: upload) unless PostUpload.where(post: post, upload: upload).exists?
            end
          end
        end
      end
    end
  end

  def preprocess_raw(body)
    raw = body.dup

    # trim off any post text beyond ---- to remove email threading
    raw = raw.slice(0..(raw.index('------'))) || raw

    raw = HtmlToMarkdown.new(raw).to_markdown
    raw
  end

  def mysql_query(sql)
    @client.query(sql, cache_rows: false)
  end
end

ImportScripts::HigherLogic.new.perform
