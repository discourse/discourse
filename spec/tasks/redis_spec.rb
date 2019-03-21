require 'rails_helper'

RSpec.describe 'Redis rake tasks' do
  let(:redis) { $redis.without_namespace }

  before do
    @multisite = Rails.configuration.multisite
    Rails.configuration.multisite = true
    Discourse::Application.load_tasks
  end

  after { Rails.configuration.multisite = @multisite }

  describe 'clean up' do
    it 'should clean up orphan Redis keys' do
      active_keys = %w[
        __mb_backlog_id_n_/users/someusername$|$default
        default:user-last-seen:607
        sidekiq:something:do:something
        somekeytonotbetouched
      ]

      orphan_keys = %w[
        tgxworld:user-last-seen:607
        __mb_backlog_id_n_/users/someusername$|$tgxworld
      ]

      (active_keys | orphan_keys).each { |key| redis.set(key, 1) }

      Rake::Task['redis:clean_up'].invoke

      active_keys.each { |key| expect(redis.get(key)).to eq('1') }

      orphan_keys.each { |key| expect(redis.get(key)).to eq(nil) }
    end
  end
end
