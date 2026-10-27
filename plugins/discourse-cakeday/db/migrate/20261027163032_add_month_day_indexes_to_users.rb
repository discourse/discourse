# frozen_string_literal: true
class AddMonthDayIndexesToUsers < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    remove_index :users,
                 name: "index_users_on_created_at_month_day",
                 algorithm: :concurrently,
                 if_exists: true
    add_index :users,
              "(EXTRACT(MONTH FROM created_at) * 100 + EXTRACT(DAY FROM created_at))",
              name: "index_users_on_created_at_month_day",
              algorithm: :concurrently

    remove_index :users,
                 name: "index_users_on_date_of_birth_month_day",
                 algorithm: :concurrently,
                 if_exists: true
    add_index :users,
              "(EXTRACT(MONTH FROM date_of_birth) * 100 + EXTRACT(DAY FROM date_of_birth))",
              name: "index_users_on_date_of_birth_month_day",
              where: "date_of_birth IS NOT NULL",
              algorithm: :concurrently
  end

  def down
    remove_index :users,
                 name: "index_users_on_created_at_month_day",
                 algorithm: :concurrently,
                 if_exists: true
    remove_index :users,
                 name: "index_users_on_date_of_birth_month_day",
                 algorithm: :concurrently,
                 if_exists: true
  end
end
