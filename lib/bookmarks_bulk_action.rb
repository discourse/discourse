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
    unless BookmarksBulkAction.operations.include?(@operation[:type])
      raise Discourse::InvalidParameters.new(:operation)
    end
    # careful these are private methods, we need send
    send(@operation[:type])
    @changed_ids.sort
  end

  private

  def delete
    @bookmark_ids.each do |b_id|
      if guardian.can_delete?(b_id)
        BookmarkManager.new(@user).destroy(b_id)
        @changed_ids << b_id
      end
    end
  end

  def clear_reminder
    bookmarks.each do |b|
      if guardian.can_edit?(b)
        BookmarkReminderNotificationHandler.new(b).clear_reminder
        @changed_ids << b.id
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
