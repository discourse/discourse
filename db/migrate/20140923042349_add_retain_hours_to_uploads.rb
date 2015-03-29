class AddRetainHoursToUploads < ActiveRecord::Migration
  def change
    add_column :uploads, :retain_hours, :integer
  end
end
