# frozen_string_literal: true

class PostMover
  attr_reader :original_topic, :destination_topic, :user, :post_ids

  def self.move_types
    @move_types ||= Enum.new(:new_topic, :existing_topic)
  end

  # options:
  # freeze_original: :boolean  - if true, the original topic will be frozen but not deleted and posts will be "copied" to topic
  def initialize(original_topic, user, post_ids, move_to_pm: false, options: {})
    @original_topic = original_topic
    @original_topic_title = original_topic.title
    @user = user
    @post_ids = post_ids
    # For now we store a copy of post_ids. If `freeze_original` is present, we will have new post_ids.
    # When we create the new posts, we will pluck out post_ids out of this and replace with updated ids.
    @post_ids_after_move = post_ids
    @move_to_pm = move_to_pm
    @options = options
  end

  def to_topic(id, participants: nil, chronological_order: false)
    @move_type = PostMover.move_types[:existing_topic]
    @creating_new_topic = false
    @chronological_order = chronological_order

    topic = Topic.find_by_id(id)
    if topic.archetype != @original_topic.archetype &&
         [@original_topic.archetype, topic.archetype].include?(Archetype.private_message)
      raise Discourse::InvalidParameters
    end

    Topic.transaction { move_posts_to topic }
    add_allowed_users(participants) if participants.present? && @move_to_pm
    enqueue_jobs(topic)
    topic
  end

  def to_new_topic(title, category_id = nil, tags = nil)
    @move_type = PostMover.move_types[:new_topic]
    @creating_new_topic = true

    post = Post.find_by(id: post_ids.first)
    raise Discourse::InvalidParameters unless post
    archetype = @move_to_pm ? Archetype.private_message : Archetype.default

    topic =
      Topic.transaction do
        new_topic =
          Topic.create!(
            user: post.user,
            title: title,
            category_id: category_id,
            created_at: post.created_at,
            archetype: archetype,
          )
        DiscourseTagging.tag_topic_by_names(new_topic, Guardian.new(user), tags)
        move_posts_to new_topic
        watch_new_topic
        update_topic_excerpt new_topic
        new_topic
      end
    enqueue_jobs(topic)
    topic
  end

  private

  def update_topic_excerpt(topic)
    topic.update_excerpt(topic.first_post.excerpt_for_topic)
  end

  def move_posts_to(topic)
    Guardian.new(user).ensure_can_see! topic
    @destination_topic = topic

    # when a topic contains some posts after moving posts to another topic we shouldn't close it
    # two types of posts should prevent a topic from closing:
    #   1. regular posts
    #   2. almost all whispers
    # we should only exclude whispers with action_code: 'split_topic'
    # because we use such whispers as a small-action posts when moving posts to the secret message
    # (in this case we don't want everyone to see that posts were moved, that's why we use whispers)
    original_topic_posts_count =
      @original_topic
        .posts
        .where(
          "post_type = ? or (post_type = ? and action_code != 'split_topic')",
          Post.types[:regular],
          Post.types[:whisper],
        )
        .count
    moving_all_posts = original_topic_posts_count == posts.length

    @first_post_number_moved =
      posts.first.is_first_post? ? posts[1]&.post_number : posts.first.post_number

    if @options[:freeze_original] # in this case we need to add the moderator post after the last copied post
      from_posts = @original_topic.ordered_posts.where("post_number > ?", posts.last.post_number)
      shift_post_numbers(from_posts) if !moving_all_posts

      @first_post_number_moved = posts.last.post_number + 1
    end

    move_each_post
    handle_moved_references

    create_moderator_post_in_original_topic
    update_statistics
    update_user_actions
    update_last_post_stats
    update_upload_security_status
    update_bookmarks

    close_topic_and_schedule_deletion if moving_all_posts

    destination_topic.reload
    DiscourseEvent.trigger(
      :posts_moved,
      destination_topic_id: destination_topic.id,
      original_topic_id: original_topic.id,
    )
    destination_topic
  end

  def handle_moved_references
    move_incoming_emails
    move_notifications
    update_reply_counts
    update_quotes
    move_first_post_replies
    delete_post_replies
    copy_shifted_post_timings_to_temp
    delete_invalid_post_timings
    copy_shifted_post_timings_from_temp
    move_post_timings
    copy_first_post_timings
    copy_topic_users
  end

  def move_each_post
    if @chronological_order
      move_each_post_chronological
    else
      move_each_post_sequential
    end
  end

  def move_each_post_sequential
    max_post_number = destination_topic.max_post_number + 1

    @post_creator = nil
    @move_map = {}
    @reply_count = {}
    posts.each_with_index do |post, offset|
      @move_map[post.post_number] = offset + max_post_number

      if post.reply_to_post_number.present?
        @reply_count[post.reply_to_post_number] = (@reply_count[post.reply_to_post_number] || 0) + 1
      end
    end

    posts.each do |post|
      metadata = movement_metadata(post, new_post_number: @move_map[post.post_number])
      new_post = post.is_first_post? ? create_first_post(post) : move(post)

      store_movement(metadata, new_post)

      if @move_to_pm && !destination_topic.topic_allowed_users.exists?(user_id: post.user_id)
        destination_topic.topic_allowed_users.create!(user_id: post.user_id)
      end
    end
  end

  def move_each_post_chronological
    destination_posts = destination_topic.ordered_posts.with_deleted

    # drops posts from destination_topic until it finds one that was created after posts.first
    min_created_at = posts.first.created_at
    moved_posts = destination_posts.drop_while { |post| post.created_at <= min_created_at }

    # if no post in destination_topic was created after posts.first it's equal to sequential
    if moved_posts.empty?
      initial_post_number = destination_topic.max_post_number + 1
    else
      initial_post_number = moved_posts.first.post_number
    end

    last_index = 0
    posts.each do |post|
      while last_index < moved_posts.length && moved_posts[last_index].created_at <= post.created_at
        last_index += 1
      end

      moved_posts.insert(last_index, post)
    end

    @post_creator = nil
    @move_map = {}
    @shift_map = {}
    @reply_count = {}
    next_post_number = initial_post_number
    moved_posts.each do |post|
      if post.topic_id == destination_topic.id
        # avoid shifting to a lower post number
        next_post_number = post.post_number if post.post_number > next_post_number

        @shift_map[post.post_number] = next_post_number
      else
        @move_map[post.post_number] = next_post_number

        if post.reply_to_post_number.present?
          @reply_count[post.reply_to_post_number] = (@reply_count[post.reply_to_post_number] || 0) +
            1
        end
      end

      next_post_number += 1
    end

    moved_posts.reverse_each do |post|
      if post.topic_id == destination_topic.id
        metadata = movement_metadata(post, new_post_number: @shift_map[post.post_number])
        new_post = move_same_topic(post)
      else
        metadata = movement_metadata(post, new_post_number: @move_map[post.post_number])
        new_post = post.is_first_post? ? create_first_post(post) : move(post)

        if @move_to_pm && !destination_topic.topic_allowed_users.exists?(user_id: post.user_id)
          destination_topic.topic_allowed_users.create!(user_id: post.user_id)
        end
      end

      store_movement(metadata, new_post)
    end

    # change topic owner if there's a new first post
    destination_topic.update_column(:user_id, posts.first.user_id) if initial_post_number == 1
  end

  def create_first_post(post)
    @post_creator =
      PostCreator.new(
        post.user,
        raw: post.raw,
        topic_id: destination_topic.id,
        acting_user: user,
        cook_method: post.cook_method,
        via_email: post.via_email,
        raw_email: post.raw_email,
        skip_validations: true,
        created_at: post.created_at,
        guardian: Guardian.new(user),
        skip_jobs: true,
      )
    new_post = @post_creator.create!

    move_email_logs(post, new_post)

    PostAction.copy(post, new_post)

    PostRevision.copy(post, new_post)

    attrs_to_update = {
      reply_count: @reply_count[1] || 0,
      version: post.version,
      public_version: post.public_version,
    }

    if new_post.post_number != @move_map[post.post_number]
      attrs_to_update[:post_number] = @move_map[post.post_number]
      attrs_to_update[:sort_order] = @move_map[post.post_number]
    end

    new_post.update_columns(attrs_to_update)
    new_post.custom_fields = post.custom_fields
    new_post.save_custom_fields

    # When freezing original, ensure the notification generated points
    # to the newly created post, not the old OP
    if @options[:freeze_original]
      @post_ids_after_move =
        @post_ids_after_move.map { |post_id| post_id == post.id ? new_post.id : post_id }
    end

    DiscourseEvent.trigger(:first_post_moved, new_post, post)
    DiscourseEvent.trigger(:post_moved, new_post, original_topic.id)

    # we don't want to keep the old topic's OP bookmarked when we are
    # moving it into a new topic
    Bookmark.where(bookmarkable: post).update_all(bookmarkable_id: new_post.id)

    new_post
  end

  def move(post)
    update = {
      reply_count: @reply_count[post.post_number] || 0,
      post_number: @move_map[post.post_number],
      reply_to_post_number: @move_map[post.reply_to_post_number],
      topic_id: destination_topic.id,
      sort_order: @move_map[post.post_number],
      baked_version: nil,
    }

    update[:reply_to_user_id] = nil unless @move_map[post.reply_to_post_number]

    moved_post =
      if @options[:freeze_original]
        post.dup
      else
        post
      end

    moved_post.attributes = update
    moved_post.disable_rate_limits! if @options[:freeze_original]
    moved_post.save(validate: false)

    if moved_post.id != post.id
      @post_ids_after_move =
        @post_ids_after_move.map { |post_id| post_id == post.id ? moved_post.id : post_id }
    end

    DiscourseEvent.trigger(:post_moved, moved_post, original_topic.id)

    # Move any links from the post to the new topic
    moved_post.topic_links.update_all(topic_id: destination_topic.id)

    moved_post
  end

  def move_same_topic(post)
    update = {
      post_number: @shift_map[post.post_number],
      sort_order: @shift_map[post.post_number],
      baked_version: nil,
    }

    if @shift_map[post.reply_to_post_number]
      update[:reply_to_post_number] = @shift_map[post.reply_to_post_number]
    end

    post.attributes = update
    post.save(validate: false)

    post
  end

  def movement_metadata(post, new_post_number: nil)
    {
      old_topic_id: post.topic_id,
      old_post_id: post.id,
      old_post_number: post.post_number,
      post_user_id: post.user_id,
      new_topic_id: destination_topic.id,
      new_post_number: new_post_number,
      new_topic_title: destination_topic.title,
    }
  end

  def store_movement(metadata, new_post)
    metadata[:new_post_id] = new_post.id
    metadata[:now] = Time.zone.now
    metadata[:created_new_topic] = @creating_new_topic
    metadata[:old_topic_title] = @original_topic_title
    metadata[:user_id] = @user.id

    DB.exec(<<~SQL, metadata)
      INSERT INTO moved_posts(old_topic_id, old_topic_title, old_post_id, old_post_number, post_user_id, user_id, new_topic_id, new_topic_title, new_post_id, new_post_number, created_new_topic, created_at, updated_at)
      VALUES (:old_topic_id, :old_topic_title, :old_post_id, :old_post_number, :post_user_id, :user_id, :new_topic_id, :new_topic_title, :new_post_id, :new_post_number, :created_new_topic, :now, :now)
    SQL
  end

  def shift_post_numbers(from_posts)
    from_posts.reverse_each { |post| post.update_columns(post_number: post.post_number + 1) }
  end

  def move_incoming_emails
    DB.exec <<~SQL
      UPDATE incoming_emails ie
      SET topic_id = mp.new_topic_id,
          post_id = mp.new_post_id
      FROM moved_posts mp
      WHERE ie.topic_id = mp.old_topic_id AND ie.post_id = mp.old_post_id
        AND mp.old_topic_id <> mp.new_topic_id
    SQL
  end

  def move_email_logs(old_post, new_post)
    EmailLog.where(post_id: old_post.id).update_all(post_id: new_post.id)
  end

  def move_notifications
    DB.exec <<~SQL
      UPDATE notifications n
      SET topic_id  = mp.new_topic_id,
        post_number = mp.new_post_number,
        data        = (data :: JSONB ||
          jsonb_strip_nulls(
              jsonb_build_object(
                  'topic_title', CASE WHEN data :: JSONB ->> 'topic_title' IS NULL
                                        THEN NULL
                                      ELSE mp.new_topic_title END
                )
            )) :: JSON
      FROM moved_posts mp
      WHERE n.topic_id = mp.old_topic_id AND n.post_number = mp.old_post_number
        AND n.notification_type <> #{Notification.types[:watching_first_post]}
    SQL
  end

  def update_reply_counts
    DB.exec <<~SQL
      UPDATE posts p
      SET reply_count = GREATEST(0, reply_count - x.moved_reply_count)
      FROM (
        SELECT r.post_id, mp.new_topic_id, COUNT(1) AS moved_reply_count
        FROM moved_posts mp
               JOIN post_replies r ON (mp.old_post_id = r.reply_post_id)
        GROUP BY r.post_id, mp.new_topic_id
      ) x
      WHERE x.post_id = p.id AND x.new_topic_id <> p.topic_id
    SQL
  end

  def update_quotes
    DB.exec <<~SQL
      UPDATE posts p
      SET raw = REPLACE(p.raw,
                        ', post:' || mp.old_post_number || ', topic:' || mp.old_topic_id,
                        ', post:' || mp.new_post_number || ', topic:' || mp.new_topic_id),
          baked_version = NULL
      FROM moved_posts mp, quoted_posts qp
      WHERE p.id = qp.post_id AND mp.old_post_id = qp.quoted_post_id
    SQL
  end

  def move_first_post_replies
    DB.exec <<~SQL
      UPDATE post_replies pr
      SET post_id = mp.new_post_id
      FROM moved_posts mp
      WHERE mp.old_post_id <> mp.new_post_id AND pr.post_id = mp.old_post_id AND
        EXISTS (SELECT 1 FROM moved_posts mr WHERE mr.new_post_id = pr.reply_post_id)
    SQL
  end

  def delete_post_replies
    DB.exec <<~SQL
      DELETE FROM post_replies pr USING moved_posts mp
      WHERE (SELECT topic_id FROM posts WHERE id = pr.post_id) <>
            (SELECT topic_id FROM posts WHERE id = pr.reply_post_id)
        AND (pr.reply_post_id = mp.old_post_id OR pr.post_id = mp.old_post_id)
    SQL
  end

  def copy_shifted_post_timings_to_temp
    DB.exec("DROP TABLE IF EXISTS temp_post_timings") if Rails.env.test?

    # copy post_timings for shifted posts to a temp table using the new_post_number
    # they'll be copied back after delete_invalid_post_timings makes room for them
    DB.exec(<<~SQL, post_ids: @post_ids_after_move)
      CREATE TEMPORARY TABLE temp_post_timings ON COMMIT DROP
        AS (
          SELECT pt.topic_id, mp.new_post_number as post_number, pt.user_id, pt.msecs
          FROM post_timings pt
          JOIN moved_posts mp
            ON mp.old_topic_id = pt.topic_id
              AND mp.old_post_number = pt.post_number
              AND mp.old_topic_id = mp.new_topic_id
        )
    SQL
  end

  def copy_shifted_post_timings_from_temp
    DB.exec <<~SQL
      INSERT INTO post_timings (topic_id, user_id, post_number, msecs)
      SELECT DISTINCT topic_id, user_id, post_number, msecs FROM temp_post_timings
    SQL
  end

  def copy_first_post_timings
    DB.exec(<<~SQL, post_ids: @post_ids_after_move)
      INSERT INTO post_timings (topic_id, user_id, post_number, msecs)
      SELECT mp.new_topic_id, pt.user_id, mp.new_post_number, pt.msecs
      FROM post_timings pt
      JOIN moved_posts mp ON (pt.topic_id = mp.old_topic_id AND pt.post_number = mp.old_post_number)
      WHERE mp.old_post_id <> mp.new_post_id
        AND mp.old_post_id IN (:post_ids)
      ON CONFLICT (topic_id, post_number, user_id) DO UPDATE
        SET msecs = GREATEST(post_timings.msecs, excluded.msecs)
    SQL
  end

  def delete_invalid_post_timings
    DB.exec <<~SQL
      DELETE
      FROM post_timings pt
      USING moved_posts mp
      WHERE pt.topic_id = mp.new_topic_id
        AND pt.post_number = mp.new_post_number
    SQL
  end

  def move_post_timings
    DB.exec(<<~SQL, post_ids: @post_ids_after_move)
      UPDATE post_timings pt
      SET topic_id    = mp.new_topic_id,
          post_number = mp.new_post_number
      FROM moved_posts mp
      WHERE pt.topic_id = mp.old_topic_id
        AND pt.post_number = mp.old_post_number
        AND mp.old_post_id = mp.new_post_id
        AND mp.old_topic_id <> mp.new_topic_id
        AND mp.new_post_id IN (:post_ids)
    SQL
  end

  def copy_topic_users
    params = {
      old_topic_id: original_topic.id,
      new_topic_id: destination_topic.id,
      old_highest_post_number: destination_topic.highest_post_number,
      old_highest_staff_post_number: destination_topic.highest_staff_post_number,
    }

    DB.exec(<<~SQL, params)
      INSERT INTO topic_users(user_id, topic_id, posted, last_read_post_number,
                              last_emailed_post_number, first_visited_at, last_visited_at, notification_level,
                              notifications_changed_at, notifications_reason_id)
      SELECT tu.user_id,
             :new_topic_id                               AS topic_id,
               EXISTS(
                 SELECT 1
                 FROM posts p
                 WHERE p.topic_id = :new_topic_id
                   AND p.user_id = tu.user_id
                 LIMIT 1
               )                                         AS posted,
             (
               SELECT MAX(lr.new_post_number)
               FROM moved_posts lr
               WHERE lr.old_topic_id = tu.topic_id
                 AND lr.old_post_number <= tu.last_read_post_number
                 AND lr.old_topic_id <> lr.new_topic_id
             )                                           AS last_read_post_number,
             (
               SELECT MAX(le.new_post_number)
               FROM moved_posts le
               WHERE le.old_topic_id = tu.topic_id
                 AND le.old_post_number <= tu.last_emailed_post_number
                 AND le.old_topic_id <> le.new_topic_id
             )                                           AS last_emailed_post_number,
             GREATEST(tu.first_visited_at, t.created_at) AS first_visited_at,
             GREATEST(tu.last_visited_at, t.created_at)  AS last_visited_at,
             tu.notification_level,
             tu.notifications_changed_at,
             tu.notifications_reason_id
      FROM topic_users tu
           JOIN topics t ON (t.id = :new_topic_id)
      WHERE tu.topic_id = :old_topic_id
        AND GREATEST(
                tu.last_read_post_number,
                tu.last_emailed_post_number
              ) >= (SELECT MIN(mp.old_post_number) FROM moved_posts mp WHERE mp.old_topic_id <> mp.new_topic_id)
      ON CONFLICT (topic_id, user_id) DO UPDATE
        SET posted                   = excluded.posted,
            last_read_post_number    = CASE
                                         WHEN topic_users.last_read_post_number = :old_highest_staff_post_number OR (
                                             :old_highest_post_number < :old_highest_staff_post_number
                                             AND topic_users.last_read_post_number = :old_highest_post_number
                                             AND NOT EXISTS(SELECT 1
                                                            FROM users u
                                                            WHERE u.id = topic_users.user_id
                                                              AND (admin OR moderator))
                                           ) THEN
                                           GREATEST(topic_users.last_read_post_number,
                                                    excluded.last_read_post_number)
                                         ELSE topic_users.last_read_post_number END,
            last_emailed_post_number = CASE
                                         WHEN topic_users.last_emailed_post_number = :old_highest_staff_post_number OR (
                                             :old_highest_post_number < :old_highest_staff_post_number
                                             AND topic_users.last_emailed_post_number = :old_highest_post_number
                                             AND NOT EXISTS(SELECT 1
                                                            FROM users u
                                                            WHERE u.id = topic_users.user_id
                                                              AND (admin OR moderator))
                                           ) THEN
                                           GREATEST(topic_users.last_emailed_post_number,
                                                    excluded.last_emailed_post_number)
                                         ELSE topic_users.last_emailed_post_number END,
            first_visited_at         = LEAST(topic_users.first_visited_at, excluded.first_visited_at),
            last_visited_at          = GREATEST(topic_users.last_visited_at, excluded.last_visited_at)
    SQL
  end

  def update_statistics
    destination_topic.update_statistics
    original_topic.update_statistics
    TopicUser.update_post_action_cache(
      topic_id: [original_topic.id, destination_topic.id],
      post_id: @post_ids,
    )
  end

  def update_user_actions
    UserAction.synchronize_target_topic_ids(posts.map(&:id))
  end

  def create_moderator_post_in_original_topic
    move_type_str = PostMover.move_types[@move_type].to_s
    move_type_str.sub!("topic", "message") if @move_to_pm

    message =
      I18n.with_locale(SiteSetting.default_locale) do
        I18n.t(
          "move_posts.#{move_type_str}_moderator_post",
          count: posts.length,
          topic_link:
            (
              if posts.first.is_first_post?
                "[#{destination_topic.title}](#{destination_topic.relative_url})"
              else
                "[#{destination_topic.title}](#{posts.first.relative_url})"
              end
            ),
        )
      end

    post_type = @move_to_pm ? Post.types[:whisper] : Post.types[:small_action]
    original_topic.add_moderator_post(
      user,
      message,
      post_type: post_type,
      action_code: "split_topic",
      post_number: @first_post_number_moved,
    )
  end

  def posts
    @posts ||=
      begin
        Post
          .where(topic: @original_topic, id: post_ids)
          .where.not(post_type: Post.types[:small_action])
          .where.not(raw: "")
          .order(:created_at)
          .tap { |posts| raise Discourse::InvalidParameters.new(:post_ids) if posts.empty? }
      end
  end

  def update_last_post_stats
    post = destination_topic.ordered_posts.where.not(post_type: Post.types[:whisper]).last
    if post && post_ids.include?(post.id)
      attrs = {}
      attrs[:last_posted_at] = post.created_at
      attrs[:last_post_user_id] = post.user_id
      attrs[:bumped_at] = Time.now
      attrs[:updated_at] = Time.now
      destination_topic.update_columns(attrs)
    end
  end

  def update_upload_security_status
    DB.after_commit { Jobs.enqueue(:update_topic_upload_security, topic_id: @destination_topic.id) }
  end

  def update_bookmarks
    DB.after_commit do
      Jobs.enqueue(:sync_topic_user_bookmarked, topic_id: @original_topic.id)
      Jobs.enqueue(:sync_topic_user_bookmarked, topic_id: @destination_topic.id)
    end
  end

  def watch_new_topic
    if @destination_topic.archetype == Archetype.private_message
      if @original_topic.archetype == Archetype.private_message
        notification_levels =
          TopicUser
            .where(topic_id: @original_topic.id, user_id: posts.pluck(:user_id))
            .pluck(:user_id, :notification_level)
            .to_h
      else
        notification_levels =
          posts
            .pluck(:user_id)
            .uniq
            .map { |user_id| [user_id, TopicUser.notification_levels[:watching]] }
            .to_h
      end
    else
      notification_levels = [[@destination_topic.user_id, TopicUser.notification_levels[:watching]]]
    end

    notification_levels.each do |user_id, notification_level|
      TopicUser.change(
        user_id,
        @destination_topic.id,
        notification_level: notification_level,
        notifications_reason_id:
          TopicUser.notification_reasons[
            destination_topic.user_id == user_id ? :created_topic : :created_post
          ],
      )
    end
  end

  def add_allowed_users(usernames)
    return if usernames.blank?

    names = usernames.split(",").flatten
    User
      .where(username: names)
      .find_each do |user|
        unless destination_topic.topic_allowed_users.where(user_id: user.id).exists?
          destination_topic.topic_allowed_users.build(user_id: user.id)
        end
      end
    destination_topic.save!
  end

  def enqueue_jobs(topic)
    @post_creator.enqueue_jobs if @post_creator

    Jobs.enqueue(:notify_moved_posts, post_ids: @post_ids_after_move, moved_by_id: user.id)

    Jobs.enqueue(:delete_inaccessible_notifications, topic_id: topic.id)
  end

  def close_topic_and_schedule_deletion
    @original_topic.update_status("closed", true, @user)
    return if @options[:freeze_original] # we only close the topic when freezing it

    days_to_deleting = SiteSetting.delete_merged_stub_topics_after_days
    if days_to_deleting == 0
      is_allowed_to_delete_after_merge =
        DiscoursePluginRegistry.apply_modifier(
          :is_allowed_to_delete_after_merge,
          Guardian.new(@user).can_delete?(@original_topic),
          @original_topic,
          @user,
        )
      if is_allowed_to_delete_after_merge
        first_post = @original_topic.ordered_posts.first

        PostDestroyer.new(
          @user,
          first_post,
          context: I18n.t("topic_statuses.auto_deleted_by_merge"),
        ).destroy

        @original_topic.trash!(Discourse.system_user)
      end
    elsif days_to_deleting > 0
      @original_topic.set_or_create_timer(
        TopicTimer.types[:delete],
        days_to_deleting * 24,
        by_user: @user,
      )
    end
  end
end
