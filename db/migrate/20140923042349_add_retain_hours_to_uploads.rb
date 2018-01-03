class AddRetainHoursToUploads < ActiveRecord::Migration[4.2]
  def change
    add_column :uploads, :retain_hours, :integer
  end
end
