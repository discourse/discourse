require 'rails_helper'

describe Admin::BadgesController do

  context "while logged in as an admin" do
    let!(:user) { log_in(:admin) }
    let!(:badge) { Fabricate(:badge) }

    context 'index' do
      it 'returns badge index' do
        get :index, format: :json
        expect(response).to be_success
      end
    end

    context 'preview' do
      it 'allows preview enable_badge_sql is enabled' do
        SiteSetting.enable_badge_sql = true

        get :preview, params: {
          sql: 'select id as user_id, created_at granted_at from users'
        }, format: :json

        expect(JSON.parse(response.body)["grant_count"]).to be > 0
      end
      it 'does not allow anything if enable_badge_sql is disabled' do
        SiteSetting.enable_badge_sql = false

        get :preview, params: {
          sql: 'select id as user_id, created_at granted_at from users'
        }, format: :json

        expect(response.status).to eq(403)
      end
    end

    describe '.create' do
      render_views

      it 'can create badges correctly' do
        SiteSetting.enable_badge_sql = true

        post :create, params: {
          name: 'test', query: 'select 1 as user_id, null as granted_at', badge_type_id: 1
        }, format: :json

        json = JSON.parse(response.body)
        expect(response.status).to eq(200)
        expect(json["badge"]["name"]).to eq('test')
        expect(json["badge"]["query"]).to eq('select 1 as user_id, null as granted_at')

        expect(UserHistory.where(acting_user_id: user.id, action: UserHistory.actions[:create_badge]).exists?).to eq(true)
      end
    end

    context '.save_badge_groupings' do

      it 'can save badge groupings' do
        groupings = BadgeGrouping.all.order(:position).to_a
        groupings << BadgeGrouping.new(name: 'Test 1')
        groupings << BadgeGrouping.new(name: 'Test 2')

        groupings.shuffle!

        names = groupings.map { |g| g.name }
        ids = groupings.map { |g| g.id.to_s }

        post :save_badge_groupings, params: { ids: ids, names: names }, format: :json

        groupings2 = BadgeGrouping.all.order(:position).to_a

        expect(groupings2.map { |g| g.name }).to eq(names)
        expect((groupings.map(&:id) - groupings2.map { |g| g.id }).compact).to be_blank
        expect(::JSON.parse(response.body)["badge_groupings"].length).to eq(groupings2.length)
      end
    end

    context '.badge_types' do
      it 'returns JSON' do
        get :badge_types, format: :json

        expect(response).to be_success
        expect(::JSON.parse(response.body)["badge_types"]).to be_present
      end
    end

    context '.destroy' do
      it 'deletes the badge' do
        delete :destroy, params: { id: badge.id }, format: :json
        expect(response).to be_success
        expect(Badge.where(id: badge.id).exists?).to eq(false)
        expect(UserHistory.where(acting_user_id: user.id, action: UserHistory.actions[:delete_badge]).exists?).to eq(true)
      end
    end

    context '.update' do

      it 'does not update the name of system badges' do
        editor_badge = Badge.find(Badge::Editor)
        editor_badge_name = editor_badge.name

        put :update, params: {
          id: editor_badge.id,
          name: "123456"
        }, format: :json

        expect(response).to be_success
        editor_badge.reload
        expect(editor_badge.name).to eq(editor_badge_name)

        expect(UserHistory.where(acting_user_id: user.id, action: UserHistory.actions[:change_badge]).exists?).to eq(true)
      end

      it 'does not allow query updates if badge_sql is disabled' do
        badge.query = "select 123"
        badge.save

        SiteSetting.enable_badge_sql = false

        put :update, params: {
          id: badge.id,
          name: "123456",
          query: "select id user_id, created_at granted_at from users",
          badge_type_id: badge.badge_type_id,
          allow_title: false,
          multiple_grant: false,
          enabled: true
        }, format: :json

        expect(response).to be_success
        badge.reload
        expect(badge.name).to eq('123456')
        expect(badge.query).to eq('select 123')
      end

      it 'updates the badge' do
        SiteSetting.enable_badge_sql = true
        sql = "select id user_id, created_at granted_at from users"

        put :update, params: {
          id: badge.id,
          name: "123456",
          query: sql,
          badge_type_id: badge.badge_type_id,
          allow_title: false,
          multiple_grant: false,
          enabled: true
        }, format: :json

        expect(response).to be_success
        badge.reload
        expect(badge.name).to eq('123456')
        expect(badge.query).to eq(sql)
      end
    end
  end
end
