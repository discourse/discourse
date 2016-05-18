class CreateOnceoffLogs < ActiveRecord::Migration
  def change
    create_table :onceoff_logs do |t|
      t.string :job_name
      t.timestamps null: false
    end

    add_index :onceoff_logs, :job_name
  end
end
