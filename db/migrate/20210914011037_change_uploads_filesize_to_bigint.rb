# frozen_string_literal: true

class ChangeUploadsFilesizeToBigint < ActiveRecord::Migration[6.1]
  def change
    change_column :uploads, :filesize, :bigint
  end
end
