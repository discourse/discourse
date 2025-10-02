# frozen_string_literal: true

class ColorSchemeColor < ActiveRecord::Base
  self.ignored_columns = [
    "dark_hex", # TODO: Remove when 20250821155127_drop_dark_hex_from_color_scheme_color has been promoted to pre-deploy
  ]

  belongs_to :color_scheme, -> { unscope(where: :remote_copy) }

  validates :hex, format: { with: /\A([0-9a-fA-F]{3}|[0-9a-fA-F]{6})\z/ }
  validate :no_edits_for_remote_copies, on: :update

  def hex_with_hash
    "##{hex}"
  end

  private

  def no_edits_for_remote_copies
    if color_scheme&.remote_copy && will_save_change_to_hex?
      errors.add(:base, I18n.t("color_schemes.errors.cannot_edit_remote_copies"))
    end
  end
end

# == Schema Information
#
# Table name: color_scheme_colors
#
#  id              :integer          not null, primary key
#  hex             :string           not null
#  name            :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  color_scheme_id :integer          not null
#
# Indexes
#
#  index_color_scheme_colors_on_color_scheme_id  (color_scheme_id)
#
