class ColorSchemeColor < ActiveRecord::Base
  belongs_to :color_scheme

  validates :hex, format: { with: /\A([0-9a-fA-F]{3}|[0-9a-fA-F]{6})\z/ }
end

# == Schema Information
#
# Table name: color_scheme_colors
#
#  id              :integer          not null, primary key
#  name            :string(255)      not null
#  hex             :string(255)      not null
#  color_scheme_id :integer          not null
#  created_at      :datetime
#  updated_at      :datetime
#
# Indexes
#
#  index_color_scheme_colors_on_color_scheme_id  (color_scheme_id)
#
