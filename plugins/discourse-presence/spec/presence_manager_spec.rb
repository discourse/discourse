require 'rails_helper'

describe ::Presence::PresenceManager do

  let(:user1) { Fabricate(:user) }
  let(:user2) { Fabricate(:user) }
  let(:user3) { Fabricate(:user) }
  let(:manager) { ::Presence::PresenceManager }

  let(:post1) { Fabricate(:post) }
  let(:post2) { Fabricate(:post) }

  after(:each) do
    $redis.del("presence:topic:#{post1.topic.id}")
    $redis.del("presence:topic:#{post2.topic.id}")
    $redis.del("presence:post:#{post1.id}")
    $redis.del("presence:post:#{post2.id}")
  end

  it 'adds, removes and lists users correctly' do
    expect(manager.get_users('post', post1.id).count).to eq(0)

    expect(manager.add('post', post1.id, user1.id)).to be true
    expect(manager.add('post', post1.id, user2.id)).to be true
    expect(manager.add('post', post2.id, user3.id)).to be true

    expect(manager.get_users('post', post1.id).count).to eq(2)
    expect(manager.get_users('post', post2.id).count).to eq(1)

    expect(manager.get_users('post', post1.id)).to contain_exactly(user1, user2)
    expect(manager.get_users('post', post2.id)).to contain_exactly(user3)

    expect(manager.remove('post', post1.id, user1.id)).to be true
    expect(manager.get_users('post', post1.id).count).to eq(1)
    expect(manager.get_users('post', post1.id)).to contain_exactly(user2)
  end

  it 'publishes correctly' do
    expect(manager.get_users('post', post1.id).count).to eq(0)

    manager.add('post', post1.id, user1.id)
    manager.add('post', post1.id, user2.id)

    messages = MessageBus.track_publish do
      manager.publish('post', post1.id)
    end

    expect(messages.count).to eq (1)
    message = messages.first

    expect(message.channel).to eq("/presence/post/#{post1.id}")

    expect(message.data["users"].map { |u| u[:id] }).to contain_exactly(user1.id, user2.id)
  end

  it 'publishes private message securely' do
    private_post = Fabricate(:private_message_post)
    manager.add('post', private_post.id, user2.id)

    messages = MessageBus.track_publish do
      manager.publish('post', private_post.id)
    end

    expect(messages.count).to eq (1)
    message = messages.first

    expect(message.channel).to eq("/presence/post/#{private_post.id}")

    user_ids = User.where('admin or moderator').pluck(:id)
    user_ids += private_post.topic.allowed_users.pluck(:id)
    expect(message.user_ids).to contain_exactly(*user_ids)
  end

  it 'publishes private category securely' do
    group = Fabricate(:group)
    category = Fabricate(:private_category, group: group)
    private_topic = Fabricate(:topic, category: category)

    manager.add('topic', private_topic.id, user2.id)

    messages = MessageBus.track_publish do
      manager.publish('topic', private_topic.id)
    end

    expect(messages.count).to eq (1)
    message = messages.first

    expect(message.channel).to eq("/presence/topic/#{private_topic.id}")

    expect(message.group_ids).to contain_exactly(*private_topic.secure_group_ids)
  end

  it 'cleans up correctly' do
    freeze_time Time.zone.now do
      expect(manager.add('post', post1.id, user1.id)).to be true
      expect(manager.cleanup('post', post1.id)).to be false # Nothing to cleanup
      expect(manager.get_users('post', post1.id).count).to eq(1)
    end

    # Anything older than 20 seconds should be cleaned up
    freeze_time 30.seconds.from_now do
      expect(manager.cleanup('post', post1.id)).to be true
      expect(manager.get_users('post', post1.id).count).to eq(0)
    end
  end
end
