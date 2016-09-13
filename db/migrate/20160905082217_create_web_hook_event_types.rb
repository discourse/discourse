class CreateWebHookEventTypes < ActiveRecord::Migration
  def change
    create_table :web_hook_event_types do |t|
      t.string :name, null: false
    end
  end
end
