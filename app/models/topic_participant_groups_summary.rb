# frozen_string_literal: true

# This is used on a topic page
class TopicParticipantGroupsSummary
  attr_reader :topic, :options

  def initialize(topic, options = {})
    @topic = topic
    @options = options
    @group = options[:group]
  end

  def summary
    group_participants.compact
  end

  def group_participants
    return [] if group_ids.blank?
    group_ids.map { |id| group_lookup[id] }
  end

  def group_ids
    ids = topic.allowed_group_ids
    ids = ids - [@group.id] if @group.present?
    ids
  end

  def group_lookup
    @group_lookup ||= options[:group_lookup] || GroupLookup.new(group_ids)
  end
end
