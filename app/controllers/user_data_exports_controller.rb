# frozen_string_literal: true

class UserDataExportsController < ApplicationController
  requires_login
  before_action :fetch_user

  EXPORT_LIMIT = 500

  def show
    render json: {
      user: {
        id: @user.id,
        username: @user.username,
        email: @user.email,
        created_at: @user.created_at,
        trust_level: @user.trust_level,
      },
      stats: {
        post_count: @user.post_count,
        topic_count: @user.topic_count,
        likes_given: @user.user_stat&.likes_given,
        likes_received: @user.user_stat&.likes_received,
        time_read: @user.user_stat&.time_read,
      },
      drafts: serialize_drafts,
      bookmarks: serialize_bookmarks,
    }
  end

  private

  def fetch_user
    @user = User.find_by!(username: params[:username])
  end

  def serialize_drafts
    Draft
      .where(user_id: @user.id)
      .order(updated_at: :desc)
      .limit(EXPORT_LIMIT)
      .map do |d|
        data =
          begin
            JSON.parse(d.data)
          rescue JSON::ParserError
            {}
          end
        { key: d.draft_key, data: data, updated_at: d.updated_at }
      end
  end

  def serialize_bookmarks
    Bookmark
      .where(user_id: @user.id)
      .order(created_at: :desc)
      .limit(EXPORT_LIMIT)
      .map { |b| { id: b.id, name: b.name, reminder_at: b.reminder_at, created_at: b.created_at } }
  end
end
