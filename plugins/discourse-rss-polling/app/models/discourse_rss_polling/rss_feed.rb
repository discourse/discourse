# frozen_string_literal: true

module DiscourseRssPolling
  class RssFeed < ActiveRecord::Base
    validates :url, presence: true
  end
end

# == Schema Information
#
# Table name: discourse_rss_polling_rss_feeds
#
#  id              :bigint           not null, primary key
#  url             :string           not null
#  category_filter :string
#  author          :string
#  category_id     :integer
#  tags            :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
