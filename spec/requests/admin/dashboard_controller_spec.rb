# frozen_string_literal: true

describe Admin::DashboardController do
  before do
    AdminDashboardData.stubs(:fetch_cached_stats).returns(reports: [])
    Jobs::VersionCheck.any_instance.stubs(:execute).returns(true)
  end

  it "is a subclass of AdminController" do
    expect(Admin::DashboardController < Admin::AdminController).to eq(true)
  end

  context 'while logged in as an admin' do
    fab!(:admin) { Fabricate(:admin) }

    def populate_new_features
      sample_features = [
        { "id" => "1", "emoji" => "🤾", "title" => "Cool Beans", "description" => "Now beans are included", "created_at" => Time.zone.now - 40.minutes },
        { "id" => "2", "emoji" => "🙈", "title" => "Fancy Legumes", "description" => "Legumes too!",  "created_at" => Time.zone.now - 20.minutes }
      ]

      Discourse.redis.set('new_features', MultiJson.dump(sample_features))
    end

    before do
      sign_in(admin)
    end

    describe '#index' do
      context 'version checking is enabled' do
        before do
          SiteSetting.version_checks = true
        end

        it 'returns discourse version info' do
          get "/admin/dashboard.json"

          expect(response.status).to eq(200)
          expect(response.parsed_body['version_check']).to be_present
        end
      end

      context 'version checking is disabled' do
        before do
          SiteSetting.version_checks = false
        end

        it 'does not return discourse version info' do
          get "/admin/dashboard.json"
          expect(response.status).to eq(200)
          json = response.parsed_body
          expect(json['version_check']).not_to be_present
        end
      end
    end

    describe '#problems' do
      context 'when there are no problems' do
        before do
          AdminDashboardData.stubs(:fetch_problems).returns([])
        end

        it 'returns an empty array' do
          get "/admin/dashboard/problems.json"

          expect(response.status).to eq(200)
          json = response.parsed_body
          expect(json['problems'].size).to eq(0)
        end
      end

      context 'when there are problems' do
        before do
          AdminDashboardData.stubs(:fetch_problems).returns(['Not enough awesome', 'Too much sass'])
        end

        it 'returns an array of strings' do
          get "/admin/dashboard/problems.json"
          expect(response.status).to eq(200)
          json = response.parsed_body
          expect(json['problems'].size).to eq(2)
          expect(json['problems'][0]).to be_a(String)
          expect(json['problems'][1]).to be_a(String)
        end
      end
    end

    describe '#new_features' do
      before do
        Discourse.redis.del "new_features_last_seen_user_#{admin.id}"
        Discourse.redis.del "new_features"
      end

      it 'is empty by default' do
        get "/admin/dashboard/new-features.json"
        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json['new_features']).to eq(nil)
      end

      it 'fails gracefully for invalid JSON' do
        Discourse.redis.set("new_features", "INVALID JSON")
        get "/admin/dashboard/new-features.json"
        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json['new_features']).to eq(nil)
      end

      it 'includes new features when available' do
        populate_new_features

        get "/admin/dashboard/new-features.json"
        expect(response.status).to eq(200)
        json = response.parsed_body

        expect(json['new_features'].length).to eq(2)
        expect(json['new_features'][0]["emoji"]).to eq("🙈")
        expect(json['new_features'][0]["title"]).to eq("Fancy Legumes")
        expect(json['has_unseen_features']).to eq(true)
      end

      it 'passes unseen feature state' do
        populate_new_features
        DiscourseUpdates.mark_new_features_as_seen(admin.id)

        get "/admin/dashboard/new-features.json"
        expect(response.status).to eq(200)
        json = response.parsed_body

        expect(json['has_unseen_features']).to eq(false)
      end
    end

    describe '#mark_new_features_as_seen' do
      it 'resets last seen for a given user' do
        populate_new_features
        put "/admin/dashboard/mark-new-features-as-seen.json"

        expect(response.status).to eq(200)
        expect(DiscourseUpdates.new_features_last_seen(admin.id)).not_to eq(nil)
        expect(DiscourseUpdates.has_unseen_features?(admin.id)).to eq(false)
      end
    end
  end
end
