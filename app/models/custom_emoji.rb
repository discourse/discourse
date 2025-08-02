# frozen_string_literal: true

class CustomEmoji < ActiveRecord::Base
  belongs_to :upload
  belongs_to :user

  has_many :upload_references, as: :target, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :upload_id, presence: true
  validates :user_id, presence: true

  before_validation :set_default_user_id, on: :create

  after_save do
    if saved_change_to_upload_id?
      UploadReference.ensure_exist!(upload_ids: [self.upload_id], target: self)
    end
  end

  private

  def set_default_user_id
    self.user_id ||= Discourse.system_user.id
  end
end

# == Schema Information
#
# Table name: custom_emojis
#
#  id         :integer          not null, primary key
#  name       :string           not null
#  upload_id  :integer          not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  group      :string(20)
#  user_id    :integer          default(-1), not null
#
# Indexes
#
#  index_custom_emojis_on_name  (name) UNIQUE
#
