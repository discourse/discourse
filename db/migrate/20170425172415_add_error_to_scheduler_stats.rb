class AddErrorToSchedulerStats < ActiveRecord::Migration[4.2]
  def change
    add_column :scheduler_stats, :error, :text
  end
end
