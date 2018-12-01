class AdminUploadsSerializer < ApplicationSerializer

  attributes :uploads_used, :uploads_free
  has_many :uploads, serializer: AdminUploadSerializer, embed: :objects

  def uploads_used
    object.uploads_used
  end

  def uploads_free
    object.uploads_free
  end
end
