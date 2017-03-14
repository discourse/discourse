class CustomEmoji < ActiveRecord::Base
  belongs_to :upload

  validates :name, presence: true, uniqueness: true
  validates :upload_id, presence: true
end
