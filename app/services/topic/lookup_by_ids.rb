# frozen_string_literal: true

# Looks up the topics behind a list of ids, for a picker naming the topics it
# holds. A held topic stays named whatever the user muted, so unlike topic
# lists this answers every topic the user can see.
class Topic::LookupByIds
  include Service::Base

  MAX_TOPIC_IDS = 50

  params do
    attribute :topic_ids, :array

    validates :topic_ids, presence: true, length: { maximum: MAX_TOPIC_IDS }
    validate :topic_ids_are_integers

    private

    def topic_ids_are_integers
      errors.add(:topic_ids, :invalid) if topic_ids&.any? { !it.is_a?(Integer) }
    end
  end

  model :topics, optional: true

  private

  def fetch_topics(params:, guardian:)
    guardian.visible_topic_scope(Topic.where(id: params.topic_ids)).preload(:tags)
  end
end
