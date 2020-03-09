# frozen_string_literal: true

class BookmarksController < ApplicationController
  requires_login

  def create
    params.require(:post_id)

    bookmark_manager = BookmarkManager.new(current_user)
    bookmark = bookmark_manager.create(
      post_id: params[:post_id],
      name: params[:name],
      reminder_type: params[:reminder_type],
      reminder_at: params[:reminder_at]
    )

    if bookmark_manager.errors.empty?
      return render json: success_json
    end

    render json: failed_json.merge(errors: bookmark_manager.errors.full_messages), status: 400
  end

  def destroy
    params.require(:id)
    BookmarkManager.new(current_user).destroy(params[:id])
    render json: success_json
  end
end
