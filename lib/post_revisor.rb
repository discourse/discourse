require "edit_rate_limiter"

class PostRevisor

  POST_TRACKED_FIELDS = %w{raw cooked edit_reason user_id wiki post_type}
  TOPIC_TRACKED_FIELDS = %w{title category_id}

  attr_reader :category_changed

  def initialize(post, topic=nil)
    @post = post
    @topic = topic || post.topic
  end

  # AVAILABLE OPTIONS:
  # - revised_at: changes the date of the revision
  # - force_new_version: bypass ninja-edit window
  # - bypass_rate_limiter:
  # - bypass_bump: do not bump the topic, even if last post
  # - skip_validations: ask ActiveRecord to skip validations
  def revise!(editor, fields, opts={})
    @editor = editor
    @fields = fields.with_indifferent_access
    @opts = opts

    # some normalization
    @fields[:raw] = cleanup_whitespaces(@fields[:raw]) if @fields.has_key?(:raw)
    @fields[:user_id] = @fields[:user_id].to_i if @fields.has_key?(:user_id)
    @fields[:category_id] = @fields[:category_id].to_i if @fields.has_key?(:category_id)

    # always reset edit_reason unless provided
    @fields[:edit_reason] = nil unless @fields.has_key?(:edit_reason)

    return false unless should_revise?

    @post.acting_user = @editor
    @topic.acting_user = @editor
    @revised_at = @opts[:revised_at] || Time.now
    @last_version_at = @post.last_version_at || Time.now

    @version_changed = false
    @post_successfully_saved = true
    @topic_successfully_saved = true

    Post.transaction do
      revise_post

      # TODO: these callbacks are being called in a transaction
      # it is kind of odd, because the callback is called "before_edit"
      # but the post is already edited at this point
      # Trouble is that much of the logic of should I edit? is deeper
      # down so yanking this in front of the transaction will lead to
      # false positive.
      plugin_callbacks

      revise_topic
      advance_draft_sequence
    end

    # WARNING: do not pull this into the transaction
    # it can fire events in sidekiq before the post is done saving
    # leading to corrupt state
    post_process_post

    update_topic_word_counts
    alert_users
    publish_changes
    grant_badge

    @post_successfully_saved && @topic_successfully_saved
  end

  def cleanup_whitespaces(raw)
    TextCleaner.normalize_whitespaces(raw).gsub(/\s+\z/, "")
  end

  def should_revise?
    post_changed? || topic_changed?
  end

  def post_changed?
    POST_TRACKED_FIELDS.each do |field|
      return true if @fields.has_key?(field) && @fields[field] != @post.send(field)
    end
    false
  end

  def topic_changed?
    TOPIC_TRACKED_FIELDS.each do |field|
      return true if @fields.has_key?(field) && @fields[field] != @topic.send(field)
    end
    false
  end

  def revise_post
    if should_create_new_version?
      revise_and_create_new_version
    else
      revise
    end
  end

  def should_create_new_version?
    edited_by_another_user? || !ninja_edit? || owner_changed? || force_new_version?
  end

  def edited_by_another_user?
    @post.last_editor_id != @editor.id
  end

  def ninja_edit?
    @revised_at - @last_version_at <= SiteSetting.ninja_edit_window.to_i
  end

  def owner_changed?
    @fields.has_key?(:user_id) && @fields[:user_id] != @post.user_id
  end

  def force_new_version?
    @opts[:force_new_version] == true
  end

  def revise_and_create_new_version
    @version_changed = true
    @post.version += 1
    @post.public_version += 1
    @post.last_version_at = @revised_at

    revise
    perform_edit
    bump_topic
  end

  def revise
    update_post
    update_topic if topic_changed?
    create_or_update_revision
  end

  def update_post
    POST_TRACKED_FIELDS.each do |field|
      @post.send("#{field}=", @fields[field]) if @fields.has_key?(field)
    end

    @post.last_editor_id = @editor.id
    @post.word_count     = @fields[:raw].scan(/\w+/).size if @fields.has_key?(:raw)
    @post.self_edits    += 1 if self_edit?

    clear_flags_and_unhide_post

    @post.extract_quoted_post_numbers
    @post_successfully_saved = @post.save(validate: !@opts[:skip_validations])
    @post.save_reply_relationships
  end

  def self_edit?
    @editor == @post.user
  end

  def clear_flags_and_unhide_post
    return unless editing_a_flagged_and_hidden_post?
    PostAction.clear_flags!(@post, Discourse.system_user)
    @post.unhide!
  end

  def editing_a_flagged_and_hidden_post?
    self_edit? &&
    @post.hidden &&
    @post.hidden_reason_id == Post.hidden_reasons[:flag_threshold_reached]
  end

  def update_topic
    @topic.title = @fields[:title] if @fields.has_key?(:title)
    Topic.transaction do
      @topic_successfully_saved = @topic.change_category_to_id(@fields[:category_id]) if @fields.has_key?(:category_id)
      @topic_successfully_saved &&= @topic.save(validate: !@opts[:skip_validations])
    end
  end

  def create_or_update_revision
    if @version_changed
      create_revision
    else
      update_revision
    end
  end

  def create_revision
    modifications = post_changes.merge(topic_changes)
    PostRevision.create!(
      user_id: @post.last_editor_id,
      post_id: @post.id,
      number: @post.version,
      modifications: modifications
    )
  end

  def update_revision
    return unless revision = PostRevision.find_by(post_id: @post.id, number: @post.version)
    revision.user_id = @post.last_editor_id
    modifications = post_changes.merge(topic_changes)
    modifications.keys.each do |field|
      if revision.modifications.has_key?(field)
        old_value = revision.modifications[field][0]
        new_value = modifications[field][1]
        revision.modifications[field] = [old_value, new_value]
      else
        revision.modifications[field] = modifications[field]
      end
    end
    revision.save
  end

  def post_changes
    @post.previous_changes.slice(*POST_TRACKED_FIELDS)
  end

  def topic_changes
    @topic.previous_changes.slice(*TOPIC_TRACKED_FIELDS)
  end

  def perform_edit
    return if bypass_rate_limiter?
    EditRateLimiter.new(@editor).performed!
  end

  def bypass_rate_limiter?
    @opts[:bypass_rate_limiter] == true
  end

  def bump_topic
    return if bypass_bump? || !is_last_post?
    @topic.update_column(:bumped_at, Time.now)
    TopicTrackingState.publish_latest(@topic)
  end

  def bypass_bump?
    @opts[:bypass_bump] == true
  end

  def is_last_post?
    !Post.where(topic_id: @topic.id)
         .where("post_number > ?", @post.post_number)
         .exists?
  end

  def plugin_callbacks
    DiscourseEvent.trigger(:before_edit_post, @post)
    DiscourseEvent.trigger(:validate_post, @post)
  end

  def revise_topic
    return unless @post.post_number == 1

    update_topic_excerpt
    update_category_description
  end

  def update_topic_excerpt
    excerpt = @post.excerpt(220, strip_links: true)
    @topic.update_column(:excerpt, excerpt)
  end

  def update_category_description
    return unless category = Category.find_by(topic_id: @topic.id)

    body = @post.cooked
    matches = body.scan(/\<p\>(.*)\<\/p\>/)
    if matches && matches[0] && matches[0][0]
      new_description = matches[0][0]
      new_description = nil if new_description == I18n.t("category.replace_paragraph")
      category.update_column(:description, new_description)
      @category_changed = category
    end
  end

  def advance_draft_sequence
    @post.advance_draft_sequence
  end

  def post_process_post
    @post.invalidate_oneboxes = true
    @post.trigger_post_process
  end

  def update_topic_word_counts
    Topic.exec_sql("UPDATE topics
                    SET word_count = (
                      SELECT SUM(COALESCE(posts.word_count, 0))
                      FROM posts
                      WHERE posts.topic_id = :topic_id
                    )
                    WHERE topics.id = :topic_id", topic_id: @topic.id)
  end

  def alert_users
    PostAlerter.new.after_save_post(@post)
  end

  def publish_changes
    @post.publish_change_to_clients!(:revised)
  end

  def grant_badge
    BadgeGranter.queue_badge_grant(Badge::Trigger::PostRevision, post: @post)
  end

end
