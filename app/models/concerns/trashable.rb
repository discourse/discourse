module Trashable
  extend ActiveSupport::Concern

  included do
    default_scope { where(with_deleted_scope_sql) }

    # scope unscoped does not work
    belongs_to :deleted_by, class_name: 'User'
  end


  module ClassMethods
    def with_deleted
      # lifted from acts_as_paranoid, works around https://github.com/rails/rails/issues/4306
      #
      # with this in place Post.limit(10).with_deleted, will work as expected
      #
      scope = self.all

      scope.where_values.delete(with_deleted_scope_sql)
      scope
    end

    def with_deleted_scope_sql
      all.table[:deleted_at].eq(nil).to_sql
    end
  end

  def trashed?
    deleted_at.present?
  end

  def trash!(trashed_by=nil)
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
      # see: https://github.com/rails/rails/issues/8436
      #
      # Fixed in Rails 4
      #
      self.class.unscoped.where(id: self.id).update_all(deleted_at: deleted_at, deleted_by_id: deleted_by_id)
      raw_write_attribute :deleted_at, deleted_at
      raw_write_attribute :deleted_by_id, deleted_by_id
    end

end
