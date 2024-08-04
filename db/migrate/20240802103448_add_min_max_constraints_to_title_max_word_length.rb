# frozen_string_literal: true
class AddMinMaxConstraintsToTitleMaxWordLength < ActiveRecord::Migration[7.1]
  def up
    DB.exec <<~SQL
        UPDATE site_settings SET value = '255' WHERE name = 'title_max_word_length' and value::int > 255;
      SQL
    DB.exec <<~SQL
        UPDATE site_settings SET value = '1' WHERE name = 'title_max_word_length' and value::int < 1;
      SQL
  end
  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
