class AddLastEmailedPostNumberToTopicUser < ActiveRecord::Migration
  def change
    add_column :topic_users, :last_emailed_post_number, :integer
  end
end
