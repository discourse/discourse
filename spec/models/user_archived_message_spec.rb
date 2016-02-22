require 'rails_helper'

describe UserArchivedMessage do
  it 'Does not move archived muted messages back to inbox' do
    user = Fabricate(:admin)
    user2 = Fabricate(:admin)

    topic = create_post(user: user,
                        skip_validations: true,
                        target_usernames: [user2.username,user.username].join(","),
                        archetype: Archetype.private_message).topic

    UserArchivedMessage.archive!(user.id, topic.id)
    expect(topic.message_archived?(user)).to eq(true)

    TopicUser.change(user.id, topic.id, notification_level: TopicUser.notification_levels[:muted])
    UserArchivedMessage.move_to_inbox!(user.id, topic.id)
    expect(topic.message_archived?(user)).to eq(true)
  end
end

