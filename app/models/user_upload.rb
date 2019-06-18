# frozen_string_literal: true

class UserUpload < ActiveRecord::Base
  belongs_to :upload
  belongs_to :user
end

# == Schema Information
#
# Table name: user_uploads
#
#  id         :bigint           not null, primary key
#  upload_id  :integer          not null
#  user_id    :integer          not null
#  created_at :datetime         not null
#
# Indexes
#
#  index_user_uploads_on_upload_id_and_user_id  (upload_id,user_id) UNIQUE
#  index_user_uploads_on_user_id_and_upload_id  (user_id,upload_id)
#
