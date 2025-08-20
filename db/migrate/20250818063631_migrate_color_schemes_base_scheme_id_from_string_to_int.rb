# frozen_string_literal: true

class MigrateColorSchemesBaseSchemeIdFromStringToInt < ActiveRecord::Migration[8.0]
  NAMES_TO_ID_MAP = {
    "default" => -1,
    "Light" => -1,
    "Dark" => -2,
    "dark" => -2,
    "Neutral" => -3,
    "Grey Amber" => -4,
    "Shades of Blue" => -5,
    "Latte" => -6,
    "Summer" => -7,
    "Dark Rose" => -8,
    "WCAG" => -9,
    "WCAG Dark" => -10,
    "Dracula" => -11,
    "Solarized Light" => -12,
    "Solarized Dark" => -13,
  }
  def up
    return if column_exists?(:color_schemes, :base_scheme_id, :integer)

    NAMES_TO_ID_MAP.each { |name, id| execute <<-SQL }
      UPDATE color_schemes
      SET base_scheme_id = #{id}
      WHERE base_scheme_id = '#{name}'
      AND base_scheme_id IS NOT NULL
    SQL

    execute <<-SQL
      ALTER TABLE color_schemes
      ALTER COLUMN base_scheme_id TYPE integer
      USING (base_scheme_id::integer);
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
