# frozen_string_literal: true

class ThemeColorScheme < ActiveRecord::Base
  belongs_to :theme
  belongs_to :color_scheme, dependent: :destroy
end

# == Schema Information
#
# Table name: theme_color_schemes
#
#  id              :bigint           not null, primary key
#  theme_id        :integer          not null
#  color_scheme_id :integer          not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_theme_color_schemes_on_color_scheme_id  (color_scheme_id) UNIQUE
#  index_theme_color_schemes_on_theme_id         (theme_id) UNIQUE
#
