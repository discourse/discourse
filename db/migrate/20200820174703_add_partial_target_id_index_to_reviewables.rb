# frozen_string_literal: true

class AddPartialTargetIdIndexToReviewables < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def change
    add_index :reviewables,
              [:target_id],
              where: "target_type = 'Post'",
              algorithm: :concurrently,
              name: "index_reviewables_on_target_id_where_post_type_eq_post"
  end
end
