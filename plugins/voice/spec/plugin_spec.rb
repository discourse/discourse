# frozen_string_literal: true

RSpec.describe UserDestroyer do
  describe "voice cleanup" do
    fab!(:admin)
    fab!(:user)
    fab!(:other_user, :user)
    fab!(:room) { Fabricate(:voice_room, creator: user, public: true) }

    before { SiteSetting.voice_enabled = true }

    it "moves the deleted user's rooms to the system user" do
      UserDestroyer.new(admin).destroy(user)

      expect(room.reload.creator_id).to eq(Discourse.system_user.id)
    end

    it "removes memberships and co-presences but keeps sessions as history" do
      session = Fabricate(:voice_session, user: user, room: room)
      ids = [user.id, other_user.id].minmax
      co_presence =
        Voice::CoPresence.create!(
          user_id_1: ids.first,
          user_id_2: ids.last,
          date: Time.zone.today,
          total_seconds: 60,
          session_count: 1,
        )

      UserDestroyer.new(admin).destroy(user)

      expect(Voice::RoomMembership.where(user_id: user.id)).to be_empty
      expect(Voice::CoPresence.exists?(co_presence.id)).to eq(false)
      expect(session.reload.user_id).to eq(user.id)
    end
  end
end

RSpec.describe BadgesController, type: :request do
  before do
    SiteSetting.enable_badges = true
    SiteSetting.chat_enabled = false
    SiteSetting.voice_enabled = false
    SiteSetting.voice_badges_enabled = true
    SeedFu.seed(Rails.root.join("plugins/voice/db/fixtures"))
  end

  let(:badge) { Badge.find_by!(name: "Mic Check") }

  it "hides unavailable badges and their recipients regardless of grouping" do
    badge.update!(badge_grouping_id: BadgeGrouping::Other)

    get "/badges.json"

    expect(response.status).to eq(Rack::Utils::SYMBOL_TO_STATUS_CODE.fetch(:ok))
    expect(
      response.parsed_body["badges"].pluck("id") & Badge.where(plugin_name: Voice::PLUGIN_NAME).ids,
    ).to be_empty

    get "/badges/#{badge.id}.json"
    expect(response.status).to eq(Rack::Utils::SYMBOL_TO_STATUS_CODE.fetch(:not_found))

    get "/user_badges.json", params: { badge_id: badge.id }
    expect(response.status).to eq(Rack::Utils::SYMBOL_TO_STATUS_CODE.fetch(:not_found))

    SiteSetting.voice_badges_enabled = false
    SiteSetting.voice_enabled = true

    get "/badges.json"

    expect(
      response.parsed_body["badges"].pluck("id") & Badge.where(plugin_name: Voice::PLUGIN_NAME).ids,
    ).to be_empty
  end

  it "keeps unavailable badges editable and protects their awards from bulk replacement" do
    admin = Fabricate(:admin)
    SiteSetting.voice_enabled = true
    award = BadgeGranter.grant(badge, admin)
    SiteSetting.voice_enabled = false
    sign_in(admin)

    get "/badges.json", headers: { "HTTP_X_REQUESTED_WITH" => "XMLHttpRequest" }

    expect(response.status).to eq(Rack::Utils::SYMBOL_TO_STATUS_CODE.fetch(:ok))
    expect(response.parsed_body["badges"].pluck("id")).to include(badge.id)

    file = file_from_fixtures("usernames.csv", "csv")
    post "/admin/badges/award/#{badge.id}.json",
         params: {
           file: fixture_file_upload(file),
           replace_badge_owners: true,
         }

    expect(response.status).to eq(Rack::Utils::SYMBOL_TO_STATUS_CODE.fetch(:unprocessable_entity))
    expect(UserBadge.exists?(award.id)).to eq(true)
  end
end

RSpec.describe BadgeGranter do
  fab!(:user)

  before do
    Jobs.run_immediately!
    SiteSetting.voice_enabled = true
    SiteSetting.voice_badges_enabled = true
    SeedFu.seed(Rails.root.join("plugins/voice/db/fixtures"))
  end

  let(:badge) { Badge.find_by!(name: "Mic Check") }

  it "blocks direct and mass grants while Voice is disabled" do
    SiteSetting.voice_enabled = false

    expect do
      described_class.grant(badge, user)
      described_class.mass_grant(badge, user, count: 1)
    end.not_to change { UserBadge.where(user: user, badge: badge).count }
  end

  it "preserves badge choices and awards across availability changes" do
    disabled_badge = Badge.find_by!(name: "Rookie")
    disabled_badge.update!(enabled: false)
    user_badge = described_class.grant(badge, user)

    %i[voice_enabled voice_badges_enabled].each do |setting|
      SiteSetting.public_send("#{setting}=", false)

      expect(user.user_badges.reload).to be_empty
      expect(user.user_stat.reload.distinct_badge_count).to eq(0)
      expect(
        Notification.filter_disabled_badge_notifications([user_badge.notification]),
      ).to be_empty

      SiteSetting.public_send("#{setting}=", true)

      expect(badge.reload.enabled).to eq(true)
      expect(disabled_badge.reload.enabled).to eq(false)
      expect(user.user_badges.reload).to contain_exactly(user_badge)
      expect(user.user_stat.reload.distinct_badge_count).to eq(1)
      expect(
        Notification.filter_disabled_badge_notifications([user_badge.notification]),
      ).to contain_exactly(user_badge.notification)
    end
  end
end
