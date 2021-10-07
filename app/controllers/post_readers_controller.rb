# frozen_string_literal: true

class PostReadersController < ApplicationController
  requires_login

  def index
    post = Post.includes(topic: %i[topic_allowed_groups]).find(params[:id])

    if !@guardian.publish_read_state?(post.topic, current_user)
      raise Discourse::InvalidAccess
    end

    is_first_post = post.post_number == 1

    readers = User
      .real
      .where(staged: false)
      .where.not(id: post.user_id)
      .includes(:topic_users)
      .where.not(topic_users: { last_read_post_number: nil })
      .where('topic_users.topic_id = ? AND topic_users.last_read_post_number >= ?', post.topic_id, post.post_number)

    readers = readers.order("topic_users.first_visited_at ASC") if is_first_post
    readers = readers.where('admin OR moderator') if post.whisper?

    readers = readers.map do |r|
      attrs = {
        id: r.id,
        avatar_template: r.avatar_template,
        username: r.username,
        username_lower: r.username_lower,
      }

      if is_first_post
        attrs[:first_visited_at] = r.topic_users.first.first_visited_at
      end

      attrs
    end

    render_json_dump(post_readers: readers)
  end
end
