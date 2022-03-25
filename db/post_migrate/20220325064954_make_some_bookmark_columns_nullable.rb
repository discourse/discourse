# frozen_string_literal: true

class MakeSomeBookmarkColumnsNullable < ActiveRecord::Migration[6.1]
  def change
    change_column_null :bookmarks, :post_id, true
  end
end
