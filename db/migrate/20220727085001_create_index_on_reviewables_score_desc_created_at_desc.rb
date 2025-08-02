# frozen_string_literal: true

class CreateIndexOnReviewablesScoreDescCreatedAtDesc < ActiveRecord::Migration[7.0]
  def change
    add_index(
      :reviewables,
      %i[score created_at],
      order: {
        score: :desc,
        created_at: :desc,
      },
      name: "idx_reviewables_score_desc_created_at_desc",
    )
  end
end
