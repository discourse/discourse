# frozen_string_literal: true

RSpec.describe "message bus integration" do
  it "allows anonymous requests to the messagebus" do
    post "/message-bus/poll"
    expect(response.status).to eq(200)
  end

  it "allows authenticated requests to the messagebus" do
    sign_in Fabricate(:user)
    post "/message-bus/poll"
    expect(response.status).to eq(200)
  end

  it "allows custom cors origins" do
    global_setting :enable_cors, true
    SiteSetting.cors_origins = "https://allowed.example.com"

    post "/message-bus/poll"
    expect(response.headers["Access-Control-Allow-Origin"]).to eq(Discourse.base_url_no_prefix)

    post "/message-bus/poll", headers: { origin: "https://allowed.example.com" }
    expect(response.headers["Access-Control-Allow-Origin"]).to eq("https://allowed.example.com")

    post "/message-bus/poll", headers: { origin: "https://not-allowed.example.com" }
    expect(response.headers["Access-Control-Allow-Origin"]).to eq(Discourse.base_url_no_prefix)
  end

  context "with login_required" do
    before { SiteSetting.login_required = true }

    it "blocks anonymous requests to the messagebus" do
      post "/message-bus/poll"
      expect(response.status).to eq(403)
    end

    it "allows authenticated requests to the messagebus" do
      sign_in Fabricate(:user)
      post "/message-bus/poll"
      expect(response.status).to eq(200)
    end
  end

  describe "limiting messages to group_ids" do
    fab!(:group_1, :group)
    fab!(:group_2, :group)

    # dlp=t disables long polling so the response comes back immediately,
    # SecureRandom.hex is the client ID which doesn't matter here
    let(:message_bus_url) { "/message-bus/#{SecureRandom.hex}/poll?dlp=t" }
    let(:test_channel) { "/test-channel" }

    # Publishes to the channel, then polls as the current client from just before
    # that message, so the response contains only the message we published.
    def publish_and_poll(group_ids)
      message_id = MessageBus.publish(test_channel, "hello", group_ids: group_ids)

      post(message_bus_url, params: { test_channel => message_id - 1 })
      expect(response.status).to eq(200)

      message_id
    end

    def allowed_response(message_id)
      [hash_including("channel" => test_channel, "message_id" => message_id, "data" => "hello")]
    end

    # A message the client may not see is filtered out, and MessageBus returns a
    # /__status message instead, fast-forwarding the client past that message.
    def disallowed_response(message_id)
      [
        {
          "global_id" => -1,
          "message_id" => -1,
          "channel" => "/__status",
          "data" => {
            test_channel => message_id,
          },
        },
      ]
    end

    context "when the user is logged in" do
      fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }

      before { sign_in(user) }

      it "receives messages for the logged_in_users pseudogroup" do
        message_id = publish_and_poll([Group::AUTO_GROUPS[:logged_in_users]])

        expect(response.parsed_body).to match(allowed_response(message_id))
      end

      it "receives messages for a specific group that the user is a member of" do
        group_1.add(user)

        message_id = publish_and_poll([group_1.id])

        expect(response.parsed_body).to match(allowed_response(message_id))
      end

      it "does not receive messages for a specific group that the user is not a member of" do
        message_id = publish_and_poll([group_1.id])

        expect(response.parsed_body).to match(disallowed_response(message_id))
      end

      it "does not receive messages for the anonymous_users pseudogroup" do
        message_id = publish_and_poll([Group::AUTO_GROUPS[:anonymous_users]])

        expect(response.parsed_body).to match(disallowed_response(message_id))
      end

      context "when granular_anonymous_and_logged_in_groups_permissions is enabled" do
        before { SiteSetting.granular_anonymous_and_logged_in_groups_permissions = true }

        it "does not receive messages for the everyone pseudogroup" do
          message_id = publish_and_poll([Group::AUTO_GROUPS[:everyone]])

          expect(response.parsed_body).to match(disallowed_response(message_id))
        end
      end

      context "when granular_anonymous_and_logged_in_groups_permissions is disabled" do
        before { SiteSetting.granular_anonymous_and_logged_in_groups_permissions = false }

        it "receives messages for the everyone pseudogroup" do
          message_id = publish_and_poll([Group::AUTO_GROUPS[:everyone]])

          expect(response.parsed_body).to match(allowed_response(message_id))
        end
      end

      context "when the user is admin" do
        fab!(:user) { Fabricate(:admin, refresh_auto_groups: true) }

        it "receives all messages regardless of group" do
          message_id = publish_and_poll([group_1.id])
          expect(response.parsed_body).to match(allowed_response(message_id))

          message_id = publish_and_poll([group_2.id])
          expect(response.parsed_body).to match(allowed_response(message_id))

          message_id = publish_and_poll([Group::AUTO_GROUPS[:logged_in_users]])
          expect(response.parsed_body).to match(allowed_response(message_id))
        end
      end
    end

    context "when the user is anonymous" do
      it "receives messages for the anonymous_users pseudogroup" do
        message_id = publish_and_poll([Group::AUTO_GROUPS[:anonymous_users]])

        expect(response.parsed_body).to match(allowed_response(message_id))
      end

      it "does not receive messages for the everyone pseudogroup" do
        message_id = publish_and_poll([Group::AUTO_GROUPS[:everyone]])

        expect(response.parsed_body).to match(disallowed_response(message_id))
      end

      it "does not receive messages for a specific group" do
        message_id = publish_and_poll([group_1.id])

        expect(response.parsed_body).to match(disallowed_response(message_id))
      end
    end
  end
end
