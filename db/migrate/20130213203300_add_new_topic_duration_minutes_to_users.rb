class AddNewTopicDurationMinutesToUsers < ActiveRecord::Migration[4.2]
  def change
    # note, no constants allowed here, -1 means since last visit
    # -2 means always
    # larger than 0 is an hour time span
    add_column :users, :new_topic_duration_minutes, :integer
  end
end
