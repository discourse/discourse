class CreateJoinTableWebHooksWebHookEventTypes < ActiveRecord::Migration[4.2]
  def change
    create_join_table :web_hooks, :web_hook_event_types

    add_index :web_hook_event_types_hooks, [:web_hook_event_type_id, :web_hook_id],
      name: 'idx_web_hook_event_types_hooks_on_ids',
      unique: true
  end
end
