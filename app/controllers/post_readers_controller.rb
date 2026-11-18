# frozen_string_literal: true

class PostReadersController < ApplicationController
  STAFF_REPORT_LIMIT = 200

  requires_login

  def index
    post = Post.includes(topic: %i[topic_allowed_groups topic_allowed_users]).find(params[:id])
    guardian.ensure_can_see!(post)
    ensure_can_see_readers!(post)

    readers =
      User
        .real
        .where(staged: false)
        .where.not(id: post.user_id)
        .joins(:topic_users)
        .where.not(topic_users: { last_read_post_number: nil })
        .where(
          "topic_users.topic_id = ? AND topic_users.last_read_post_number >= ?",
          post.topic_id,
          post.post_number,
        )

    readers = readers.where("admin OR moderator") if post.whisper?

    readers =
      readers.map do |r|
        {
          id: r.id,
          avatar_template: r.avatar_template,
          username: r.username,
          username_lower: r.username_lower,
        }
      end

    render_json_dump(post_readers: readers)
  end

  def staff_report
    raise Discourse::NotFound unless SiteSetting.enable_post_readers_modal
    guardian.ensure_is_staff!

    post = Post.includes(:topic).find(params[:id])
    guardian.ensure_can_see!(post)
    if post.post_type != Post.types[:regular] || post.topic.private_message?
      raise Discourse::NotFound
    end

    # Moving posts can create placeholder timings of one millisecond.
    timings =
      PostTiming
        .where(topic_id: post.topic_id, post_number: post.post_number)
        .where("post_timings.msecs > 1")
        .joins(:user)
        .merge(User.real.where(staged: false))
        .joins(<<~SQL)
          LEFT JOIN topic_users ON topic_users.topic_id = post_timings.topic_id
            AND topic_users.user_id = post_timings.user_id
        SQL
        .order(Arel.sql("topic_users.last_visited_at DESC NULLS LAST, users.id"))
        .limit(STAFF_REPORT_LIMIT + 1)
        .select("post_timings.user_id", "topic_users.last_visited_at")
        .preload(:user)
        .to_a

    readers =
      timings
        .first(STAFF_REPORT_LIMIT)
        .map do |timing|
          {
            username: timing.user.username,
            avatar_template: timing.user.avatar_template,
            last_visited_at: timing.last_visited_at,
          }
        end
    render json: {
             readers:,
             truncated: timings.length > STAFF_REPORT_LIMIT,
             limit: STAFF_REPORT_LIMIT,
           }
  end

  private

  def ensure_can_see_readers!(post)
    allowed_groups = post.topic.allowed_groups.to_a

    show_readers =
      allowed_groups.all? { |group| guardian.can_see_group_members?(group) } &&
        GroupUser
          .where(user: current_user)
          .joins(:group)
          .where(groups: { id: allowed_groups.map(&:id), publish_read_state: true })
          .exists?

    raise Discourse::InvalidAccess unless show_readers
  end
end
