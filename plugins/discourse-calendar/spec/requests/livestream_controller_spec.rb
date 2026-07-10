# frozen_string_literal: true

module DiscourseCalendar
  describe LivestreamController do
    fab!(:current_user, :user)
    fab!(:tag) { Fabricate(:tag, name: "livestream") }
    fab!(:topic) { Fabricate(:topic, user: current_user, tags: [tag]) }
    fab!(:post) { Fabricate(:post, user: current_user, topic: topic, post_number: 1) }
    fab!(:event) do
      Fabricate(
        :event,
        post: post,
        location: "https://us06web.zoom.us/j/123456789?pwd=secret",
        livestream: true,
      )
    end

    before do
      SiteSetting.calendar_enabled = true
      SiteSetting.discourse_post_event_enabled = true
      SiteSetting.livestream_zoom_enabled = true
      SiteSetting.livestream_zoom_sdk_key = "sdk-key"
      SiteSetting.livestream_zoom_sdk_secret = "sdk-secret"
    end

    describe "#prepare_zoom_signature" do
      it "rejects anonymous users" do
        get "/discourse-calendar/livestream/zoom/signature.json", params: { topic_id: topic.id }

        expect(response.status).to eq(403)
      end

      context "when signed in" do
        before { sign_in(current_user) }

        it "returns the Zoom join payload" do
          get "/discourse-calendar/livestream/zoom/signature.json", params: { topic_id: topic.id }

          expect(response.status).to eq(200)
          expect(response.parsed_body["sdk_key"]).to eq("sdk-key")
          expect(response.parsed_body["meeting_number"]).to eq("123456789")
          expect(response.parsed_body["password"]).to eq("secret")
          expect(response.parsed_body["user_name"]).to eq(current_user.display_name)
          expect(response.parsed_body["user_email"]).to eq(current_user.email)
          expect(response.parsed_body["leave_url"]).to eq(topic.relative_url)
          expect(response.parsed_body["signature"]).to be_present
        end

        it "rejects invalid params" do
          get "/discourse-calendar/livestream/zoom/signature.json"

          expect(response.status).to eq(400)
        end

        it "returns not found when livestreams are unavailable" do
          SiteSetting.discourse_post_event_enabled = false

          get "/discourse-calendar/livestream/zoom/signature.json", params: { topic_id: topic.id }

          expect(response.status).to eq(404)
        end

        it "returns not found when Zoom embedding is unavailable" do
          SiteSetting.livestream_zoom_enabled = false

          get "/discourse-calendar/livestream/zoom/signature.json", params: { topic_id: topic.id }

          expect(response.status).to eq(404)
        end

        it "returns not found when the topic does not exist" do
          get "/discourse-calendar/livestream/zoom/signature.json", params: { topic_id: -1 }

          expect(response.status).to eq(404)
        end

        it "returns not found when the topic cannot be seen" do
          group = Fabricate(:group)
          private_category = Fabricate(:private_category, group: group)
          private_topic = Fabricate(:topic, category: private_category, tags: [tag])
          private_post = Fabricate(:post, topic: private_topic, post_number: 1)
          Fabricate(
            :event,
            post: private_post,
            location: "https://us06web.zoom.us/j/123456789?pwd=secret",
            livestream: true,
          )

          get "/discourse-calendar/livestream/zoom/signature.json",
              params: {
                topic_id: private_topic.id,
              }

          expect(response.status).to eq(404)
        end

        it "returns not found when there is no first-post event" do
          topic_without_event = Fabricate(:topic, user: current_user, tags: [tag])
          Fabricate(:post, user: current_user, topic: topic_without_event, post_number: 1)

          get "/discourse-calendar/livestream/zoom/signature.json",
              params: {
                topic_id: topic_without_event.id,
              }

          expect(response.status).to eq(404)
        end

        it "returns not found when the event is not a livestream" do
          event.update!(livestream: false)

          get "/discourse-calendar/livestream/zoom/signature.json", params: { topic_id: topic.id }

          expect(response.status).to eq(404)
        end

        it "returns not found when the livestream has no location or URL" do
          event.update_columns(location: nil, url: nil)

          get "/discourse-calendar/livestream/zoom/signature.json", params: { topic_id: topic.id }

          expect(response.status).to eq(404)
        end

        it "returns not found when the livestream URL is not a supported Zoom URL" do
          event.update!(location: "https://example.com/stream")

          get "/discourse-calendar/livestream/zoom/signature.json", params: { topic_id: topic.id }

          expect(response.status).to eq(404)
        end
      end
    end
  end
end
