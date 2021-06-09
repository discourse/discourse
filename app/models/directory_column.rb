# frozen_string_literal: true

class DirectoryColumn < ActiveRecord::Base
  self.inheritance_column = nil

  enum type: { automatic: 0, user_field: 1, plugin: 2 }

  belongs_to :user_field
end
