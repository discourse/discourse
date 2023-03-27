# frozen_string_literal: true

class AddLinkPostIdIndexOnTopicLinks < ActiveRecord::Migration[4.2]
  def change
    add_index :topic_links, %i[link_post_id reflection]
  end
end
