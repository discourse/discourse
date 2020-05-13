# frozen_string_literal: true

class UpdateDeprecatedBadgeIconNames < ActiveRecord::Migration[6.0]
  def up
    migrate_value("up")
  end

  def down
    migrate_value("down")
  end

  def migrate_value(dir)
    icons = File.open("#{Rails.root}/db/migrate/20200513013022_fa4_renames.json", "r:UTF-8") { |f| JSON.parse(f.read) }

    icons.each do |key, value|
      from = dir == "up" ? key : value
      to = dir == "up" ? value : key
      execute <<~SQL
        UPDATE badges
        SET icon = '#{to}'
        WHERE icon = '#{from}'
      SQL
    end
  end
end
