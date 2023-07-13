# frozen_string_literal: true

class BookmarksController < ApplicationController
  requires_login

  def create
    params.require(:bookmarkable_id)
    params.require(:bookmarkable_type)
    params.permit(
      :bookmarkable_id,
      :bookmarkable_type,
      :name,
      :reminder_at,
      :auto_delete_preference,
    )

    RateLimiter.new(
      current_user,
      "create_bookmark",
      SiteSetting.max_bookmarks_per_day,
      1.day.to_i,
    ).performed!

    bookmark_manager = BookmarkManager.new(current_user)
    bookmark =
      bookmark_manager.create_for(
        bookmarkable_id: params[:bookmarkable_id],
        bookmarkable_type: params[:bookmarkable_type],
        name: params[:name],
        reminder_at: params[:reminder_at],
        options: {
          auto_delete_preference: params[:auto_delete_preference],
        },
      )

    return render json: success_json.merge(id: bookmark.id) if bookmark_manager.errors.empty?

    render json: failed_json.merge(errors: bookmark_manager.errors.full_messages), status: 400
  end

  def destroy
    params.require(:id)
    destroyed_bookmark = BookmarkManager.new(current_user).destroy(params[:id])
    render json:
             success_json.merge(BookmarkManager.bookmark_metadata(destroyed_bookmark, current_user))
  end

  def update
    params.require(:id)
    params.permit(:id, :name, :reminder_at, :auto_delete_preference)

    bookmark_manager = BookmarkManager.new(current_user)
    bookmark_manager.update(
      bookmark_id: params[:id],
      name: params[:name],
      reminder_at: params[:reminder_at],
      options: {
        auto_delete_preference: params[:auto_delete_preference],
      },
    )

    return render json: success_json if bookmark_manager.errors.empty?

    render json: failed_json.merge(errors: bookmark_manager.errors.full_messages), status: 400
  end

  def toggle_pin
    params.require(:bookmark_id)

    bookmark_manager = BookmarkManager.new(current_user)
    bookmark_manager.toggle_pin(bookmark_id: params[:bookmark_id])

    return render json: success_json if bookmark_manager.errors.empty?

    render json: failed_json.merge(errors: bookmark_manager.errors.full_messages), status: 400
  end
end
