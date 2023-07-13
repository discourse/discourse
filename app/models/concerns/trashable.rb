# frozen_string_literal: true

module Trashable
  extend ActiveSupport::Concern

  included do
    default_scope { where(deleted_at: nil) }
    scope :with_deleted, -> { unscope(where: :deleted_at) }
    scope :only_deleted, -> { with_deleted.where.not(deleted_at: nil) }

    belongs_to :deleted_by, class_name: "User"
  end

  def trashed?
    deleted_at.present?
  end

  def trash!(trashed_by = nil)
    # note, an argument could be made that the column should probably called trashed_at
    # however, deleted_at is the terminology used in the UI
    #
    # we could hijack use a delete! and delete - redirecting the originals elsewhere, but that is
    # confusing as well. So for now, we go with trash!
    #
    trash_update(DateTime.now, trashed_by.try(:id))
  end

  def recover!
    trash_update(nil, nil)
  end

  private

  def trash_update(deleted_at, deleted_by_id)
    self.update_columns(deleted_at: deleted_at, deleted_by_id: deleted_by_id)
  end
end
