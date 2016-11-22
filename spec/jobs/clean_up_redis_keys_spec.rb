require 'rails_helper'

describe Jobs::CleanUpRedisKeys do
  let(:redis) { $redis.without_namespace }

  before do
    @multisite = Rails.configuration.multisite
    Rails.configuration.multisite = true
  end

  after do
    Rails.configuration.multisite = @multisite
  end

  it 'should clean up the right keys' do
    active_keys = [
      '__mb_backlog_id_n_/users/someusername$|$default',
      'default:user-last-seen:607',
      'sidekiq:something:do:something',
      'somekeytonotbetouched'
    ]

    orphan_keys = [
      'tgxworld:user-last-seen:607',
      '__mb_backlog_id_n_/users/someusername$|$tgxworld'
    ]

    (active_keys | orphan_keys).each do |key|
      redis.set(key, 1)
    end

    described_class.new.execute({})

    active_keys.each do |key|
      expect(redis.get(key)).to eq('1')
    end

    orphan_keys.each do |key|
      expect(redis.get(key)).to eq(nil)
    end
  end
end
