class CreateJoinTableWebHooksTags < ActiveRecord::Migration[5.2]
  def change
    create_join_table :web_hooks, :tags do |t|
      t.index [:web_hook_id, :tag_id], name: 'web_hooks_tags', unique: true
    end
  end
end
