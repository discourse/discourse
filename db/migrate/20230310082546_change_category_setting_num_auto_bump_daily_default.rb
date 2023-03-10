# frozen_string_literal: true

class ChangeCategorySettingNumAutoBumpDailyDefault < ActiveRecord::Migration[7.0]
  def up
    change_column_default :category_settings, :num_auto_bump_daily, 0

    execute(<<~SQL)
      UPDATE category_settings
      SET num_auto_bump_daily = 0
      WHERE num_auto_bump_daily IS NULL;
    SQL
  end

  def down
    change_column_default :category_settings, :num_auto_bump_daily, nil

    execute(<<~SQL)
      UPDATE category_settings
      SET num_auto_bump_daily = NULL
      WHERE num_auto_bump_daily = 0;
    SQL
  end
end
