# frozen_string_literal: true
class RemoveCategoryExpertsWebHookEventTypes < ActiveRecord::Migration[7.1]
  def up
    if !defined?(DiscourseCategoryExperts)
      execute "DELETE FROM web_hook_event_types WHERE (name = 'category_experts_approved' AND id = 1901) OR (name = 'category_experts_unapproved' AND id = 1902)"
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
