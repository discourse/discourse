# frozen_string_literal: true

class UpdateDeprecatedIconNames < ActiveRecord::Migration[6.0]
  def up
    migrate_value("up")
  end

  def down
    migrate_value("down")
  end

  def migrate_value(dir)
    icons = File.open("#{Rails.root}/db/migrate/20200517140915_fa4_renames.json", "r:UTF-8") { |f| JSON.parse(f.read) }

    icons.each do |key, value|
      from = dir == "up" ? key : value
      to = dir == "up" ? value : key
      execute <<~SQL
        UPDATE badges
        SET icon = '#{to}'
        WHERE icon = '#{from}' OR icon = 'fa-#{from}'
      SQL

      execute <<~SQL
        UPDATE groups
        SET flair_icon = '#{to}'
        WHERE flair_icon = '#{from}' OR flair_icon = 'fa-#{from}'
      SQL

    end
  end
end
