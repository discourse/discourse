# frozen_string_literal: true

module DiscourseCalendar
  describe LivestreamController do
    fab!(:current_user, :user)
    fab!(:tag) { Fabricate(:tag, name: "livestream") }
    fab!(:topic) { Fabricate(:topic, user: current_user, tags: [tag]) }
    fab!(:post) { Fabricate(:post, user: current_user, topic: topic, post_number: 1) }
    fab!(:event) do
      Fabricate(:event, post: post, url: "https://us06web.zoom.us/j/123456789?pwd=secret")
    end

    before do
      SiteSetting.calendar_enabled = true
      SiteSetting.discourse_post_event_enabled = true
      SiteSetting.livestream_zoom_enabled = true
      SiteSetting.livestream_zoom_sdk_key = "sdk-key"
      SiteSetting.livestream_zoom_sdk_secret = "sdk-secret"
    end

    describe "#signature" do
      it "returns the Zoom join payload" do
        sign_in(current_user)

        get "/discourse-calendar/livestream/zoom/signature.json", params: { topic_id: topic.id }

        expect(response.status).to eq(200)
        expect(response.parsed_body["sdk_key"]).to eq("sdk-key")
        expect(response.parsed_body["meeting_number"]).to eq("123456789")
        expect(response.parsed_body["password"]).to eq("secret")
        expect(response.parsed_body["user_name"]).to eq(current_user.name)
        expect(response.parsed_body["user_email"]).to eq(current_user.email)
        expect(response.parsed_body["leave_url"]).to eq(topic.relative_url)
        expect(response.parsed_body["signature"]).to be_present
      end

      it "rejects anonymous users" do
        get "/discourse-calendar/livestream/zoom/signature.json", params: { topic_id: topic.id }

        expect(response.status).to eq(403)
      end

      it "returns 404 when the topic is not joinable" do
        sign_in(current_user)
        event.update!(url: "https://example.com/stream")

        get "/discourse-calendar/livestream/zoom/signature.json", params: { topic_id: topic.id }

        expect(response.status).to eq(404)
      end
    end
  end
end
