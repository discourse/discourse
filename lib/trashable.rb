module Trashable
  extend ActiveSupport::Concern

  included do
    default_scope where(with_deleted_scope_sql)
  end


  module ClassMethods
    def with_deleted
      # lifted from acts_as_paranoid, works around http://stackoverflow.com/questions/8734669/rails-3-1-3-unscoped-scope
      scope = self.scoped.with_default_scope
      scope.where_values.delete(with_deleted_scope_sql)
      scope
    end

    def with_deleted_scope_sql
      self.scoped.table[:deleted_at].eq(nil).to_sql
    end
  end

  def trash!
    self.update_column(:deleted_at, DateTime.now)
  end

  def recover!
    # see: https://github.com/rails/rails/issues/8436
    self.class.unscoped.update_all({deleted_at: nil}, id: self.id)
    raw_write_attribute :deleted_at, nil
  end

end
