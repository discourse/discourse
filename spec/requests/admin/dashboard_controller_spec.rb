# frozen_string_literal: true

require 'rails_helper'

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
        { "id" => "1", "emoji" => "🤾", "title" => "Cool Beans", "description" => "Now beans are included" },
        { "id" => "2", "emoji" => "🙈", "title" => "Fancy Legumes", "description" => "Legumes too!" }
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

      context 'new features' do
        it 'has no new features by default' do
          get "/admin/dashboard.json"
          expect(response.status).to eq(200)
          json = response.parsed_body
          expect(json['new_features']).to eq(nil)
        end

        it 'fails gracefully for invalid JSON' do
          Discourse.redis.set("new_features", "INVALID JSON")
          get "/admin/dashboard.json"
          expect(response.status).to eq(200)
          json = response.parsed_body
          expect(json['new_features']).to eq(nil)
        end

        it 'includes new features when available' do
          populate_new_features

          get "/admin/dashboard.json"
          expect(response.status).to eq(200)
          json = response.parsed_body

          expect(json['new_features'].length).to eq(2)
          expect(json['new_features'][0]["emoji"]).to eq("🙈")
          expect(json['new_features'][0]["id"]).to eq("2")

          DiscourseUpdates.reset_new_features(admin.id)
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

    describe '#mark_new_features_as_seen' do
      it 'resets seen id for a given user' do
        populate_new_features
        put "/admin/dashboard/mark_new_features_as_seen.json"

        expect(response.status).to eq(200)
        expect(response.body).to eq("OK")

        expect(DiscourseUpdates.new_features_last_seen(admin.id)).to eq("2")

        DiscourseUpdates.reset_new_features(admin.id)
      end
    end
  end
end
