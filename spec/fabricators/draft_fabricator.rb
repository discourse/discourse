# frozen_string_literal: true

Fabricator(:draft) do
  user { Fabricate(:user) }
  transient :category_id
  transient :topic
  transient :post
  transient :archetype
  transient :tags
  draft_key do |transients|
    topic = transients[:topic] || transients[:post]&.topic

    return "#{Draft::EXISTING_TOPIC}_#{topic.id}" if topic

    if transients[:archetype] == "regular"
      Draft::NEW_TOPIC
    else
      Draft::NEW_PRIVATE_MESSAGE
    end
  end
  owner { SecureRandom.hex(10) }
  revisions { sequence(:revisions) { |n| n } }
  sequence { sequence(:sequence) { |n| n } }
  data do |transients|
    topic = transients[:topic] || transients[:post]&.topic

    {
      reply: "This is my really long draft",
      action: topic.present? ? "reply" : "createTopic",
      categoryId: transients[:category_id] || topic&.category_id,
      tags: transients[:tags],
      archetypeId: transients[:archetype],
      metaData: nil,
      composerTime: SecureRandom.random_number(10_000),
      typingTime: SecureRandom.random_number(10_000),
    }
  end
end
