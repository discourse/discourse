# frozen_string_literal: true

class BookmarksController < ApplicationController
  requires_login

  def create
    if SiteSetting.use_polymorphic_bookmarks
      params.require(:bookmarkable_id)
      params.require(:bookmarkable_type)
    else
      params.require(:post_id)
    end

    RateLimiter.new(
      current_user, "create_bookmark", SiteSetting.max_bookmarks_per_day, 1.day.to_i
    ).performed!

    bookmark_manager = BookmarkManager.new(current_user)

    create_params = {
      name: params[:name],
      reminder_at: params[:reminder_at],
      options: {
        auto_delete_preference: params[:auto_delete_preference] || 0
      }
    }

    if SiteSetting.use_polymorphic_bookmarks
      bookmark = bookmark_manager.create_for(
        **create_params.merge(
          bookmarkable_id: params[:bookmarkable_id],
          bookmarkable_type: params[:bookmarkable_type]
        )
      )
    else
      bookmark = bookmark_manager.create(
        **create_params.merge(
          post_id: params[:post_id],
          for_topic: params[:for_topic] == "true",
        )
      )
    end

    if bookmark_manager.errors.empty?
      return render json: success_json.merge(id: bookmark.id)
    end

    render json: failed_json.merge(errors: bookmark_manager.errors.full_messages), status: 400
  end

  def destroy
    params.require(:id)
    destroyed_bookmark = BookmarkManager.new(current_user).destroy(params[:id])

    success_data = {}
    if SiteSetting.use_polymorphic_bookmarks
      if destroyed_bookmark.bookmarkable_type == "Topic"
        success_data[:topic_bookmarked] = Bookmark.for_user_in_topic(current_user.id, destroyed_bookmark.bookmarkable.id).exists?
      elsif destroyed_bookmark.bookmarkable_type == "Post"
        success_data[:topic_bookmarked] = Bookmark.for_user_in_topic(current_user.id, destroyed_bookmark.bookmarkable.topic.id).exists?
      end
    else
      success_data[:topic_bookmarked] = Bookmark.for_user_in_topic(current_user.id, destroyed_bookmark.topic.id).exists?
    end

    render json: success_json.merge(success_data)
  end

  def update
    params.require(:id)

    bookmark_manager = BookmarkManager.new(current_user)
    bookmark_manager.update(
      bookmark_id: params[:id],
      name: params[:name],
      reminder_at: params[:reminder_at],
      options: {
        auto_delete_preference: params[:auto_delete_preference] || 0
      }
    )

    if bookmark_manager.errors.empty?
      return render json: success_json
    end

    render json: failed_json.merge(errors: bookmark_manager.errors.full_messages), status: 400
  end

  def toggle_pin
    params.require(:bookmark_id)

    bookmark_manager = BookmarkManager.new(current_user)
    bookmark_manager.toggle_pin(bookmark_id: params[:bookmark_id])

    if bookmark_manager.errors.empty?
      return render json: success_json
    end

    render json: failed_json.merge(errors: bookmark_manager.errors.full_messages), status: 400
  end
end
