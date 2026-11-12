# frozen_string_literal: true

class PostReadersController < ApplicationController
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
