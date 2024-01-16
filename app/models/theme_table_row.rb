# frozen_string_literal: true

class ThemeTableRow < ActiveRecord::Base
  validates :theme_table_id, presence: true
  validates :data, presence: true

  belongs_to :theme_table
end
