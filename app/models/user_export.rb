class UserExport < ActiveRecord::Base
  belongs_to :user
  belongs_to :upload, dependent: :destroy

  def self.remove_old_exports
    UserExport.where('created_at < ?', 2.days.ago).find_each do |user_export|
      user_export.destroy!
    end
  end

  def self.base_directory
    File.join(Rails.root, "public", "uploads", "csv_exports", RailsMultisite::ConnectionManagement.current_db)
  end

end

# == Schema Information
#
# Table name: user_exports
#
#  id         :integer          not null, primary key
#  file_name  :string           not null
#  user_id    :integer          not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  upload_id  :integer
#
