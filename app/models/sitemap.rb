# frozen_string_literal: true

class Sitemap < ActiveRecord::Base
  RECENT_SITEMAP_NAME = "recent"
  NEWS_SITEMAP_NAME = "news"

  class << self
    def regenerate_sitemaps
      names_used = [RECENT_SITEMAP_NAME, NEWS_SITEMAP_NAME]

      names_used.each { |name| touch(name) }

      count = Category.where(read_restricted: false).sum(:topic_count)
      max_page_size = SiteSetting.sitemap_page_size
      size, mod = count.divmod(max_page_size)
      size += 1 if mod > 0

      size.times do |index|
        page_name = (index + 1).to_s
        touch(page_name)
        names_used << page_name
      end

      where.not(name: names_used).update_all(enabled: false)
    end

    def touch(name)
      find_or_initialize_by(name: name).tap do |sitemap|
        sitemap.update!(last_posted_at: sitemap.last_posted_topic || 3.days.ago, enabled: true)
      end
    end
  end

  def topics
    if name == RECENT_SITEMAP_NAME
      sitemap_topics.pluck(:id, :slug, :bumped_at, :updated_at, :posts_count)
    elsif name == NEWS_SITEMAP_NAME
      sitemap_topics.pluck(:id, :title, :slug, :created_at)
    else
      sitemap_topics.pluck(:id, :slug, :bumped_at, :updated_at)
    end
  end

  def last_posted_topic
    sitemap_topics.maximum(:updated_at)
  end

  def max_page_size
    SiteSetting.sitemap_page_size
  end

  private

  def sitemap_topics
    indexable_topics =
      Topic.where(visible: true).joins(:category).where(categories: { read_restricted: false })

    if name == RECENT_SITEMAP_NAME
      indexable_topics.where("bumped_at > ?", 3.days.ago).order(bumped_at: :desc)
    elsif name == NEWS_SITEMAP_NAME
      indexable_topics.where("bumped_at > ?", 72.hours.ago).order(bumped_at: :desc)
    else
      offset = (name.to_i - 1) * max_page_size

      indexable_topics.order(id: :asc).limit(max_page_size).offset(offset)
    end
  end
end

# == Schema Information
#
# Table name: sitemaps
#
#  id             :bigint           not null, primary key
#  name           :string           not null
#  last_posted_at :datetime         not null
#  enabled        :boolean          default(TRUE), not null
#
# Indexes
#
#  index_sitemaps_on_name  (name) UNIQUE
#
