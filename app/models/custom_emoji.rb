# frozen_string_literal: true

class CustomEmoji < ActiveRecord::Base
  belongs_to :upload

  validates :name, presence: true, uniqueness: true
  validates :upload_id, presence: true
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
#
# Indexes
#
#  index_custom_emojis_on_name  (name) UNIQUE
#
