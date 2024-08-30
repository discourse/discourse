# frozen_string_literal: true

class CategoryModerationGroup < ActiveRecord::Base
  belongs_to :category
  belongs_to :group
end
