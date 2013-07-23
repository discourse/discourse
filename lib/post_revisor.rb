require 'edit_rate_limiter'
class PostRevisor

  attr_reader :category_changed

  def initialize(post)
    @post = post
  end

  def revise!(user, new_raw, opts = {})
    @user, @new_raw, @opts = user, new_raw, opts
    return false if not should_revise?

    @post.acting_user = @user
    revise_post
    update_category_description
    post_process_post
    @post.advance_draft_sequence
    true
  end

  private

  def should_revise?
    @post.raw != @new_raw
  end

  def revise_post
    if should_create_new_version?
      revise_and_create_new_version
    else
      revise_without_creating_a_new_version
    end
  end

  def get_revised_at
    @opts[:revised_at] || Time.now
  end

  def should_create_new_version?
    (@post.last_editor_id != @user.id) or
      ((get_revised_at - @post.last_version_at) > SiteSetting.ninja_edit_window.to_i) or
      @opts[:force_new_version] == true
  end

  def revise_and_create_new_version
    Post.transaction do
      @post.cached_version = @post.version + 1
      @post.last_version_at = get_revised_at
      update_post
      EditRateLimiter.new(@post.user).performed! unless @opts[:bypass_rate_limiter] == true
      bump_topic unless @opts[:bypass_bump]
    end
  end

  def revise_without_creating_a_new_version
    @post.skip_version do
      update_post
    end
  end

  def bump_topic
    unless Post.where('post_number > ? and topic_id = ?', @post.post_number, @post.topic_id).exists?
      @post.topic.update_column(:bumped_at, Time.now)
    end
  end

  def update_post
    @post.raw = @new_raw
    @post.updated_by = @user
    @post.last_editor_id = @user.id

    if @post.hidden && @post.hidden_reason_id == Post.hidden_reasons[:flag_threshold_reached]
      @post.hidden = false
      @post.hidden_reason_id = nil
      @post.topic.update_attributes(visible: true)

      PostAction.clear_flags!(@post, -1)
    end

    @post.extract_quoted_post_numbers
    @post.save
    @post.save_reply_relationships
  end

  def update_category_description
    # If we're revising the first post, we might have to update the category description
    return unless @post.post_number == 1

    # Is there a category with our topic id?
    category = Category.where(topic_id: @post.topic_id).first
    return unless category.present?

    # If found, update its description
    body = @post.cooked
    matches = body.scan(/\<p\>(.*)\<\/p\>/)
    if matches && matches[0] && matches[0][0]
      new_description = matches[0][0]
      new_description = nil if new_description == I18n.t("category.replace_paragraph")
      category.update_column(:description, new_description)
      @category_changed = category
    end
  end

  def post_process_post
    @post.invalidate_oneboxes = true
    @post.trigger_post_process
  end
end
