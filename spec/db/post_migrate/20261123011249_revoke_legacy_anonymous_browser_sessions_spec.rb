# frozen_string_literal: true

require Rails.root.join(
          "db/post_migrate/20261123011249_revoke_legacy_anonymous_browser_sessions.rb",
        )

RSpec.describe RevokeLegacyAnonymousBrowserSessions do
  describe "#up" do
    it "resets browsers and push only for identifiable anonymous families across batches" do
      master, current, historical, orphan, outsider = Fabricate.times(5, :user)
      AnonymousUser.create!(user: current, master_user: master, active: true)
      AnonymousUser.create!(user: historical, master_user: master, active: false)
      former_master = Fabricate(:user)
      AnonymousUser.create!(user: orphan, master_user: former_master, active: false)
      former_master.destroy!
      users = [master, current, historical, orphan, outsider]
      sessions = users.map { |user| UserAuthToken.generate!(user_id: user.id) }
      subscriptions = users.map { |user| Fabricate(:push_subscription, user: user) }
      keys = users.map { |user| Fabricate(:user_api_key, user: user) }

      stub_const(described_class, :BATCH_SIZE, 1) { 2.times { described_class.new.up } }

      expect(UserAuthToken.where(id: sessions.map(&:id)).pluck(:user_id)).to eq([outsider.id])
      expect(PushSubscription.where(id: subscriptions.map(&:id)).pluck(:user_id)).to eq(
        [outsider.id],
      )
      expect(UserApiKey.active.where(id: keys.map(&:id)).pluck(:user_id)).to match_array(
        users.map(&:id),
      )
    end
  end
end
