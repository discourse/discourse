# frozen_string_literal: true

class BookmarksBulkAction
  def initialize(user, bookmark_ids, operation, options = {})
    @user = user
    @bookmark_ids = bookmark_ids
    @operation = operation
    @changed_ids = []
    @options = options
  end

  def self.operations
    @operations ||= %w[clear_reminder delete]
  end

  def perform!
    if BookmarksBulkAction.operations.exclude?(@operation[:type])
      raise Discourse::InvalidParameters.new(:operation)
    end

    case @operation[:type]
    when "clear_reminder"
      clear_reminder
    when "delete"
      delete
    end

    @changed_ids.sort
  end

  private

  def delete
    @bookmark_ids.each do |bookmark_id|
      if guardian.can_delete?(bookmark_id)
        BookmarkManager.new(@user).destroy(bookmark_id)
        @changed_ids << bookmark_id
      end
    end
  end

  def clear_reminder
    bookmarks.each do |bookmark|
      if guardian.can_edit?(bookmark)
        bookmark.clear_reminder!(force_clear_reminder_at: true)
        @changed_ids << bookmark.id
      else
        raise Discourse::InvalidAccess.new
      end
    end
  end

  def guardian
    @guardian ||= Guardian.new(@user)
  end

  def bookmarks
    @bookmarks ||= Bookmark.where(id: @bookmark_ids)
  end
end
