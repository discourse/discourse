# frozen_string_literal: true

RSpec.describe Admin::ReportsController do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:post) { Fabricate(:post, user: admin, topic: topic) }
  fab!(:classification_result) { Fabricate(:classification_result, target: post) }

  before do
    enable_current_plugin
    SiteSetting.ai_sentiment_enabled = true
  end

  describe "#show sentiment_analysis report" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "allows admins to access the sentiment_analysis report" do
        get "/admin/reports/sentiment_analysis.json"
        expect(response.status).to eq(200)
        expect(response.parsed_body["report"]["type"]).to eq("sentiment_analysis")
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      it "allows moderators to access the sentiment_analysis report" do
        get "/admin/reports/sentiment_analysis.json"
        expect(response.status).to eq(200)
        expect(response.parsed_body["report"]["type"]).to eq("sentiment_analysis")
      end
    end

    context "when logged in as a regular user" do
      before { sign_in(user) }

      it "denies access to regular users" do
        get "/admin/reports/sentiment_analysis.json"
        expect(response.status).to eq(404)
      end
    end

    context "when not logged in" do
      it "denies access to anonymous users" do
        get "/admin/reports/sentiment_analysis.json"
        expect(response.status).to eq(404)
      end
    end
  end
end
