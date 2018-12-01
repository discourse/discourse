class AdminUploadSerializer < ApplicationSerializer
  attributes :original_filename, :user,
             :url, :extension, :created_at

  def user
    User.find(object.user_id)
  end
end
