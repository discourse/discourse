# frozen_string_literal: true

class MarkBadgesForBeginners < ActiveRecord::Migration[6.0]
  def up
    execute <<~SQL
      UPDATE badges
      SET for_beginners = true
      WHERE name IN (
        'Autobiographer',
        'Editor',
        'First Like',
        'First Share',
        'First Flag',
        'First Link',
        'First Quote',
        'Read Guidelines',
        'Reader',
        'First Mention',
        'First Emoji',
        'First Onebox',
        'First Reply By Email',
        'Wiki Editor',
        'Certified',
        'Licensed',
        'First Reaction',
        'Welcome'
      )
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
