# frozen_string_literal: true

module DiscourseRssPolling
  class RssFeed < ActiveRecord::Base
    self.ignored_columns += %i[author]

    belongs_to :user, optional: true

    validates :url, presence: true

    delegate :username, to: :user, prefix: :author, allow_nil: true

    def poll(inline: false)
      args = {
        feed_url: url,
        user_id: user_id,
        discourse_category_id: category_id,
        discourse_tags: tags&.split(","),
        feed_category_filter: category_filter,
      }

      if inline
        Jobs::DiscourseRssPolling::PollFeed.new.execute(args)
      else
        Jobs.enqueue("DiscourseRssPolling::PollFeed", args)
      end
    end
  end
end

# == Schema Information
#
# Table name: discourse_rss_polling_rss_feeds
#
#  id              :bigint           not null, primary key
#  category_filter :string
#  tags            :string
#  url             :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  category_id     :integer
#  user_id         :bigint
#
# Indexes
#
#  index_discourse_rss_polling_rss_feeds_on_user_id  (user_id)
#
