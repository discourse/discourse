# frozen_string_literal: true

class PostReadersController < ApplicationController
  requires_login

  def index
    post = Post.includes(topic: %i[allowed_groups]).find(params[:id])
    read_state = post.topic.allowed_groups.any? { |g| g.publish_read_state? && g.users.include?(current_user) }
    raise Discourse::InvalidAccess unless read_state

    readers = User
      .joins(:topic_users)
      .where.not(topic_users: { last_read_post_number: nil })
      .where('topic_users.topic_id = ? AND topic_users.last_read_post_number >= ?', post.topic_id, post.post_number)
      .where.not(id: [current_user.id, post.user_id])

    readers = readers.map do |r|
      {
        id: r.id, avatar_template: r.avatar_template,
        username: r.username,
        username_lower: r.username_lower
      }
    end

    render_json_dump(post_readers: readers)
  end
end
