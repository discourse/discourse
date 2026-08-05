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
        original_starts_at: 5.minutes.ago.iso8601,
        original_ends_at: 1.hour.from_now.iso8601,
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
          event.update!(location: "https://example.com/stream")

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

    describe "#zoom_webhook" do
      let(:secret) { "webhook-secret" }
      let(:meeting_number) { "123456789" }

      before { SiteSetting.livestream_zoom_webhook_secret_token = secret }

      def post_webhook(payload, signature: nil, timestamp: Time.now.to_i, token: secret)
        body = payload.to_json
        signature ||= "v0=#{OpenSSL::HMAC.hexdigest("SHA256", token, "v0:#{timestamp}:#{body}")}"

        # `post` is shadowed by the fabricated post.
        process :post,
                "/discourse-calendar/livestream/zoom/webhook",
                params: body,
                headers: {
                  "CONTENT_TYPE" => "application/json",
                  "HTTP_X_ZM_REQUEST_TIMESTAMP" => timestamp.to_s,
                  "HTTP_X_ZM_SIGNATURE" => signature,
                }
      end

      def started_payload
        { event: "webinar.started", payload: { object: { id: meeting_number } } }
      end

      it "accepts a correctly signed webinar.started and marks the meeting live" do
        messages =
          MessageBus.track_publish("/discourse-calendar/livestream/zoom/#{topic.id}") do
            post_webhook(started_payload)
          end

        expect(response.status).to eq(200)
        expect(Livestream::ZoomLiveMeetings.live?(meeting_number)).to eq(true)
        expect(messages.map { |m| m.data["live"] || m.data[:live] }).to eq([true])
      end

      it "restricts the push to participants when the event is in a personal message" do
        pm = Fabricate(:private_message_topic, user: current_user)
        pm_post = Fabricate(:post, user: current_user, topic: pm, post_number: 1)
        Fabricate(
          :event,
          post: pm_post,
          location: "https://us06web.zoom.us/j/#{meeting_number}?pwd=secret",
          livestream: true,
        )

        messages =
          MessageBus.track_publish("/discourse-calendar/livestream/zoom/#{pm.id}") do
            post_webhook(started_payload)
          end

        expect(messages.size).to eq(1)
        # Core's audience helper adds staff on top of the participants.
        expect(messages.first.user_ids).to include(*pm.allowed_users.pluck(:id))
        expect(messages.first.group_ids).to be_blank
      end

      it "clears the live state when the webinar ends" do
        Livestream::ZoomLiveMeetings.started(meeting_number)

        post_webhook({ event: "webinar.ended", payload: { object: { id: meeting_number } } })

        expect(response.status).to eq(200)
        expect(Livestream::ZoomLiveMeetings.live?(meeting_number)).to eq(false)
      end

      it "rejects a payload signed with the wrong token" do
        post_webhook(started_payload, token: "not-the-secret")

        expect(response.status).to eq(403)
        expect(Livestream::ZoomLiveMeetings.live?(meeting_number)).to eq(false)
      end

      it "rejects an unsigned payload" do
        process :post,
                "/discourse-calendar/livestream/zoom/webhook",
                params: started_payload.to_json,
                headers: {
                  "CONTENT_TYPE" => "application/json",
                }

        expect(response.status).to eq(403)
        expect(Livestream::ZoomLiveMeetings.live?(meeting_number)).to eq(false)
      end

      it "rejects a replayed payload signed outside the timestamp window" do
        post_webhook(started_payload, timestamp: 1.hour.ago.to_i)

        expect(response.status).to eq(403)
        expect(Livestream::ZoomLiveMeetings.live?(meeting_number)).to eq(false)
      end

      it "answers Zoom's URL validation challenge" do
        post_webhook({ event: "endpoint.url_validation", payload: { plainToken: "abc123" } })

        expect(response.status).to eq(200)
        expect(response.parsed_body["plainToken"]).to eq("abc123")
        expect(response.parsed_body["encryptedToken"]).to eq(
          OpenSSL::HMAC.hexdigest("SHA256", secret, "abc123"),
        )
      end

      it "is closed off entirely when no secret token is configured" do
        SiteSetting.livestream_zoom_webhook_secret_token = ""

        post_webhook(started_payload)

        expect(response.status).to eq(404)
        expect(Livestream::ZoomLiveMeetings.live?(meeting_number)).to eq(false)
      end

      it "ignores a meeting number no event points at" do
        messages =
          MessageBus.track_publish do
            post_webhook({ event: "webinar.started", payload: { object: { id: "999999" } } })
          end

        expect(response.status).to eq(200)
        expect(
          messages.select { |m| m.channel.start_with?("/discourse-calendar/livestream") },
        ).to be_empty
      end
    end
  end
end
