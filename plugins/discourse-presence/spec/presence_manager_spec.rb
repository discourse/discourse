require 'rails_helper'

describe ::Presence::PresenceManager do

  let(:user1) { Fabricate(:user) }
  let(:user2) { Fabricate(:user) }
  let(:user3) { Fabricate(:user) }
  let(:manager) { ::Presence::PresenceManager }

  after(:each) do
    $redis.del('presence:post:22')
    $redis.del('presence:post:11')
  end

  it 'adds, removes and lists users correctly' do
    expect(manager.get_users('post', 22).count).to eq(0)

    expect(manager.add('post', 22, user1.id)).to be true
    expect(manager.add('post', 22, user2.id)).to be true
    expect(manager.add('post', 11, user3.id)).to be true

    expect(manager.get_users('post', 22).count).to eq(2)
    expect(manager.get_users('post', 11).count).to eq(1)

    expect(manager.get_users('post', 22)).to contain_exactly(user1, user2)
    expect(manager.get_users('post', 11)).to contain_exactly(user3)

    expect(manager.remove('post', 22, user1.id)).to be true
    expect(manager.get_users('post', 22).count).to eq(1)
    expect(manager.get_users('post', 22)).to contain_exactly(user2)
  end

  it 'publishes correctly' do
    expect(manager.get_users('post', 22).count).to eq(0)

    manager.add('post', 22, user1.id)
    manager.add('post', 22, user2.id)

    messages = MessageBus.track_publish do
      manager.publish('post', 22)
    end

    expect(messages.count).to eq (1)
    message = messages.first

    expect(message.channel).to eq('/presence/post/22')

    expect(message.data["users"].map { |u| u[:id] }).to contain_exactly(user1.id, user2.id)
  end

  it 'cleans up correctly' do
    freeze_time Time.zone.now do
      expect(manager.add('post', 22, user1.id)).to be true
      expect(manager.cleanup('post', 22)).to be false # Nothing to cleanup
      expect(manager.get_users('post', 22).count).to eq(1)
    end

    # Anything older than 20 seconds should be cleaned up
    freeze_time 30.seconds.from_now do
      expect(manager.cleanup('post', 22)).to be true
      expect(manager.get_users('post', 22).count).to eq(0)
    end
  end
end
