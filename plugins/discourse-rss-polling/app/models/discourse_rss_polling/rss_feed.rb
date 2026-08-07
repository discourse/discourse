# frozen_string_literal: true

module DiscourseRssPolling
  class RssFeed < ActiveRecord::Base
    self.ignored_columns += %i[author]

    belongs_to :user, optional: true
    has_many :poll_attempts, class_name: "DiscourseRssPolling::PollAttempt", dependent: :delete_all

    validates :url, presence: true

    scope :enabled, -> { where(enabled: true) }

    def user
      super || Discourse.system_user
    end

    def poll(inline: false, force: false)
      args = {
        rss_feed_id: id,
        feed_url: url,
        user_id: user_id,
        discourse_category_id: category_id,
        discourse_tags: tags&.split(","),
        feed_category_filter: category_filter,
        force: force,
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
#  enabled         :boolean          default(TRUE), not null
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
