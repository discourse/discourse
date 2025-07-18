# frozen_string_literal: true

class PushFixTopicEmbedAuthorsJob < ActiveRecord::Migration[5.2]
  def change
    Jobs.enqueue("DiscourseRssPolling::FixTopicEmbedAuthors")
  end
end
