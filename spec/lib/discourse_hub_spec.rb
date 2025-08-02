# frozen_string_literal: true

RSpec.describe DiscourseHub do
  describe ".discourse_version_check" do
    it "should return just return the json that the hub returns" do
      hub_response = { "success" => "OK", "latest_version" => "0.8.1", "critical_updates" => false }

      stub_request(
        :get,
        (ENV["HUB_BASE_URL"] || "http://local.hub:3000/api") + "/version_check",
      ).with(query: DiscourseHub.version_check_payload).to_return(
        status: 200,
        body: hub_response.to_json,
      )

      expect(DiscourseHub.discourse_version_check).to eq(hub_response)
    end
  end

  describe ".discover_enrollment" do
    it "should trigger a POST request to hub" do
      stub_request(
        :post,
        (ENV["HUB_BASE_URL"] || "http://local.hub:3000/api") + "/discover/enroll",
      ).with(body: JSON[DiscourseHub.discover_enrollment_payload]).to_return(
        status: 200,
        body: "",
        headers: {
        },
      )

      DiscourseHub.discover_enrollment
    end
  end

  describe ".discover_enrollment_payload" do
    it "should return the correct payload" do
      payload = DiscourseHub.discover_enrollment_payload
      expect(payload[:forum_url]).to eq(Discourse.base_url)
      expect(payload[:forum_title]).to eq(SiteSetting.title)
      expect(payload[:locale]).to eq(I18n.locale)
    end
  end

  describe ".version_check_payload" do
    describe "when Discourse Hub has not fetched stats since past 7 days" do
      it "should include stats" do
        DiscourseHub.stats_fetched_at = 8.days.ago
        json = JSON.parse(DiscourseHub.version_check_payload.to_json)

        expect(json["topics_count"]).to be_present
        expect(json["posts_count"]).to be_present
        expect(json["users_count"]).to be_present
        expect(json["topics_7_days"]).to be_present
        expect(json["topics_30_days"]).to be_present
        expect(json["posts_7_days"]).to be_present
        expect(json["posts_30_days"]).to be_present
        expect(json["users_7_days"]).to be_present
        expect(json["users_30_days"]).to be_present
        expect(json["active_users_7_days"]).to be_present
        expect(json["active_users_30_days"]).to be_present
        expect(json["likes_count"]).to be_present
        expect(json["likes_7_days"]).to be_present
        expect(json["likes_30_days"]).to be_present
        expect(json["participating_users_7_days"]).to be_present
        expect(json["participating_users_30_days"]).to be_present
        expect(json["installed_version"]).to be_present
        expect(json["branch"]).to be_present
      end
    end

    describe "when Discourse Hub has fetched stats in past 7 days" do
      it "should not include stats" do
        DiscourseHub.stats_fetched_at = 2.days.ago
        json = JSON.parse(DiscourseHub.version_check_payload.to_json)

        expect(json["topic_count"]).not_to be_present
        expect(json["post_count"]).not_to be_present
        expect(json["user_count"]).not_to be_present
        expect(json["like_count"]).not_to be_present
        expect(json["likes_7_days"]).not_to be_present
        expect(json["likes_30_days"]).not_to be_present
        expect(json["installed_version"]).to be_present
        expect(json["branch"]).to be_present
      end
    end

    describe "when send_anonymize_stats is disabled" do
      describe "when Discourse Hub has not fetched stats for the past year" do
        it "should not include stats" do
          DiscourseHub.stats_fetched_at = 1.year.ago
          SiteSetting.share_anonymized_statistics = false
          json = JSON.parse(DiscourseHub.version_check_payload.to_json)

          expect(json["topic_count"]).not_to be_present
          expect(json["post_count"]).not_to be_present
          expect(json["user_count"]).not_to be_present
          expect(json["like_count"]).not_to be_present
          expect(json["likes_7_days"]).not_to be_present
          expect(json["likes_30_days"]).not_to be_present
          expect(json["installed_version"]).to be_present
          expect(json["branch"]).to be_present
        end
      end
    end
  end

  describe ".collection_action" do
    let(:fake_logger) { FakeLogger.new }

    before { Rails.logger.broadcast_to(fake_logger) }

    after { Rails.logger.stop_broadcasting_to(fake_logger) }

    it "should log correctly on error" do
      stub_request(:get, (ENV["HUB_BASE_URL"] || "http://local.hub:3000/api") + "/test").to_return(
        status: 500,
        body: "",
        headers: {
        },
      )

      DiscourseHub.collection_action(:get, "/test")

      expect(fake_logger.warnings).to eq([DiscourseHub.response_status_log_message("/test", 500)])

      expect(fake_logger.errors).to eq([DiscourseHub.response_body_log_message("")])
    end
  end
end
