# frozen_string_literal: true

class CategoryFeaturedTopic < ActiveRecord::Base
  belongs_to :category
  belongs_to :topic

  NEXT_CATEGORY_ID_KEY = 'category-featured-topic:next-category-id'.freeze
  DEFAULT_BATCH_SIZE = 100

  # Populates the category featured topics.
  def self.feature_topics(batched: false, batch_size: nil)
    current = {}
    CategoryFeaturedTopic.select(:topic_id, :category_id).order(:rank).each do |f|
      (current[f.category_id] ||= []) << f.topic_id
    end

    batch_size ||= DEFAULT_BATCH_SIZE

    next_category_id = batched ? Discourse.redis.get(NEXT_CATEGORY_ID_KEY).to_i : 0

    categories = Category.select(:id, :topic_id, :num_featured_topics)
      .where('id >= ?', next_category_id)
      .order('id ASC')
      .limit(batch_size)
      .to_a

    if batched
      if categories.length == batch_size
        next_id = Category.where('id > ?', categories.last.id).order('id asc').limit(1).pluck(:id)[0]
        next_id ? Discourse.redis.setex(NEXT_CATEGORY_ID_KEY, 1.day, next_id) : clear_batch!
      else
        clear_batch!
      end
    end

    categories.each do |c|
      CategoryFeaturedTopic.feature_topics_for(c, current[c.id] || [])
    end
  end

  def self.clear_batch!
    Discourse.redis.del(NEXT_CATEGORY_ID_KEY)
  end

  def self.feature_topics_for(c, existing = nil)
    return if c.blank?

    query_opts = {
      per_page: c.num_featured_topics,
      except_topic_ids: [c.topic_id],
      visible: true,
      no_definitions: true
    }

    # It may seem a bit odd that we are running 2 queries here, when admin
    # can clearly pull out all the topics needed.
    # We do so, so anonymous will ALWAYS get some topics
    # If we only fetched as admin we may have a situation where anon can see
    # no featured topics (all the previous 2x topics are only visible to admins)

    # Add topics, even if they're in secured categories or invisible
    query = TopicQuery.new(CategoryFeaturedTopic.fake_admin, query_opts)
    results = query.list_category_topic_ids(c).uniq

    # Add some topics that are visible to everyone:
    anon_query = TopicQuery.new(nil, query_opts.merge(except_topic_ids: [c.topic_id] + results))
    results += anon_query.list_category_topic_ids(c).uniq

    return if results == existing

    CategoryFeaturedTopic.transaction do
      CategoryFeaturedTopic.where(category_id: c.id).delete_all
      if results
        results.each_with_index do |topic_id, idx|
          begin
            c.category_featured_topics.create(topic_id: topic_id, rank: idx)
          rescue PG::UniqueViolation
            # If another process features this topic, just ignore it
          end
        end
      end
    end
  end

  def self.fake_admin
    # fake an admin
    admin = User.new
    admin.admin = true
    admin.id = -1
    admin
  end

end

# == Schema Information
#
# Table name: category_featured_topics
#
#  category_id :integer          not null
#  topic_id    :integer          not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  rank        :integer          default(0), not null
#  id          :integer          not null, primary key
#
# Indexes
#
#  cat_featured_threads                                    (category_id,topic_id) UNIQUE
#  index_category_featured_topics_on_category_id_and_rank  (category_id,rank)
#
