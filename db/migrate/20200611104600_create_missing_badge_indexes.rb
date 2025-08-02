# frozen_string_literal: true

# Badge and user_badge tables were created using add_column index: true
# When the migration was written, `index: true` was a no-op for non-reference columns
# Since then, rails made it work https://github.com/rails/rails/commit/9a0d35e820464f872b0340366dded639f00e19b9
# This migration adds the index to very old sites, so that we have a consistent state

# frozen_string_literal: true

class CreateMissingBadgeIndexes < ActiveRecord::Migration[6.0]
  def up
    execute "CREATE INDEX IF NOT EXISTS index_user_badges_on_user_id ON public.user_badges USING btree (user_id)"
    execute "CREATE INDEX IF NOT EXISTS index_badges_on_badge_type_id ON public.badges USING btree (badge_type_id)"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
