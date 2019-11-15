# frozen_string_literal: true
class AddBannerIndexToTopics < ActiveRecord::Migration[6.0]
  def change
    # this speeds up the process for finding banners on the site
    add_index :topics, [:id], name: 'index_topics_on_id_filtered_banner', where: "archetype = 'banner' AND deleted_at IS NULL", unique: true
  end
end
