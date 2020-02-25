# frozen_string_literal: true

class UserExport < ActiveRecord::Base
  belongs_to :user
  belongs_to :upload, dependent: :destroy
  belongs_to :topic, dependent: :destroy

  DESTROY_CREATED_BEFORE = 2.days.ago

  def self.remove_old_exports
    UserExport.where('created_at < ?', DESTROY_CREATED_BEFORE).find_each do |user_export|
      UserExport.transaction do
        begin
          Post.where(topic_id: user_export.topic_id).find_each { |p| p.destroy! }
          user_export.destroy!
        rescue => e
          Rails.logger.warn("Failed to remove user_export record with id #{user_export.id}: #{e.message}\n#{e.backtrace.join("\n")}")
        end
      end
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
#  topic_id   :integer
#
