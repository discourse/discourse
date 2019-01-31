require "edit_rate_limiter"
require 'post_locker'

class PostRevisor

  # Helps us track changes to a topic.
  #
  # It's passed to `track_topic_fields` callbacks so they can record if they
  # changed a value or not. This is needed for things like custom fields.
  class TopicChanges
    attr_reader :topic, :user

    def initialize(topic, user)
      @topic = topic
      @user = user
      @changed = {}
      @errored = false
    end

    def errored?
      @errored
    end

    def guardian
      @guardian ||= Guardian.new(@user)
    end

    def record_change(field_name, previous_val, new_val)
      return if previous_val == new_val
      diff[field_name] = [previous_val, new_val]
    end

    def check_result(res)
      @errored = true if !res
    end

    def diff
      @diff ||= {}
    end
  end

  POST_TRACKED_FIELDS = %w{raw cooked edit_reason user_id wiki post_type}

  attr_reader :category_changed

  def initialize(post, topic = nil)
    @post = post
    @topic = topic || post.topic
  end

  def self.tracked_topic_fields
    @@tracked_topic_fields ||= {}
    @@tracked_topic_fields
  end

  def self.track_topic_field(field, &block)
    tracked_topic_fields[field] = block

    # Define it in the serializer unless it already has been defined
    unless PostRevisionSerializer.instance_methods(false).include?("#{field}_changes".to_sym)
      PostRevisionSerializer.add_compared_field(field)
    end
  end

  # Fields we want to record revisions for by default
  track_topic_field(:title) do |tc, title|
    tc.record_change('title', tc.topic.title, title)
    tc.topic.title = title
  end

  track_topic_field(:category_id) do |tc, category_id|
    if category_id == 0 || tc.guardian.can_move_topic_to_category?(category_id)
      tc.record_change('category_id', tc.topic.category_id, category_id)
      tc.check_result(tc.topic.change_category_to_id(category_id))
    end
  end

  track_topic_field(:tags) do |tc, tags|
    if tc.guardian.can_tag_topics?
      prev_tags = tc.topic.tags.map(&:name)
      next if tags.blank? && prev_tags.blank?
      if !DiscourseTagging.tag_topic_by_names(tc.topic, tc.guardian, tags)
        tc.check_result(false)
        next
      end
      tc.record_change('tags', prev_tags, tags) unless prev_tags.sort == tags.sort
    end
  end

  track_topic_field(:tags_empty_array) do |tc, val|
    if val.present? && tc.guardian.can_tag_topics?
      prev_tags = tc.topic.tags.map(&:name)
      if !DiscourseTagging.tag_topic_by_names(tc.topic, tc.guardian, [])
        tc.check_result(false)
        next
      end
      tc.record_change('tags', prev_tags, nil)
    end
  end

  track_topic_field(:featured_link) do |topic_changes, featured_link|
    if SiteSetting.topic_featured_link_enabled &&
       topic_changes.guardian.can_edit_featured_link?(topic_changes.topic.category_id)

      topic_changes.record_change('featured_link', topic_changes.topic.featured_link, featured_link)
      topic_changes.topic.featured_link = featured_link
    end
  end

  # AVAILABLE OPTIONS:
  # - revised_at: changes the date of the revision
  # - force_new_version: bypass ninja-edit window
  # - bypass_rate_limiter:
  # - bypass_bump: do not bump the topic, even if last post
  # - skip_validations: ask ActiveRecord to skip validations
  # - skip_revision: do not create a new PostRevision record
  def revise!(editor, fields, opts = {})
    @editor = editor
    @fields = fields.with_indifferent_access
    @opts = opts

    @topic_changes = TopicChanges.new(@topic, editor)

    # some normalization
    @fields[:raw] = cleanup_whitespaces(@fields[:raw]) if @fields.has_key?(:raw)
    @fields[:user_id] = @fields[:user_id].to_i if @fields.has_key?(:user_id)
    @fields[:category_id] = @fields[:category_id].to_i if @fields.has_key?(:category_id)

    # always reset edit_reason unless provided
    @fields[:edit_reason] = nil unless @fields[:edit_reason].present?

    return false unless should_revise?

    @post.acting_user = @editor
    @topic.acting_user = @editor
    @revised_at = @opts[:revised_at] || Time.now
    @last_version_at = @post.last_version_at || Time.now

    @version_changed = false
    @post_successfully_saved = true

    @validate_post = true
    @validate_post = @opts[:validate_post] if @opts.has_key?(:validate_post)
    @validate_post = !@opts[:skip_validations] if @opts.has_key?(:skip_validations)

    @validate_topic = true
    @validate_topic = @opts[:validate_topic] if @opts.has_key?(:validate_topic)
    @validate_topic = !@opts[:validate_topic] if @opts.has_key?(:skip_validations)

    @skip_revision = false
    @skip_revision = @opts[:skip_revision] if @opts.has_key?(:skip_revision)

    old_raw = @post.raw

    Post.transaction do
      revise_post

      yield if block_given?
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

    # Lock the post by default if the appropriate setting is true
    if (
      SiteSetting.staff_edit_locks_post? &&
      !@post.wiki? &&
      @fields.has_key?('raw') &&
      @editor.staff? &&
      @editor != Discourse.system_user &&
      !@post.user.staff?
    )
      PostLocker.new(@post, @editor).lock
    end

    # We log staff edits to posts
    if @editor.staff? && @editor.id != @post.user.id && @fields.has_key?('raw')
      StaffActionLogger.new(@editor).log_post_edit(
        @post,
        old_raw: old_raw
      )
    end

    # WARNING: do not pull this into the transaction
    # it can fire events in sidekiq before the post is done saving
    # leading to corrupt state
    QuotedPost.extract_from(@post)
    post_process_post

    update_topic_word_counts
    alert_users
    publish_changes
    grant_badge

    TopicLink.extract_from(@post)

    successfully_saved_post_and_topic
  end

  def cleanup_whitespaces(raw)
    raw.present? ? TextCleaner.normalize_whitespaces(raw).gsub(/\s+\z/, "") : ""
  end

  def should_revise?
    post_changed? || topic_changed?
  end

  def post_changed?
    POST_TRACKED_FIELDS.each do |field|
      return true if @fields.has_key?(field) && @fields[field] != @post.send(field)
    end
    advance_draft_sequence
    false
  end

  def topic_changed?
    PostRevisor.tracked_topic_fields.keys.any? { |f| @fields.has_key?(f) }
  end

  def revise_post
    if should_create_new_version?
      revise_and_create_new_version
    else
      unless cached_original_raw
        self.original_raw = @post.raw
        self.original_cooked = @post.cooked
      end
      revise
    end
  end

  def should_create_new_version?
    return false if @skip_revision
    edited_by_another_user? || !ninja_edit? || owner_changed? || force_new_version?
  end

  def edited_by_another_user?
    @post.last_editor_id != @editor.id
  end

  def original_raw_key
    "original_raw_#{(@last_version_at.to_f * 1000).to_i}#{@post.id}"
  end

  def original_cooked_key
    "original_cooked_#{(@last_version_at.to_f * 1000).to_i}#{@post.id}"
  end

  def cached_original_raw
    @cached_original_raw ||= $redis.get(original_raw_key)
  end

  def cached_original_cooked
    @cached_original_cooked ||= $redis.get(original_cooked_key)
  end

  def original_raw
    cached_original_raw || @post.raw
  end

  def original_raw=(val)
    @cached_original_raw = val
    $redis.setex(original_raw_key, SiteSetting.editing_grace_period + 1, val)
  end

  def original_cooked=(val)
    @cached_original_cooked = val
    $redis.setex(original_cooked_key, SiteSetting.editing_grace_period + 1, val)
  end

  def diff_size(before, after)
    changes = 0
    ONPDiff.new(before, after).short_diff.each do |str, type|
      next if type == :common
      changes += str.length
    end
    changes
  end

  def ninja_edit?
    return false if @post.has_active_flag?
    return false if (@revised_at - @last_version_at) > SiteSetting.editing_grace_period.to_i

    if new_raw = @fields[:raw]

      max_diff = SiteSetting.editing_grace_period_max_diff.to_i
      if @editor.staff? || (@editor.trust_level > 1)
        max_diff = SiteSetting.editing_grace_period_max_diff_high_trust.to_i
      end

      if (original_raw.length - new_raw.length).abs > max_diff ||
        diff_size(original_raw, new_raw) > max_diff
        return false
      end
    end

    true
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

  USER_ACTIONS_TO_REMOVE ||= [UserAction::REPLY, UserAction::RESPONSE]

  def update_post
    if @fields.has_key?("user_id") && @fields["user_id"] != @post.user_id && @post.user_id != nil
      prev_owner = User.find(@post.user_id)
      new_owner = User.find(@fields["user_id"])

      # UserActionCreator will create new UserAction records for the new owner

      UserAction.where(target_post_id: @post.id)
        .where(user_id: prev_owner.id)
        .where(action_type: USER_ACTIONS_TO_REMOVE)
        .destroy_all

      if @post.post_number == 1
        UserAction.where(target_topic_id: @post.topic_id)
          .where(user_id: prev_owner.id)
          .where(action_type: UserAction::NEW_TOPIC)
          .destroy_all
      end
    end

    POST_TRACKED_FIELDS.each do |field|
      @post.send("#{field}=", @fields[field]) if @fields.has_key?(field)
    end

    @post.last_editor_id = @editor.id
    @post.word_count     = @fields[:raw].scan(/[[:word:]]+/).size if @fields.has_key?(:raw)
    @post.self_edits    += 1 if self_edit?

    remove_flags_and_unhide_post

    @post.extract_quoted_post_numbers

    @post_successfully_saved = @post.save(validate: @validate_post)
    @post.save_reply_relationships

    # post owner changed
    if prev_owner && new_owner && prev_owner != new_owner
      likes = UserAction.where(target_post_id: @post.id)
        .where(user_id: prev_owner.id)
        .where(action_type: UserAction::WAS_LIKED)
        .update_all(user_id: new_owner.id)

      private_message = @post.topic.private_message?

      prev_owner_user_stat = prev_owner.user_stat
      unless private_message
        prev_owner_user_stat.post_count -= 1 if @post.post_type == Post.types[:regular]
        prev_owner_user_stat.topic_count -= 1 if @post.is_first_post?
        prev_owner_user_stat.likes_received -= likes
      end
      prev_owner_user_stat.update_topic_reply_count

      if @post.created_at == prev_owner.user_stat.first_post_created_at
        prev_owner_user_stat.first_post_created_at = prev_owner.posts.order('created_at ASC').first.try(:created_at)
      end

      prev_owner_user_stat.save!

      new_owner_user_stat = new_owner.user_stat
      unless private_message
        new_owner_user_stat.post_count += 1 if @post.post_type == Post.types[:regular]
        new_owner_user_stat.topic_count += 1 if @post.is_first_post?
        new_owner_user_stat.likes_received += likes
      end
      new_owner_user_stat.update_topic_reply_count
      new_owner_user_stat.save!
    end
  end

  def self_edit?
    @editor == @post.user
  end

  def remove_flags_and_unhide_post
    return unless editing_a_flagged_and_hidden_post?

    flaggers = []
    @post.post_actions.where(post_action_type_id: PostActionType.flag_types_without_custom.values).each do |action|
      flaggers << action.user if action.user
      action.remove_act!(Discourse.system_user)
    end

    @post.unhide!
    PostActionNotifier.after_post_unhide(@post, flaggers)
  end

  def editing_a_flagged_and_hidden_post?
    self_edit? &&
    @post.hidden &&
    @post.hidden_reason_id == Post.hidden_reasons[:flag_threshold_reached]
  end

  def update_topic
    Topic.transaction do
      PostRevisor.tracked_topic_fields.each do |f, cb|
        if !@topic_changes.errored? && @fields.has_key?(f)
          cb.call(@topic_changes, @fields[f])
        end
      end

      unless @topic_changes.errored?
        @topic_changes.check_result(@topic.save(validate: @validate_topic))
      end
    end
  end

  def create_or_update_revision
    return if @skip_revision
    # don't create an empty revision if something failed
    return unless successfully_saved_post_and_topic
    @version_changed ? create_revision : update_revision
  end

  def create_revision
    modifications = post_changes.merge(@topic_changes.diff)

    if modifications["raw"]
      modifications["raw"][0] = cached_original_raw || modifications["raw"][0]
    end

    if modifications["cooked"]
      modifications["cooked"][0] = cached_original_cooked || modifications["cooked"][0]
    end

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
    modifications = post_changes.merge(@topic_changes.diff)

    modifications.each_key do |field|
      if revision.modifications.has_key?(field)
        old_value = revision.modifications[field][0].to_s
        new_value = modifications[field][1].to_s
        if old_value != new_value
          revision.modifications[field] = [old_value, new_value]
        else
          revision.modifications.delete(field)
        end
      else
        revision.modifications[field] = modifications[field]
      end
    end
    # should probably do this before saving the post!
    if revision.modifications.empty?
      revision.destroy
      @post.version -= 1
      @post.public_version -= 1
      @post.save
    else
      revision.save
    end
  end

  def post_changes
    @post.previous_changes.slice(*POST_TRACKED_FIELDS)
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
    !@post_successfully_saved || @topic_changes.errored? || @opts[:bypass_bump] == true
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
    return unless @post.is_first_post?

    update_topic_excerpt
    update_category_description
  end

  def update_topic_excerpt
    excerpt = @post.excerpt_for_topic
    @topic.update_column(:excerpt, excerpt)
    if @topic.archetype == "banner"
      ApplicationController.banner_json_cache.clear
    end
  end

  def update_category_description
    return unless category = Category.find_by(topic_id: @topic.id)

    doc = Nokogiri::HTML.fragment(@post.cooked)
    doc.css("img").remove

    if html = doc.css("p").first&.inner_html&.strip
      new_description = html unless html.starts_with?(Category.post_template[0..50])
      category.update_column(:description, new_description)
      @category_changed = category
    else
      @post.errors[:base] << I18n.t("category.errors.description_incomplete")
    end
  end

  def advance_draft_sequence
    @post.advance_draft_sequence
  end

  def post_process_post
    @post.invalidate_oneboxes = true
    @post.trigger_post_process
    DiscourseEvent.trigger(:post_edited, @post, self.topic_changed?)
  end

  def update_topic_word_counts
    DB.exec("UPDATE topics
                    SET word_count = (
                      SELECT SUM(COALESCE(posts.word_count, 0))
                      FROM posts
                      WHERE posts.topic_id = :topic_id
                    )
                    WHERE topics.id = :topic_id", topic_id: @topic.id)
  end

  def alert_users
    return if @editor.id == Discourse::SYSTEM_USER_ID
    Jobs.enqueue(:post_alert, post_id: @post.id)
  end

  def publish_changes
    options =
      if !@topic_changes.diff.empty? && !@topic_changes.errored?
        { reload_topic: true }
      else
        {}
      end

    @post.publish_change_to_clients!(:revised, options)
  end

  def grant_badge
    BadgeGranter.queue_badge_grant(Badge::Trigger::PostRevision, post: @post)
  end

  def successfully_saved_post_and_topic
    @post_successfully_saved && !@topic_changes.errored?
  end

end
