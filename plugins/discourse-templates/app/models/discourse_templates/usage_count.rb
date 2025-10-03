# frozen_string_literal: true

module DiscourseTemplates
  class UsageCount < ActiveRecord::Base
    self.table_name = "discourse_templates_usage_count"

    belongs_to :topic

    validates_presence_of :topic_id
  end
end

# == Schema Information
#
# Table name: discourse_templates_usage_count
#
#  id          :bigint           not null, primary key
#  topic_id    :integer          not null
#  usage_count :integer          default(0), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_discourse_templates_usage_count_on_topic_id  (topic_id) UNIQUE
#
