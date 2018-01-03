class AddOriginToUploads < ActiveRecord::Migration[4.2]
  def change
    add_column :uploads, :origin, :string, limit: 1000
  end
end
