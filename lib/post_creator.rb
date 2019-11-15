# frozen_string_literal: true

# Responsible for creating posts and topics
#

class PostCreator
  include HasErrors

  attr_reader :opts

  # Acceptable options:
  #
  #   raw                     - raw text of post
  #   image_sizes             - We can pass a list of the sizes of images in the post as a shortcut.
  #   invalidate_oneboxes     - Whether to force invalidation of oneboxes in this post
  #   acting_user             - The user performing the action might be different than the user
  #                             who is the post "author." For example when copying posts to a new
  #                             topic.
  #   created_at              - Post creation time (optional)
  #   auto_track              - Automatically track this topic if needed (default true)
  #   custom_fields           - Custom fields to be added to the post, Hash (default nil)
  #   post_type               - Whether this is a regular post or moderator post.
  #   no_bump                 - Do not cause this post to bump the topic.
  #   cooking_options         - Options for rendering the text
  #   cook_method             - Method of cooking the post.
  #                               :regular - Pass through Markdown parser and strip bad HTML
  #                               :raw_html - Perform no processing
  #                               :raw_email - Imported from an email
  #   via_email               - Mark this post as arriving via email
  #   raw_email               - Full text of arriving email (to store)
  #   action_code             - Describes a small_action post (optional)
  #   skip_jobs               - Don't enqueue jobs when creation succeeds. This is needed if you
  #                             wrap `PostCreator` in a transaction, as the sidekiq jobs could
  #                             dequeue before the commit finishes. If you do this, be sure to
  #                             call `enqueue_jobs` after the transaction is comitted.
  #   hidden_reason_id        - Reason for hiding the post (optional)
  #   skip_validations        - Do not validate any of the content in the post
  #
  #   When replying to a topic:
  #     topic_id              - topic we're replying to
  #     reply_to_post_number  - post number we're replying to
  #
  #   When creating a topic:
  #     title                 - New topic title
  #     archetype             - Topic archetype
  #     is_warning            - Is the topic a warning?
  #     category              - Category to assign to topic
  #     target_usernames      - comma delimited list of usernames for membership (private message)
  #     target_group_names    - comma delimited list of groups for membership (private message)
  #     meta_data             - Topic meta data hash
  #     created_at            - Topic creation time (optional)
  #     pinned_at             - Topic pinned time (optional)
  #     pinned_globally       - Is the topic pinned globally (optional)
  #     shared_draft          - Is the topic meant to be a shared draft
  #     topic_opts            - Options to be overwritten for topic
  #
  def initialize(user, opts)
    # TODO: we should reload user in case it is tainted, should take in a user_id as opposed to user
    # If we don't do this we introduce a rather risky dependency
    @user = user
    @opts = opts || {}
    opts[:title] = pg_clean_up(opts[:title]) if opts[:title] && opts[:title].include?("\u0000")
    opts[:raw] = pg_clean_up(opts[:raw]) if opts[:raw] && opts[:raw].include?("\u0000")
    opts.delete(:reply_to_post_number) unless opts[:topic_id]
    opts[:visible] = false if opts[:visible].nil? && opts[:hidden_reason_id].present?
    @guardian = opts[:guardian] if opts[:guardian]

    @spam = false
  end

  def pg_clean_up(str)
    str.gsub("\u0000", "")
  end

  # True if the post was considered spam
  def spam?
    @spam
  end

  def skip_validations?
    @opts[:skip_validations]
  end

  def guardian
    @guardian ||= Guardian.new(@user)
  end

  def valid?
    @topic = nil
    @post = nil

    if @user.suspended? && !skip_validations?
      errors.add(:base, I18n.t(:user_is_suspended))
      return false
    end

    if @opts[:target_usernames].present? && !skip_validations? && !@user.staff?
      names = @opts[:target_usernames].split(',')

      # Make sure max_allowed_message_recipients setting is respected
      max_allowed_message_recipients = SiteSetting.max_allowed_message_recipients

      if names.length > max_allowed_message_recipients
        errors.add(
          :base,
          I18n.t(:max_pm_recepients, recipients_limit: max_allowed_message_recipients)
        )

        return false
      end

      # Make sure none of the users have muted the creator
      users = User.where(username: names).pluck(:id, :username).to_h

      User
        .joins("LEFT JOIN user_options ON user_options.user_id = users.id")
        .joins("LEFT JOIN muted_users ON muted_users.user_id = users.id AND muted_users.muted_user_id = #{@user.id.to_i}")
        .joins("LEFT JOIN ignored_users ON ignored_users.user_id = users.id AND ignored_users.ignored_user_id = #{@user.id.to_i}")
        .where("user_options.user_id IS NOT NULL")
        .where("
          (user_options.user_id IN (:user_ids) AND NOT user_options.allow_private_messages) OR
          muted_users.user_id IN (:user_ids) OR
          ignored_users.user_id IN (:user_ids)
        ", user_ids: users.keys)
        .pluck(:id).each do |m|

        errors.add(:base, I18n.t(:not_accepting_pms, username: users[m]))
      end

      return false if errors[:base].present?
    end

    if new_topic?
      topic_creator = TopicCreator.new(@user, guardian, @opts)
      return false unless skip_validations? || validate_child(topic_creator)
    else
      @topic = Topic.find_by(id: @opts[:topic_id])
      unless @topic.present? && (@opts[:skip_guardian] || guardian.can_create?(Post, @topic))
        errors.add(:base, I18n.t(:topic_not_found))
        return false
      end
    end

    setup_post

    return true if skip_validations?

    if @post.has_host_spam?
      @spam = true
      errors.add(:base, I18n.t(:spamming_host))
      return false
    end

    DiscourseEvent.trigger :before_create_post, @post
    DiscourseEvent.trigger :validate_post, @post

    post_validator = PostValidator.new(skip_topic: true)
    post_validator.validate(@post)

    valid = @post.errors.blank?
    add_errors_from(@post) unless valid
    valid
  end

  def create
    if valid?
      transaction do
        build_post_stats
        create_topic
        create_post_notice
        save_post
        UserActionManager.post_created(@post)
        extract_links
        track_topic
        update_topic_stats
        update_topic_auto_close
        update_user_counts
        create_embedded_topic
        link_post_uploads
        ensure_in_allowed_users if guardian.is_staff?
        unarchive_message
        @post.advance_draft_sequence unless @opts[:import_mode]
        @post.save_reply_relationships
      end
    end

    if @post && errors.blank? && !@opts[:import_mode]
      store_unique_post_key
      # update counters etc.
      @post.topic.reload

      publish

      track_latest_on_category
      enqueue_jobs unless @opts[:skip_jobs]
      BadgeGranter.queue_badge_grant(Badge::Trigger::PostRevision, post: @post)

      trigger_after_events unless opts[:skip_events]

      auto_close
    end

    handle_spam if !opts[:import_mode] && (@post || @spam)

    @post
  end

  def create!
    create

    if !self.errors.full_messages.empty?
      raise ActiveRecord::RecordNotSaved.new(self.errors.full_messages.to_sentence)
    end

    @post
  end

  def enqueue_jobs
    return unless @post && !@post.errors.present?

    PostJobsEnqueuer.new(@post, @topic, new_topic?,
      import_mode: @opts[:import_mode],
      post_alert_options: @opts[:post_alert_options]
    ).enqueue_jobs
  end

  def trigger_after_events
    DiscourseEvent.trigger(:topic_created, @post.topic, @opts, @user) unless @opts[:topic_id]
    DiscourseEvent.trigger(:post_created, @post, @opts, @user)
  end

  def self.track_post_stats
    Rails.env != "test".freeze || @track_post_stats
  end

  def self.track_post_stats=(val)
    @track_post_stats = val
  end

  def self.create(user, opts)
    PostCreator.new(user, opts).create
  end

  def self.create!(user, opts)
    PostCreator.new(user, opts).create!
  end

  def self.before_create_tasks(post)
    set_reply_info(post)

    post.word_count = post.raw.scan(/[[:word:]]+/).size

    whisper = post.post_type == Post.types[:whisper]
    increase_posts_count = !post.topic&.private_message? || post.post_type != Post.types[:small_action]
    post.post_number ||= Topic.next_post_number(post.topic_id,
      reply: post.reply_to_post_number.present?,
      whisper: whisper,
      post: increase_posts_count)

    cooking_options = post.cooking_options || {}
    cooking_options[:topic_id] = post.topic_id

    post.cooked ||= post.cook(post.raw, cooking_options.symbolize_keys)
    post.sort_order = post.post_number
    post.last_version_at ||= Time.now
  end

  def self.set_reply_info(post)
    return unless post.reply_to_post_number.present?

    # Before the locking here was added, replying to a post and liking a post
    # at roughly the same time could cause a deadlock.
    #
    # Liking a post grabs an update lock on the post and then on the topic (to
    # update like counts).
    #
    # Here, we lock the replied to post before getting the topic lock so that
    # we can update the replied to post later without causing a deadlock.

    reply_info = Post.where(topic_id: post.topic_id, post_number: post.reply_to_post_number)
      .select(:user_id, :post_type)
      .lock
      .first

    if reply_info.present?
      post.reply_to_user_id ||= reply_info.user_id
      whisper_type = Post.types[:whisper]
      post.post_type = whisper_type if reply_info.post_type == whisper_type
    end
  end

  protected

  def build_post_stats
    if PostCreator.track_post_stats
      draft_key = @topic ? "topic_#{@topic.id}" : "new_topic"

      sequence = DraftSequence.current(@user, draft_key)
      revisions = Draft.where(sequence: sequence,
                              user_id: @user.id,
                              draft_key: draft_key).pluck_first(:revisions) || 0

      @post.build_post_stat(
        drafts_saved: revisions,
        typing_duration_msecs: @opts[:typing_duration_msecs] || 0,
        composer_open_duration_msecs: @opts[:composer_open_duration_msecs] || 0
      )
    end
  end

  def auto_close
    topic = @post.topic
    is_private_message = topic.private_message?
    topic_posts_count = @post.topic.posts_count

    if is_private_message &&
        !topic.closed &&
        SiteSetting.auto_close_messages_post_count > 0 &&
        SiteSetting.auto_close_messages_post_count <= topic_posts_count

      @post.topic.update_status(
        :closed, true, Discourse.system_user,
        message: I18n.t(
          'topic_statuses.autoclosed_message_max_posts',
          count: SiteSetting.auto_close_messages_post_count
        )
      )
    elsif !is_private_message &&
        !topic.closed &&
        SiteSetting.auto_close_topics_post_count > 0 &&
        SiteSetting.auto_close_topics_post_count <= topic_posts_count

      topic.update_status(
        :closed, true, Discourse.system_user,
        message: I18n.t(
          'topic_statuses.autoclosed_topic_max_posts',
          count: SiteSetting.auto_close_topics_post_count
        )
      )
    end
  end

  def transaction(&blk)
    if new_topic?
      Post.transaction do
        blk.call
      end
    else
      # we need to ensure post_number is monotonically increasing with no gaps
      # so we serialize creation to avoid needing rollbacks
      DistributedMutex.synchronize("topic_id_#{@opts[:topic_id]}") do
        Post.transaction do
          blk.call
        end
      end
    end
  end

  # You can supply an `embed_url` for a post to set up the embedded relationship.
  # This is used by the wp-discourse plugin to associate a remote post with a
  # discourse post.
  def create_embedded_topic
    return unless @opts[:embed_url].present?
    embed = TopicEmbed.new(topic_id: @post.topic_id, post_id: @post.id, embed_url: @opts[:embed_url])
    rollback_from_errors!(embed) unless embed.save
  end

  def link_post_uploads
    @post.link_post_uploads
  end

  def handle_spam
    if @spam
      GroupMessage.create(Group[:moderators].name,
                           :spam_post_blocked,
                           user: @user,
                           limit_once_per: 24.hours,
                           message_params: { domains: @post.linked_hosts.keys.join(', ') })
    elsif @post && errors.blank? && !skip_validations?
      SpamRule::FlagSockpuppets.new(@post).perform
    end
  end

  def track_latest_on_category
    return unless @post && @post.errors.count == 0 && @topic && @topic.category_id

    Category.where(id: @topic.category_id).update_all(latest_post_id: @post.id)
    Category.where(id: @topic.category_id).update_all(latest_topic_id: @topic.id) if @post.is_first_post?
  end

  def ensure_in_allowed_users
    return unless @topic.private_message? && @topic.id

    unless @topic.topic_allowed_users.where(user_id: @user.id).exists?
      unless @topic.topic_allowed_groups.where('group_id IN (
                                              SELECT group_id FROM group_users where user_id = ?
                                           )', @user.id).exists?
        @topic.topic_allowed_users.create!(user_id: @user.id)
      end
    end
  end

  def unarchive_message
    return unless @topic.private_message? && @topic.id

    UserArchivedMessage.where(topic_id: @topic.id).pluck(:user_id).each do |user_id|
      UserArchivedMessage.move_to_inbox!(user_id, @topic)
    end

    GroupArchivedMessage.where(topic_id: @topic.id).pluck(:group_id).each do |group_id|
      GroupArchivedMessage.move_to_inbox!(group_id, @topic)
    end
  end

  private

  def create_topic
    return if @topic
    begin
      opts = @opts[:topic_opts] ? @opts.merge(@opts[:topic_opts]) : @opts
      topic_creator = TopicCreator.new(@user, guardian, opts)
      @topic = topic_creator.create
    rescue ActiveRecord::Rollback
      rollback_from_errors!(topic_creator)
    end
    @post.topic_id = @topic.id
    @post.topic = @topic
    if @topic && @topic.category && @topic.category.all_topics_wiki
      @post.wiki = true
    end
  end

  def update_topic_stats
    attrs = { updated_at: Time.now }

    if @post.post_type != Post.types[:whisper]
      attrs[:last_posted_at] = @post.created_at
      attrs[:last_post_user_id] = @post.user_id
      attrs[:word_count] = (@topic.word_count || 0) + @post.word_count
      attrs[:excerpt] = @post.excerpt_for_topic if new_topic?
      attrs[:bumped_at] = @post.created_at unless @post.no_bump
      @topic.update_columns(attrs)
    end

    @topic.update_columns(attrs)
  end

  def update_topic_auto_close
    return if @opts[:import_mode]

    if @topic.closed?
      @topic.delete_topic_timer(TopicTimer.types[:close])
    else
      topic_timer = @topic.public_topic_timer

      if topic_timer &&
         topic_timer.based_on_last_post &&
         topic_timer.duration > 0

        @topic.set_or_create_timer(TopicTimer.types[:close],
          topic_timer.duration,
          based_on_last_post: topic_timer.based_on_last_post
        )
      end
    end
  end

  def setup_post
    @opts[:raw] = TextCleaner.normalize_whitespaces(@opts[:raw] || '').gsub(/\s+\z/, "")

    post = Post.new(raw: @opts[:raw],
                    topic_id: @topic.try(:id),
                    user: @user,
                    reply_to_post_number: @opts[:reply_to_post_number])

    # Attributes we pass through to the post instance if present
    [:post_type, :no_bump, :cooking_options, :image_sizes, :acting_user, :invalidate_oneboxes, :cook_method, :via_email, :raw_email, :action_code].each do |a|
      post.public_send("#{a}=", @opts[a]) if @opts[a].present?
    end

    post.extract_quoted_post_numbers
    post.created_at = Time.zone.parse(@opts[:created_at].to_s) if @opts[:created_at].present?

    if fields = @opts[:custom_fields]
      post.custom_fields = fields
    end

    if @opts[:hidden_reason_id].present?
      post.hidden = true
      post.hidden_at = Time.zone.now
      post.hidden_reason_id = @opts[:hidden_reason_id]
    end

    @post = post
  end

  def save_post
    @post.disable_rate_limits! if skip_validations?
    @post.skip_validation = skip_validations?
    saved = @post.save
    rollback_from_errors!(@post) unless saved
  end

  def store_unique_post_key
    @post.store_unique_post_key
  end

  def update_user_counts
    return if @opts[:import_mode]

    @user.create_user_stat if @user.user_stat.nil?

    if @user.user_stat.first_post_created_at.nil?
      @user.user_stat.first_post_created_at = @post.created_at
    end

    unless @post.topic.private_message?
      @user.user_stat.post_count += 1 if @post.post_type == Post.types[:regular] && !@post.is_first_post?
      @user.user_stat.topic_count += 1 if @post.is_first_post?
    end

    # We don't count replies to your own topics
    if !@opts[:import_mode] && @user.id != @topic.user_id
      @user.user_stat.update_topic_reply_count
    end

    @user.user_stat.save!

    if !@topic.private_message? && @post.post_type != Post.types[:whisper]
      @user.update(last_posted_at: @post.created_at)
    end
  end

  def create_post_notice
    return if @opts[:import_mode] || @user.anonymous? || @user.bot? || @user.staged

    last_post_time = Post.where(user_id: @user.id)
      .order(created_at: :desc)
      .limit(1)
      .pluck(:created_at)
      .first

    if !last_post_time
      @post.custom_fields["notice_type"] = Post.notices[:new_user]
    elsif SiteSetting.returning_users_days > 0 && last_post_time < SiteSetting.returning_users_days.days.ago
      @post.custom_fields["notice_type"] = Post.notices[:returning_user]
      @post.custom_fields["notice_args"] = last_post_time.iso8601
    end
  end

  def publish
    return if @opts[:import_mode] || @post.post_number == 1
    @post.publish_change_to_clients! :created
  end

  def extract_links
    TopicLink.extract_from(@post)
    QuotedPost.extract_from(@post)
  end

  def track_topic
    return if @opts[:import_mode] || @opts[:auto_track] == false

    TopicUser.change(@post.user_id,
                      @topic.id,
                      posted: true,
                      last_read_post_number: @post.post_number,
                      highest_seen_post_number: @post.post_number)

    # assume it took us 5 seconds of reading time to make a post
    PostTiming.record_timing(topic_id: @post.topic_id,
                             user_id: @post.user_id,
                             post_number: @post.post_number,
                             msecs: 5000)

    if @user.staged
      TopicUser.auto_notification_for_staging(@user.id, @topic.id, TopicUser.notification_reasons[:auto_watch])
    elsif !@topic.private_message?
      notification_level = @user.user_option.notification_level_when_replying || NotificationLevels.topic_levels[:tracking]
      TopicUser.auto_notification(@user.id, @topic.id, TopicUser.notification_reasons[:created_post], notification_level)
    end
  end

  def new_topic?
    @opts[:topic_id].blank?
  end

end
