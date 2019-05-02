# frozen_string_literal: true

class ChildTheme < ActiveRecord::Base
  belongs_to :parent_theme, class_name: 'Theme'
  belongs_to :child_theme, class_name: 'Theme'

  validate :child_validations

  private

  def child_validations
    if Theme.where(
         "(component IS true AND id = :parent) OR (component IS false AND id = :child)",
         parent: parent_theme_id, child: child_theme_id
       ).exists?
      errors.add(:base, I18n.t("themes.errors.no_multilevels_components"))
    end
  end
end

# == Schema Information
#
# Table name: child_themes
#
#  id              :integer          not null, primary key
#  parent_theme_id :integer
#  child_theme_id  :integer
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_child_themes_on_child_theme_id_and_parent_theme_id  (child_theme_id,parent_theme_id) UNIQUE
#  index_child_themes_on_parent_theme_id_and_child_theme_id  (parent_theme_id,child_theme_id) UNIQUE
#
