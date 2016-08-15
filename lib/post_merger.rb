class PostMerger
  class CannotMergeError < StandardError; end

  def initialize(user, posts)
    @user = user
    @posts = posts
  end

  def merge
    return unless ensure_at_least_two_posts
    ensure_same_topic!
    ensure_same_user!

    guardian = Guardian.new(@user)
    ensure_staff_user!(guardian)

    posts = @posts.sort_by do |post|
      guardian.ensure_can_delete!(post)
      post.post_number
    end

    post_content = posts.map(&:raw)
    post = posts.pop

    changes = {
      raw: post_content.join("\n\n"),
      edit_reason: I18n.t("merge_posts.edit_reason", count: posts.length, username: @user.username)
    }

    revisor = PostRevisor.new(post, post.topic)

    revisor.revise!(@user, changes) do
      posts.each { |p| PostDestroyer.new(@user, p).destroy }
    end
  end

  private

  def ensure_at_least_two_posts
    @posts.count >= 2
  end

  def ensure_same_topic!
    unless @posts.map(&:topic_id).uniq.length == 1
      raise CannotMergeError.new(I18n.t("merge_posts.errors.different_topics"))
    end
  end

  def ensure_same_user!
    unless @posts.map(&:user_id).uniq.length == 1
      raise CannotMergeError.new(I18n.t("merge_posts.errors.different_users"))
    end
  end

  def ensure_staff_user!(guardian)
    raise Discourse::InvalidAccess unless guardian.is_staff?
  end
end
