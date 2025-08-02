# frozen_string_literal: true

class RemoveUpdatedTranslationOverrides < ActiveRecord::Migration[7.0]
  def up
    execute <<~SQL
      DELETE
      FROM translation_overrides
      WHERE translation_key IN (
        'js.user.messages.read_more_group_pm_MF',
        'js.user.messages.read_more_personal_pm_MF',
        'js.topic.read_more_MF',
        'js.topic.bumped_at_title_MF',
        'js.topic.read_more_in_category',
        'js.topic.read_more'
      )
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
