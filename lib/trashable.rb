module Trashable
  extend ActiveSupport::Concern

  included do
    default_scope where(with_deleted_scope_sql)

    # scope unscoped does not work
  end


  module ClassMethods
    def with_deleted
      # lifted from acts_as_paranoid, works around https://github.com/rails/rails/issues/4306
      #
      # with this in place Post.limit(10).with_deleted, will work as expected
      #
      scope = self.scoped.with_default_scope
      scope.where_values.delete(with_deleted_scope_sql)
      scope
    end

    def with_deleted_scope_sql
      scoped.table[:deleted_at].eq(nil).to_sql
    end
  end

  def trash!
    # note, an argument could be made that the column should probably called trashed_at
    # however, deleted_at is the terminology used in the UI
    #
    # we could hijack use a delete! and delete - redirecting the originals elsewhere, but that is
    # confusing as well. So for now, we go with trash!
    #
    update_column(:deleted_at, DateTime.now)
  end

  def recover!
    # see: https://github.com/rails/rails/issues/8436
    #
    # Fixed in Rails 4
    #
    self.class.unscoped.update_all({deleted_at: nil}, id: self.id)
    raw_write_attribute :deleted_at, nil
  end

end
