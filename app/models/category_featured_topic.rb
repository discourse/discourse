class CategoryFeaturedTopic < ActiveRecord::Base
  belongs_to :category
  belongs_to :topic

  # Populates the category featured topics
  def self.feature_topics
    current = {}
    CategoryFeaturedTopic.select(:topic_id, :category_id).order(:rank).each do |f|
      (current[f.category_id] ||= []) << f.topic_id
    end
    Category.select(:id, :topic_id, :num_featured_topics).find_each do |c|
      CategoryFeaturedTopic.feature_topics_for(c, current[c.id] || [])
    end
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
