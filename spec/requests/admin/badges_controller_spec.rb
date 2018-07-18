require 'rails_helper'

describe Admin::BadgesController do
  context "while logged in as an admin" do
    let(:admin) { Fabricate(:admin) }
    let!(:badge) { Fabricate(:badge) }

    before do
      sign_in(admin)
    end

    describe '#index' do
      it 'returns badge index' do
        get "/admin/badges.json"
        expect(response.status).to eq(200)
      end
    end

    describe '#preview' do
      it 'allows preview enable_badge_sql is enabled' do
        SiteSetting.enable_badge_sql = true

        post "/admin/badges/preview.json", params: {
          sql: 'select id as user_id, created_at granted_at from users'
        }

        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)["grant_count"]).to be > 0
      end

      it 'does not allow anything if enable_badge_sql is disabled' do
        SiteSetting.enable_badge_sql = false

        post "/admin/badges/preview.json", params: {
          sql: 'select id as user_id, created_at granted_at from users'
        }

        expect(response.status).to eq(403)
      end
    end

    describe '#create' do
      it 'can create badges correctly' do
        SiteSetting.enable_badge_sql = true

        post "/admin/badges.json", params: {
          name: 'test', query: 'select 1 as user_id, null as granted_at', badge_type_id: 1
        }

        json = JSON.parse(response.body)
        expect(response.status).to eq(200)
        expect(json["badge"]["name"]).to eq('test')
        expect(json["badge"]["query"]).to eq('select 1 as user_id, null as granted_at')

        expect(UserHistory.where(acting_user_id: admin.id, action: UserHistory.actions[:create_badge]).exists?).to eq(true)
      end
    end

    describe '#save_badge_groupings' do
      it 'can save badge groupings' do
        groupings = BadgeGrouping.all.order(:position).to_a
        groupings << BadgeGrouping.new(name: 'Test 1')
        groupings << BadgeGrouping.new(name: 'Test 2')

        groupings.shuffle!

        names = groupings.map { |g| g.name }
        ids = groupings.map { |g| g.id.to_s }

        post "/admin/badges/badge_groupings.json", params: { ids: ids, names: names }
        expect(response.status).to eq(200)

        groupings2 = BadgeGrouping.all.order(:position).to_a

        expect(groupings2.map { |g| g.name }).to eq(names)
        expect((groupings.map(&:id) - groupings2.map { |g| g.id }).compact).to be_blank
        expect(::JSON.parse(response.body)["badge_groupings"].length).to eq(groupings2.length)
      end
    end

    describe '#badge_types' do
      it 'returns JSON' do
        get "/admin/badges/types.json"

        expect(response.status).to eq(200)
        expect(::JSON.parse(response.body)["badge_types"]).to be_present
      end
    end

    describe '#destroy' do
      it 'deletes the badge' do
        delete "/admin/badges/#{badge.id}.json"
        expect(response.status).to eq(200)
        expect(Badge.where(id: badge.id).exists?).to eq(false)
        expect(UserHistory.where(acting_user_id: admin.id, action: UserHistory.actions[:delete_badge]).exists?).to eq(true)
      end
    end

    describe '#update' do
      it 'does not update the name of system badges' do
        editor_badge = Badge.find(Badge::Editor)
        editor_badge_name = editor_badge.name

        put "/admin/badges/#{editor_badge.id}.json", params: {
          name: "123456"
        }

        expect(response.status).to eq(200)
        editor_badge.reload
        expect(editor_badge.name).to eq(editor_badge_name)

        expect(UserHistory.where(acting_user_id: admin.id, action: UserHistory.actions[:change_badge]).exists?).to eq(true)
      end

      it 'does not allow query updates if badge_sql is disabled' do
        badge.query = "select 123"
        badge.save

        SiteSetting.enable_badge_sql = false

        put "/admin/badges/#{badge.id}.json", params: {
          name: "123456",
          query: "select id user_id, created_at granted_at from users",
          badge_type_id: badge.badge_type_id,
          allow_title: false,
          multiple_grant: false,
          enabled: true
        }

        expect(response.status).to eq(200)
        badge.reload
        expect(badge.name).to eq('123456')
        expect(badge.query).to eq('select 123')
      end

      it 'updates the badge' do
        SiteSetting.enable_badge_sql = true
        sql = "select id user_id, created_at granted_at from users"

        put "/admin/badges/#{badge.id}.json", params: {
          name: "123456",
          query: sql,
          badge_type_id: badge.badge_type_id,
          allow_title: false,
          multiple_grant: false,
          enabled: true
        }

        expect(response.status).to eq(200)
        badge.reload
        expect(badge.name).to eq('123456')
        expect(badge.query).to eq(sql)
      end
    end
  end
end
