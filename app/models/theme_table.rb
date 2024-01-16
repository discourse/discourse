# frozen_string_literal: true

class ThemeTable < ActiveRecord::Base
  validates :theme_id, presence: true
  validates :name, presence: true, uniqueness: { scope: :theme_id }

  belongs_to :theme
  has_many :theme_table_rows, dependent: :destroy
end
