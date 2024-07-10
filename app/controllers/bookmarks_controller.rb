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

  def bulk
    if params[:bookmark_ids].present?
      unless Array === params[:bookmark_ids]
        raise Discourse::InvalidParameters.new(
                "Expecting bookmark_ids to contain a list of bookmark ids",
              )
      end
      bookmark_ids = params[:bookmark_ids].map { |t| t.to_i }
    else
      raise ActionController::ParameterMissing.new(:bookmark_ids)
    end

    operation = params.require(:operation).permit(:type).to_h.symbolize_keys

    raise ActionController::ParameterMissing.new(:operation_type) if operation[:type].blank?
    operator = BookmarksBulkAction.new(current_user, bookmark_ids, operation)
    changed_bookmark_ids = operator.perform!
    render_json_dump bookmark_ids: changed_bookmark_ids
  end
end
