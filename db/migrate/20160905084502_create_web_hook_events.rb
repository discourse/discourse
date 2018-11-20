class CreateWebHookEvents < ActiveRecord::Migration[4.2]
  def change
    create_table :web_hook_events do |t|
      t.belongs_to :web_hook, null: false, index: true
      t.string     :headers
      t.text       :payload
      t.integer    :status, default: 0
      t.string     :response_headers
      t.text       :response_body
      t.integer    :duration, default: 0

      t.timestamps null: false
    end
  end
end
