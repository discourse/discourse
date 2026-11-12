# frozen_string_literal: true

module DiscourseEvents
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
        original_starts_at: 5.minutes.ago.iso8601,
        original_ends_at: 1.hour.from_now.iso8601,
      )
    end

    before do
      SiteSetting.discourse_events_enabled = true
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

      context "when the event allows anonymous attendance" do
        before { event.update!(allow_anonymous_livestream: true) }

        it "allows a guest to skip the join window in development" do
          Rails.env.stubs(:development?).returns(true)
          event.update!(original_starts_at: 2.hours.from_now, original_ends_at: 3.hours.from_now)

          get "/discourse-calendar/livestream/zoom/signature.json",
              params: {
                topic_id: topic.id,
                ignore_timeframe: true,
              }

          expect(response.status).to eq(200)
          expect(response.parsed_body["signature"]).to be_present
        end

        it "enforces the join window for guests outside development" do
          event.update!(original_starts_at: 2.hours.from_now, original_ends_at: 3.hours.from_now)

          get "/discourse-calendar/livestream/zoom/signature.json",
              params: {
                topic_id: topic.id,
                ignore_timeframe: true,
              }

          expect(response.status).to eq(404)
        end

        it "returns the Zoom join payload with a guest identity" do
          get "/discourse-calendar/livestream/zoom/signature.json", params: { topic_id: topic.id }

          expect(response.status).to eq(200)
          expect(response.parsed_body).to include(
            "meeting_number" => "123456789",
            "user_name" => I18n.t("discourse_post_event.zoom_guest"),
            "user_email" => a_string_matching(/\Aguest-[0-9a-f]+@example\.com\z/),
          )
        end

        it "honors the site's login requirement" do
          SiteSetting.login_required = true

          get "/discourse-calendar/livestream/zoom/signature.json", params: { topic_id: topic.id }

          expect(response.status).to eq(403)
        end

        it "honors topic visibility" do
          topic.update!(category: Fabricate(:private_category, group: Fabricate(:group)))

          get "/discourse-calendar/livestream/zoom/signature.json", params: { topic_id: topic.id }

          expect(response.status).to eq(404)
        end

        it "withholds Zoom credentials when the opening post is hidden" do
          post.hide!(PostActionType.types[:spam])

          get "/discourse-calendar/livestream/zoom/signature.json", params: { topic_id: topic.id }

          expect(response.status).to eq(404)
        end

        it "withholds Zoom credentials when the event is soft-deleted" do
          event.update_column(:deleted_at, Time.current)

          get "/discourse-calendar/livestream/zoom/signature.json", params: { topic_id: topic.id }

          expect(response.status).to eq(404)
        end
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

        it "returns a signature the Zoom SDK can verify" do
          get "/discourse-calendar/livestream/zoom/signature.json", params: { topic_id: topic.id }

          claims =
            JWT.decode(response.parsed_body["signature"], "sdk-secret", true, algorithm: "HS256")[0]

          expect(claims["sdkKey"]).to eq("sdk-key")
          expect(claims["mn"]).to eq("123456789")
          expect(claims["role"]).to eq(0)
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
          event.update!(location: "https://www.youtube.com/live/abc123")

          get "/discourse-calendar/livestream/zoom/signature.json", params: { topic_id: topic.id }

          expect(response.status).to eq(404)
        end

        it "returns not found when the event is outside its timeframe" do
          event.update!(
            original_starts_at: 2.hours.from_now.iso8601,
            original_ends_at: 3.hours.from_now.iso8601,
          )

          get "/discourse-calendar/livestream/zoom/signature.json", params: { topic_id: topic.id }

          expect(response.status).to eq(404)
        end

        it "returns not found when the livestream URL is not served over HTTPS" do
          event.update_columns(location: "http://zoom.us/j/123456789")

          get "/discourse-calendar/livestream/zoom/signature.json", params: { topic_id: topic.id }

          expect(response.status).to eq(404)
        end
      end
    end

    describe "#zoom_frame" do
      it "rejects anonymous users" do
        get "/discourse-calendar/livestream/zoom/frame", params: { topic_id: topic.id }

        expect(response.status).to eq(404)
      end

      it "serves the meeting frame when the event allows anonymous attendance" do
        event.update!(allow_anonymous_livestream: true)

        get "/discourse-calendar/livestream/zoom/frame", params: { topic_id: topic.id }

        expect(response.status).to eq(200)
        expect(response.body).to include('"anonymous":true')
      end

      it "withholds the meeting frame from guests when the opening post is hidden" do
        event.update!(allow_anonymous_livestream: true)
        post.hide!(PostActionType.types[:spam])

        get "/discourse-calendar/livestream/zoom/frame", params: { topic_id: topic.id }

        expect(response.status).to eq(404)
      end

      context "when signed in" do
        before { sign_in(current_user) }

        it "serves the page the meeting runs in" do
          get "/discourse-calendar/livestream/zoom/frame", params: { topic_id: topic.id }

          expect(response.status).to eq(200)
          expect(response.body).to include("zoomFrameConfig")
        end

        it "joins the meeting with chat disabled" do
          get "/discourse-calendar/livestream/zoom/frame", params: { topic_id: topic.id }

          expect(response.body).to include("isSupportChat: false")
        end

        it "points the page at the signature for its own topic" do
          get "/discourse-calendar/livestream/zoom/frame", params: { topic_id: topic.id }

          expect(response.body).to include(
            "/discourse-calendar/livestream/zoom/signature.json?topic_id=#{topic.id}",
          )
        end

        # Zoom leaves the webinar by navigating this page to its own URL with
        # the flag set, which is the only notice the app around it gets.
        it "tells the app the user has left when Zoom returns them" do
          get "/discourse-calendar/livestream/zoom/frame", params: { topic_id: topic.id, left: 1 }

          expect(response.status).to eq(200)
          expect(response.body).to include("\"hasLeft\":true")
        end

        it "returns not found when the topic does not exist" do
          get "/discourse-calendar/livestream/zoom/frame", params: { topic_id: -1 }

          expect(response.status).to eq(404)
        end

        it "returns not found when the topic cannot be seen" do
          group = Fabricate(:group)
          private_category = Fabricate(:private_category, group: group)
          private_topic = Fabricate(:topic, category: private_category, tags: [tag])

          get "/discourse-calendar/livestream/zoom/frame", params: { topic_id: private_topic.id }

          expect(response.status).to eq(404)
        end

        it "returns not found when Zoom embedding is unavailable" do
          SiteSetting.livestream_zoom_enabled = false

          get "/discourse-calendar/livestream/zoom/frame", params: { topic_id: topic.id }

          expect(response.status).to eq(404)
        end

        context "when the site is in a subfolder" do
          before { set_subfolder "/forum" }

          it "returns them to a path the site actually serves" do
            get "/discourse-calendar/livestream/zoom/frame", params: { topic_id: topic.id }

            expect(response.status).to eq(200)
            expect(response.body).to include(
              "#{Discourse.base_url_no_prefix}/forum/discourse-calendar/livestream/zoom/frame?topic_id=#{topic.id}",
            )
            expect(response.body).not_to include("/forum/forum")
          end
        end
      end
    end

    describe "anonymous livestream chat" do
      before do
        SiteSetting.enable_public_channels = true
        SiteSetting.chat_allowed_groups =
          Group::AUTO_GROUPS.values_at(:anonymous_users, :trust_level_0).join("|")
        event.update!(allow_anonymous_livestream: true)
      end

      it "withholds chat messages after the opening post is hidden" do
        channel_id = topic.topic_chat_channel.chat_channel_id

        get "/chat/api/channels/#{channel_id}/messages"
        expect(response.status).to eq(200)

        post.hide!(PostActionType.types[:spam])

        get "/chat/api/channels/#{channel_id}/messages"
        expect(response.status).to eq(403)
      end

      it "allows thread reads until the opening post is hidden" do
        channel = topic.topic_chat_channel.chat_channel
        channel.update!(threading_enabled: true)
        thread = Fabricate(:chat_thread, channel:)
        path = "/chat/api/channels/#{channel.id}/threads/#{thread.id}/messages"

        get path
        expect(response.status).to eq(200)

        post.hide!(PostActionType.types[:spam])

        get path
        expect(response.status).to eq(403)
      end
    end

    # The full-page mobile Zoom view is a client-side route rendered by the topic
    # controller, so the server just needs to serve the topic at that path.
    describe "the full-page Zoom route" do
      it "serves the topic" do
        get "/t/#{topic.slug}/#{topic.id}/zoom"

        expect(response.status).to eq(200)
      end

      it "returns not found for an unknown topic" do
        get "/t/#{topic.slug}/-1/zoom"

        expect(response.status).to eq(404)
      end
    end

    # `post` names the event's post here.
    def request_pause(pause_key)
      process(
        :post,
        "/discourse-calendar/livestream/notification-pause.json",
        params: {
          topic_id: topic.id,
          pause_key:,
        },
      )
    end

    describe "#pause_notifications" do
      let(:pause_key) { SecureRandom.uuid }

      it "rejects anonymous users" do
        request_pause(pause_key)

        expect(response.status).to eq(403)
      end

      it "pauses notifications until the event ends" do
        sign_in(current_user)

        request_pause(pause_key)

        expect(response.status).to eq(200)
        expect(Time.zone.parse(response.parsed_body["ends_at"])).to eq_time(event.ends_at)
      end

      it "returns not found for a topic the user cannot see" do
        topic.update!(category: Fabricate(:private_category, group: Fabricate(:group)))
        sign_in(current_user)

        request_pause(pause_key)

        expect(response.status).to eq(404)
      end

      it "returns a conflict when the pause was already ended" do
        sign_in(current_user)
        delete "/discourse-calendar/livestream/notification-pause/#{pause_key}.json"

        request_pause(pause_key)

        expect(response.status).to eq(409)
      end
    end

    describe "#resume_notifications" do
      it "rejects anonymous users" do
        delete "/discourse-calendar/livestream/notification-pause/#{SecureRandom.uuid}.json"

        expect(response.status).to eq(403)
      end

      it "succeeds with no content" do
        sign_in(current_user)
        pause_key = SecureRandom.uuid
        request_pause(pause_key)

        delete "/discourse-calendar/livestream/notification-pause/#{pause_key}.json"

        expect(response.status).to eq(204)
      end

      it "rejects a malformed pause key" do
        sign_in(current_user)

        delete "/discourse-calendar/livestream/notification-pause/not-a-key.json"

        expect(response.status).to eq(400)
      end
    end
  end
end
