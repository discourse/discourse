class AddOriginToUploads < ActiveRecord::Migration
  def change
    add_column :uploads, :origin, :string, limit: 1000
  end
end
