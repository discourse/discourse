# frozen_string_literal: true

namespace :nested_replies do
  desc "Prepare nested reply statistics for all regular topics"
  task prepare_stats: :environment do
    enqueue =
      lambda do
        database = RailsMultisite::ConnectionManagement.current_db
        SiteSetting.nested_replies_stats_maintenance_enabled = true
        max_topic_id = Topic.where(archetype: Archetype.default, deleted_at: nil).maximum(:id).to_i
        Jobs.enqueue(:prepare_nested_reply_stats, max_topic_id: max_topic_id)

        puts "Enqueued nested reply stats preparation for '#{database}' " \
               "through topic #{max_topic_id}"
      end

    if ENV["RAILS_DB"]
      enqueue.call
    else
      RailsMultisite::ConnectionManagement.each_connection { enqueue.call }
    end
  end
end
