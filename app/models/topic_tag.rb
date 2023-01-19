# frozen_string_literal: true

class TopicTag < ActiveRecord::Base
  belongs_to :topic
  belongs_to :tag

  after_create do
    if topic
      if topic.archetype == Archetype.private_message
        tag.increment!(:pm_topic_count)
      else
        counters_to_update = { staff_topic_count: 1 }

        if Category.exists?(id: topic.category_id, read_restricted: false)
          counters_to_update[:public_topic_count] = 1
        end

        Tag.update_counters(tag.id, counters_to_update)

        if stat = CategoryTagStat.find_by(tag_id: tag_id, category_id: topic.category_id)
          stat.increment!(:topic_count)
        else
          CategoryTagStat.create!(tag_id: tag_id, category_id: topic.category_id, topic_count: 1)
        end
      end
    end
  end

  after_destroy do
    if topic
      if topic.archetype == Archetype.private_message
        tag.decrement!(:pm_topic_count)
      else
        if stat = CategoryTagStat.find_by(tag_id: tag_id, category: topic.category_id)
          stat.topic_count == 1 ? stat.destroy! : stat.decrement!(:topic_count)
        end

        counters_to_update = { staff_topic_count: -1 }

        if Category.exists?(id: topic.category_id, read_restricted: false)
          counters_to_update[:public_topic_count] = -1
        end

        Tag.update_counters(tag.id, counters_to_update)
      end
    end
  end
end

# == Schema Information
#
# Table name: topic_tags
#
#  id         :integer          not null, primary key
#  topic_id   :integer          not null
#  tag_id     :integer          not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_topic_tags_on_topic_id_and_tag_id  (topic_id,tag_id) UNIQUE
#
