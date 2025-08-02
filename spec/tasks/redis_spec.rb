# frozen_string_literal: true

RSpec.describe "Redis rake tasks", type: :multisite do
  let(:redis) { Discourse.redis.without_namespace }

  describe "clean up" do
    it "should clean up orphan Redis keys" do
      active_keys = %w[
        __mb_backlog_id_n_/users/someusername$|$default
        default:user-last-seen:607
        sidekiq:something:do:something
        somekeytonotbetouched
      ]

      orphan_keys = %w[tgxworld:user-last-seen:607 __mb_backlog_id_n_/users/someusername$|$tgxworld]

      (active_keys | orphan_keys).each { |key| redis.set(key, 1) }

      invoke_rake_task("redis:clean_up")

      active_keys.each { |key| expect(redis.get(key)).to eq("1") }

      orphan_keys.each { |key| expect(redis.get(key)).to eq(nil) }
    ensure
      active_keys.each { |key| redis.del(key) }
    end
  end
end
