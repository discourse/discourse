# frozen_string_literal: true

class PostMerger
  class CannotMergeError < StandardError; end

  def initialize(user, posts)
    @user = user
    @posts = posts
  end

  def merge
    return if @posts.count < 2

    ensure_same_topic!
    ensure_same_user!

    guardian = Guardian.new(@user)
    ensure_can_merge!(guardian)

    posts = @posts.sort_by do |post|
      guardian.ensure_can_delete!(post)
      post.post_number
    end

    post_content = posts.map(&:raw)
    post = posts.pop

    merged_post_raw = post_content.join("\n\n")
    changes = {
      raw: merged_post_raw,
      edit_reason: I18n.t("merge_posts.edit_reason", count: posts.length, username: @user.username)
    }

    ensure_max_post_length!(merged_post_raw)
    PostRevisor.new(post, post.topic).revise!(@user, changes) do
      posts.each { |p| PostDestroyer.new(@user, p).destroy }
    end
  end

  private

  def ensure_same_topic!
    if @posts.map(&:topic_id).uniq.size != 1
      raise CannotMergeError.new(I18n.t("merge_posts.errors.different_topics"))
    end
  end

  def ensure_same_user!
    if @posts.map(&:user_id).uniq.size != 1
      raise CannotMergeError.new(I18n.t("merge_posts.errors.different_users"))
    end
  end

  def ensure_can_merge!(guardian)
    raise Discourse::InvalidAccess unless guardian.can_moderate_topic?(@posts[0].topic)
  end

  def ensure_max_post_length!(raw)
    value = StrippedLengthValidator.get_sanitized_value(raw)
    if value.size > SiteSetting.max_post_length
      raise CannotMergeError.new(I18n.t("merge_posts.errors.max_post_length"))
    end
  end
end
