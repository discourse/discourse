# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Redis rake tasks", type: :multisite do
  let(:redis) { Discourse.redis.without_namespace }

  before do
    Discourse::Application.load_tasks
  end

  describe 'clean up' do
    it 'should clean up orphan Redis keys' do
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

      Rake::Task['redis:clean_up'].invoke

      active_keys.each do |key|
        expect(redis.get(key)).to eq('1')
      end

      orphan_keys.each do |key|
        expect(redis.get(key)).to eq(nil)
      end
    ensure
      active_keys.each { |key| redis.del(key) }
    end
  end
end
