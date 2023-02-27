# frozen_string_literal: true

class UpdateNarrativeBadgeIcons < ActiveRecord::Migration[7.0]
  def change
    execute <<~SQL
      UPDATE badges
      SET icon = 'stamp'
      WHERE
        name IN ('#{DiscourseNarrativeBot::NewUserNarrative::BADGE_NAME}', '#{DiscourseNarrativeBot::AdvancedUserNarrative::BADGE_NAME}')
    SQL
  end
end
