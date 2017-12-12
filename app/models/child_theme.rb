class ChildTheme < ActiveRecord::Base
  belongs_to :parent_theme, class_name: 'Theme'
  belongs_to :child_theme, class_name: 'Theme'
end

# == Schema Information
#
# Table name: child_themes
#
#  id              :integer          not null, primary key
#  parent_theme_id :integer
#  child_theme_id  :integer
#  created_at      :datetime
#  updated_at      :datetime
#
# Indexes
#
#  index_child_themes_on_child_theme_id_and_parent_theme_id  (child_theme_id,parent_theme_id) UNIQUE
#  index_child_themes_on_parent_theme_id_and_child_theme_id  (parent_theme_id,child_theme_id) UNIQUE
#
