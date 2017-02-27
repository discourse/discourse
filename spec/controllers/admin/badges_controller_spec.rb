require 'rails_helper'

describe Admin::BadgesController do

  context "while logged in as an admin" do
    let!(:user) { log_in(:admin) }
    let!(:badge) { Fabricate(:badge) }

    context 'index' do
      it 'returns badge index' do
        xhr :get, :index
        expect(response).to be_success
      end
    end

    context 'preview' do
      it 'allows preview enable_badge_sql is enabled' do
        SiteSetting.enable_badge_sql = true
        result = xhr :get, :preview, sql: 'select id as user_id, created_at granted_at from users'
        expect(JSON.parse(result.body)["grant_count"]).to be > 0
      end
      it 'does not allow anything if enable_badge_sql is disabled' do
        SiteSetting.enable_badge_sql = false
        result = xhr :get, :preview, sql: 'select id as user_id, created_at granted_at from users'
        expect(result.status).to eq(403)
      end
    end

    context '.save_badge_groupings' do

      it 'can save badge groupings' do
        groupings = BadgeGrouping.all.order(:position).to_a
        groupings << BadgeGrouping.new(name: 'Test 1')
        groupings << BadgeGrouping.new(name: 'Test 2')

        groupings.shuffle!

        names = groupings.map{|g| g.name}
        ids = groupings.map{|g| g.id.to_s}


        xhr :post, :save_badge_groupings, ids: ids, names: names

        groupings2 = BadgeGrouping.all.order(:position).to_a

        expect(groupings2.map{|g| g.name}).to eq(names)
        expect((groupings.map(&:id) - groupings2.map{|g| g.id}).compact).to be_blank

        expect(::JSON.parse(response.body)["badge_groupings"].length).to eq(groupings2.length)
      end
    end

    context '.badge_types' do
      it 'returns success' do
        xhr :get, :badge_types
        expect(response).to be_success
      end

      it 'returns JSON' do
        xhr :get, :badge_types
        expect(::JSON.parse(response.body)["badge_types"]).to be_present
      end
    end

    context '.destroy' do
      it 'returns success' do
        xhr :delete, :destroy, id: badge.id
        expect(response).to be_success
      end

      it 'deletes the badge' do
        xhr :delete, :destroy, id: badge.id
        expect(Badge.where(id: badge.id).count).to eq(0)
      end
    end

    context '.update' do

      it 'does not update the name of system badges' do
        editor_badge = Badge.find(Badge::Editor)
        editor_badge_name = editor_badge.name

        xhr :put, :update,
            id: editor_badge.id,
            name: "123456"

        expect(response).to be_success
        editor_badge.reload
        expect(editor_badge.name).to eq(editor_badge_name)
      end

      it 'does not allow query updates if badge_sql is disabled' do
        badge.query = "select 123"
        badge.save

        SiteSetting.enable_badge_sql = false

        xhr :put, :update,
            id: badge.id,
            name: "123456",
            query: "select id user_id, created_at granted_at from users",
            badge_type_id: badge.badge_type_id,
            allow_title: false,
            multiple_grant: false,
            enabled: true

        expect(response).to be_success
        badge.reload
        expect(badge.name).to eq('123456')
        expect(badge.query).to eq('select 123')
      end

      it 'updates the badge' do
        SiteSetting.enable_badge_sql = true
        sql = "select id user_id, created_at granted_at from users"

        xhr :put, :update,
            id: badge.id,
            name: "123456",
            query: sql,
            badge_type_id: badge.badge_type_id,
            allow_title: false,
            multiple_grant: false,
            enabled: true

        expect(response).to be_success
        badge.reload
        expect(badge.name).to eq('123456')
        expect(badge.query).to eq(sql)
      end
    end
  end
end
