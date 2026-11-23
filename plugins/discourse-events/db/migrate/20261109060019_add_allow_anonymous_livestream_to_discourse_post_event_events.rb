# frozen_string_literal: true

class AddAllowAnonymousLivestreamToDiscoursePostEventEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :discourse_post_event_events,
               :allow_anonymous_livestream,
               :boolean,
               default: false,
               null: false
  end
end
