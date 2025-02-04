# frozen_string_literal: true
class RemoveCategoryExpertsWebHookEventTypes < ActiveRecord::Migration[7.1]
  def up
    execute "DELETE FROM web_hook_event_types WHERE (name, id) IN (('category_experts_approved', 1901), ('category_experts_unapproved', 1902))"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
