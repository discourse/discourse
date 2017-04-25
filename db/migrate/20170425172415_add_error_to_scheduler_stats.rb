class AddErrorToSchedulerStats < ActiveRecord::Migration
  def change
    add_column :scheduler_stats, :error, :text
  end
end
