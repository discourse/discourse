# frozen_string_literal: true

# Use http://tatiyants.com/pev/#/plans/new if you want to optimize a query

task "import:ensure_consistency" => :environment do
  log "Starting..."

  insert_post_timings
  insert_post_replies
  insert_topic_users
  insert_topic_views
  insert_user_actions
  insert_user_options
  insert_user_stats
  insert_user_visits
  insert_draft_sequences

  update_user_stats
  update_posts
  update_topics
  update_categories
  update_users
  update_groups
  update_tag_stats
  create_category_definitions

  log "Done!"
end

MS_SPEND_CREATING_POST ||= 5000

def insert_post_timings
  log "Inserting post timings..."

  DB.exec <<-SQL
    INSERT INTO post_timings (topic_id, post_number, user_id, msecs)
         SELECT topic_id, post_number, user_id, #{MS_SPEND_CREATING_POST}
           FROM posts
          WHERE user_id > 0
    ON CONFLICT DO NOTHING
  SQL
end

def insert_post_replies
  log "Inserting post replies..."

  DB.exec <<-SQL
    INSERT INTO post_replies (post_id, reply_id, created_at, updated_at)
         SELECT p2.id, p.id, p.created_at, p.created_at
           FROM posts p
     INNER JOIN posts p2 ON p2.post_number = p.reply_to_post_number AND p2.topic_id = p.topic_id
    ON CONFLICT DO NOTHING
  SQL
end

def insert_topic_users
  log "Inserting topic users..."

  DB.exec <<-SQL
    INSERT INTO topic_users (user_id, topic_id, posted, last_read_post_number, highest_seen_post_number, first_visited_at, last_visited_at, total_msecs_viewed)
         SELECT user_id, topic_id, 't' , MAX(post_number), MAX(post_number), MIN(created_at), MAX(created_at), COUNT(id) * #{MS_SPEND_CREATING_POST}
           FROM posts
          WHERE user_id > 0
       GROUP BY user_id, topic_id
    ON CONFLICT DO NOTHING
  SQL
end

def insert_topic_views
  log "Inserting topic views..."

  DB.exec <<-SQL
    WITH X AS (
          SELECT topic_id, user_id, DATE(p.created_at) posted_at
            FROM posts p
            JOIN users u ON u.id = p.user_id
           WHERE user_id > 0
        GROUP BY topic_id, user_id, DATE(p.created_at)
    )
    INSERT INTO topic_views (topic_id, user_id, viewed_at, ip_address)
         SELECT X.topic_id, X.user_id, X.posted_at, ip_address
           FROM X
           JOIN users u ON u.id = X.user_id
          WHERE ip_address IS NOT NULL
    ON CONFLICT DO NOTHING
  SQL
end

def insert_user_actions
  log "Inserting user actions for NEW_TOPIC = 4..."

  DB.exec <<-SQL
    INSERT INTO user_actions (action_type, user_id, target_topic_id, target_post_id, acting_user_id, created_at, updated_at)
         SELECT 4, p.user_id, topic_id, p.id, p.user_id, p.created_at, p.created_at
           FROM posts p
           JOIN topics t ON t.id = p.topic_id
          WHERE post_number = 1
            AND archetype <> 'private_message'
            AND p.deleted_at IS NULL
            AND t.deleted_at IS NULL
    ON CONFLICT DO NOTHING
  SQL

  log "Inserting user actions for REPLY = 5..."

  DB.exec <<-SQL
    INSERT INTO user_actions (action_type, user_id, target_topic_id, target_post_id, acting_user_id, created_at, updated_at)
         SELECT 5, p.user_id, topic_id, p.id, p.user_id, p.created_at, p.created_at
           FROM posts p
           JOIN topics t ON t.id = p.topic_id
          WHERE post_number > 1
            AND archetype <> 'private_message'
            AND p.deleted_at IS NULL
            AND t.deleted_at IS NULL
    ON CONFLICT DO NOTHING
  SQL

  log "Inserting user actions for RESPONSE = 6..."

  DB.exec <<-SQL
    INSERT INTO user_actions (action_type, user_id, target_topic_id, target_post_id, acting_user_id, created_at, updated_at)
         SELECT 6, p.user_id, p.topic_id, p.id, p2.user_id, p.created_at, p.created_at
           FROM posts p
           JOIN topics t ON t.id = p.topic_id
     INNER JOIN posts p2 ON p2.post_number = p.reply_to_post_number
          WHERE p.post_number > 1
            AND archetype <> 'private_message'
            AND p.deleted_at IS NULL
            AND t.deleted_at IS NULL
            AND p2.topic_id = p.topic_id
            AND p2.user_id <> p.user_id
    ON CONFLICT DO NOTHING
  SQL

  # TODO:
  #  - NEW_PRIVATE_MESSAGE
  #  - GOT_PRIVATE_MESSAGE
end

def insert_user_options
  log "Inserting user options..."

  DB.exec <<-SQL
    INSERT INTO user_options (
                  user_id,
                  mailing_list_mode,
                  mailing_list_mode_frequency,
                  email_level,
                  email_messages_level,
                  email_previous_replies,
                  email_in_reply_to,
                  email_digests,
                  digest_after_minutes,
                  include_tl0_in_digests,
                  automatically_unpin_topics,
                  enable_quoting,
                  external_links_in_new_tab,
                  dynamic_favicon,
                  new_topic_duration_minutes,
                  auto_track_topics_after_msecs,
                  notification_level_when_replying,
                  like_notification_frequency
                )
             SELECT u.id
                  , #{SiteSetting.default_email_mailing_list_mode}
                  , #{SiteSetting.default_email_mailing_list_mode_frequency}
                  , #{SiteSetting.default_email_level}
                  , #{SiteSetting.default_email_messages_level}
                  , #{SiteSetting.default_email_previous_replies}
                  , #{SiteSetting.default_email_in_reply_to}
                  , #{SiteSetting.default_email_digest_frequency.to_i > 0}
                  , #{SiteSetting.default_email_digest_frequency}
                  , #{SiteSetting.default_include_tl0_in_digests}
                  , #{SiteSetting.default_topics_automatic_unpin}
                  , #{SiteSetting.default_other_enable_quoting}
                  , #{SiteSetting.default_other_external_links_in_new_tab}
                  , #{SiteSetting.default_other_dynamic_favicon}
                  , #{SiteSetting.default_other_new_topic_duration_minutes}
                  , #{SiteSetting.default_other_auto_track_topics_after_msecs}
                  , #{SiteSetting.default_other_notification_level_when_replying}
                  , #{SiteSetting.default_other_like_notification_frequency}
               FROM users u
          LEFT JOIN user_options uo ON uo.user_id = u.id
              WHERE uo.user_id IS NULL
  SQL
end

def insert_user_stats
  log "Inserting user stats..."

  DB.exec <<-SQL
    INSERT INTO user_stats (user_id, new_since)
         SELECT id, created_at
           FROM users
    ON CONFLICT DO NOTHING
  SQL
end

def insert_user_visits
  log "Inserting user visits..."

  DB.exec <<-SQL
    INSERT INTO user_visits (user_id, visited_at, posts_read)
         SELECT user_id, DATE(created_at), COUNT(*)
           FROM posts
          WHERE user_id > 0
       GROUP BY user_id, DATE(created_at)
    ON CONFLICT DO NOTHING
  SQL
end

def insert_draft_sequences
  log "Inserting draft sequences..."

  DB.exec <<-SQL
    INSERT INTO draft_sequences (user_id, draft_key, sequence)
         SELECT user_id, CONCAT('#{Draft::EXISTING_TOPIC}', id), 1
           FROM topics
          WHERE user_id > 0
            AND archetype = 'regular'
    ON CONFLICT DO NOTHING
  SQL
end

def update_user_stats
  log "Updating user stats..."

  # TODO: topic_count is counting all topics you replied in as if you started the topic.
  # TODO: post_count is counting first posts.
  # TODO: topic_reply_count is never used, and is counting PMs here.
  DB.exec <<-SQL
    WITH X AS (
      SELECT p.user_id
           , COUNT(p.id) posts
           , COUNT(DISTINCT p.topic_id) topics
           , MIN(p.created_at) min_created_at
           , COALESCE(COUNT(DISTINCT DATE(p.created_at)), 0) days
           , COALESCE((
              SELECT COUNT(*)
                FROM topics
               WHERE id IN (
                SELECT topic_id
                  FROM posts p2
                  JOIN topics t2 ON t2.id = p2.topic_id
                 WHERE p2.deleted_at IS NULL
                   AND p2.post_type = 1
                   AND NOT COALESCE(p2.hidden, 't')
                   AND p2.user_id <> t2.user_id
                   AND p2.user_id = p.user_id
                )
              ), 0) topic_replies
        FROM posts p
        JOIN topics t ON t.id = p.topic_id
       WHERE p.deleted_at IS NULL
         AND NOT COALESCE(p.hidden, 't')
         AND p.post_type = 1
         AND t.deleted_at IS NULL
         AND COALESCE(t.visible, 't')
         AND t.archetype <> 'private_message'
         AND p.user_id > 0
    GROUP BY p.user_id
    )
    UPDATE user_stats
       SET post_count = X.posts
         , posts_read_count = X.posts
         , time_read = X.posts * 5
         , topic_count = X.topics
         , topics_entered = X.topics
         , first_post_created_at = X.min_created_at
         , days_visited = X.days
         , topic_reply_count = X.topic_replies
      FROM X
     WHERE user_stats.user_id = X.user_id
       AND (post_count <> X.posts
         OR posts_read_count <> X.posts
         OR time_read <> X.posts * 5
         OR topic_count <> X.topics
         OR topics_entered <> X.topics
         OR COALESCE(first_post_created_at, '1970-01-01') <> X.min_created_at
         OR days_visited <> X.days
         OR topic_reply_count <> X.topic_replies)
  SQL
end

def update_posts
  log "Updating posts..."

  DB.exec <<-SQL
    WITH Y AS (
      SELECT post_id, COUNT(*) replies FROM post_replies GROUP BY post_id
    )
    UPDATE posts
       SET reply_count = Y.replies
      FROM Y
     WHERE posts.id = Y.post_id
       AND reply_count <> Y.replies
  SQL

  # -- TODO: ensure this is how this works!
  # WITH X AS (
  #   SELECT pr.post_id, p.user_id
  #     FROM post_replies pr
  #     JOIN posts p ON p.id = pr.reply_id
  # )
  # UPDATE posts
  #    SET reply_to_user_id = X.user_id
  #   FROM X
  #  WHERE id = X.post_id
  #    AND COALESCE(reply_to_user_id, -9999) <> X.user_id
end

def update_topics
  log "Updating topics..."

  DB.exec <<-SQL
    WITH X AS (
      SELECT topic_id
           , COUNT(*) posts
           , MAX(created_at) last_post_date
           , COALESCE(SUM(word_count), 0) words
           , COALESCE(SUM(reply_count), 0) replies
           , (  SELECT user_id
                  FROM posts
                 WHERE NOT hidden
                   AND deleted_at IS NULL
                   AND topic_id = p.topic_id
              ORDER BY post_number DESC
                 LIMIT 1) last_poster
        FROM posts p
       WHERE NOT hidden
         AND deleted_at IS NULL
    GROUP BY topic_id
  )
  UPDATE topics
     SET posts_count = X.posts
       , last_posted_at = X.last_post_date
       , bumped_at = X.last_post_date
       , word_count = X.words
       , reply_count = X.replies
       , last_post_user_id = X.last_poster
    FROM X
   WHERE id = X.topic_id
     AND (posts_count <> X.posts
       OR COALESCE(last_posted_at, '1970-01-01') <> X.last_post_date
       OR bumped_at <> X.last_post_date
       OR COALESCE(word_count, -1) <> X.words
       OR COALESCE(reply_count, -1) <> X.replies
       OR COALESCE(last_post_user_id, -9999) <> X.last_poster)
  SQL
end

def update_categories
  log "Updating categories..."

  DB.exec <<-SQL
    WITH X AS (
        SELECT category_id
             , MAX(p.id) post_id
             , MAX(t.id) topic_id
             , COUNT(p.id) posts
             , COUNT(DISTINCT p.topic_id) topics
          FROM posts p
          JOIN topics t ON t.id = p.topic_id
         WHERE p.deleted_at IS NULL
           AND t.deleted_at IS NULL
           AND NOT p.hidden
           AND t.visible
      GROUP BY category_id
    )
    UPDATE categories
       SET latest_post_id = X.post_id
         , latest_topic_id = X.topic_id
         , post_count = X.posts
         , topic_count = X.topics
      FROM X
     WHERE id = X.category_id
       AND (COALESCE(latest_post_id, -1) <> X.post_id
         OR COALESCE(latest_topic_id, -1) <> X.topic_id
         OR post_count <> X.posts
         OR topic_count <> X.topics)
  SQL
end

def update_users
  log "Updating users..."

  DB.exec(<<~SQL, Archetype.private_message)
    WITH X AS (
        SELECT p.user_id
             , MIN(p.created_at) min_created_at
             , MAX(p.created_at) max_created_at
          FROM posts p
          JOIN topics t ON t.id = p.topic_id AND t.archetype <> ?
         WHERE deleted_at IS NULL
      GROUP BY user_id
    )
    UPDATE users
       SET first_seen_at  = X.min_created_at
         , last_seen_at   = X.max_created_at
         , last_posted_at = X.max_created_at
      FROM X
     WHERE id = X.user_id
       AND (COALESCE(first_seen_at, '1970-01-01')  <> X.min_created_at
         OR COALESCE(last_seen_at, '1970-01-01')   <> X.max_created_at
         OR COALESCE(last_posted_at, '1970-01-01') <> X.max_created_at)
  SQL
end

def update_groups
  log "Updating groups..."

  DB.exec <<-SQL
    WITH X AS (
        SELECT group_id, COUNT(*) count
          FROM group_users
      GROUP BY group_id
    )
    UPDATE groups
       SET user_count = X.count
      FROM X
     WHERE id = X.group_id
       AND user_count <> X.count
  SQL
end

def update_tag_stats
  Tag.ensure_consistency!
end

def create_category_definitions
  log "Creating category definitions"
  Category.ensure_consistency!
end

def log(message)
  puts "[#{DateTime.now.strftime("%Y-%m-%d %H:%M:%S")}] #{message}"
end

task "import:create_phpbb_permalinks" => :environment do
  log 'Creating Permalinks...'

  # /[^\/]+\/.*-t(\d+).html/
  SiteSetting.permalink_normalizations = '/[^\/]+\/.*-t(\d+).html/thread/\1'

  Topic.listable_topics.find_each do |topic|
    tcf = topic.custom_fields
    if tcf && tcf["import_id"]
      Permalink.create(url: "thread/#{tcf["import_id"]}", topic_id: topic.id) rescue nil
    end
  end

  log "Done!"
end

task "import:remap_old_phpbb_permalinks" => :environment do
  log 'Remapping Permalinks...'

  i = 0
  Post.where("raw LIKE ?", "%discussions.example.com%").each do |p|
    begin
      new_raw = p.raw.dup
      # \((https?:\/\/discussions\.example\.com\/\S*-t\d+.html)\)
      new_raw.gsub!(/\((https?:\/\/discussions\.example\.com\/\S*-t\d+.html)\)/) do
        normalized_url = Permalink.normalize_url($1)
        permalink = Permalink.find_by_url(normalized_url) rescue nil
        if permalink && permalink.target_url
          "(#{permalink.target_url})"
        else
          "(#{$1})"
        end
      end

      if new_raw != p.raw
        p.revise(Discourse.system_user, { raw: new_raw }, bypass_bump: true, skip_revision: true)
        putc "."
        i += 1
      end
    rescue
      # skip
    end
  end

  log "Done! #{i} posts remapped."
end

task "import:create_vbulletin_permalinks" => :environment do
  log 'Creating Permalinks...'

  # /showthread.php\?t=(\d+).*/
  SiteSetting.permalink_normalizations = '/showthread.php\?t=(\d+).*/showthread.php?t=\1'

  Topic.listable_topics.find_each do |topic|
    tcf = topic.custom_fields
    if tcf && tcf["import_id"]
      Permalink.create(url: "showthread.php?t=#{tcf["import_id"]}", topic_id: topic.id) rescue nil
    end
  end

  Category.find_each do |cat|
    ccf = cat.custom_fields
    if ccf && ccf["import_id"]
      Permalink.create(url: "forumdisplay.php?f=#{ccf["import_id"]}", category_id: cat.id) rescue nil
    end
  end

  log "Done!"
end

desc 'Import existing exported file'
task 'import:file', [:file_name] => [:environment] do |_, args|
  require "import_export"

  ImportExport.import(args[:file_name])
  puts "", "Done", ""
end
