# frozen_string_literal: true

class BookmarksController < ApplicationController
  requires_login

  def create
    params.require(:post_id)

    existing_bookmark = Bookmark.find_by(post_id: params[:post_id], user_id: current_user.id)
    if existing_bookmark.present?
      return render json: failed_json.merge(errors: [I18n.t("bookmarks.errors.already_bookmarked_post")]), status: 422
    end

    bookmark = Bookmark.create(
      user_id: current_user.id,
      topic_id: params[:topic_id],
      post_id: params[:post_id],
      name: params[:name],
      reminder_type: Bookmark.reminder_types[params[:reminder_type].to_sym],
      reminder_at: params[:reminder_at]
    )

    return render json: success_json if bookmark.save
    render json: failed_json.merge(errors: bookmark.errors.full_messages), status: 400
  end
end
