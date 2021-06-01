# frozen_string_literal: true

class DirectoryColumn < ActiveRecord::Base
  belongs_to :user_field
  validates :position, presence: true, uniqueness: true
end
