# frozen_string_literal: true

RSpec.describe DiscourseCalendar::Livestream::PrepareZoomJoin do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:topic_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, guardian:) }

    fab!(:current_user, :user)
    fab!(:tag) { Fabricate(:tag, name: "livestream") }
    fab!(:topic) { Fabricate(:topic, user: current_user, tags: [tag]) }
    fab!(:post) { Fabricate(:post, user: current_user, topic: topic, post_number: 1) }
    fab!(:event) do
      Fabricate(
        :event,
        post: post,
        livestream: true,
        location: "https://us06web.zoom.us/j/123456789?pwd=secret",
      )
    end

    let(:guardian) { current_user.guardian }
    let(:params) { { topic_id: topic.id } }

    before do
      SiteSetting.calendar_enabled = true
      SiteSetting.discourse_post_event_enabled = true
      SiteSetting.livestream_zoom_enabled = true
      SiteSetting.livestream_zoom_sdk_key = "sdk-key"
      SiteSetting.livestream_zoom_sdk_secret = "sdk-secret"
    end

    context "when the contract is invalid" do
      let(:params) { { topic_id: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when post events are not enabled" do
      before { SiteSetting.discourse_post_event_enabled = false }

      it { is_expected.to fail_a_policy(:livestream_available) }
    end

    context "when Zoom embedding is disabled" do
      before { SiteSetting.livestream_zoom_enabled = false }

      it { is_expected.to fail_a_policy(:zoom_enabled) }
    end

    context "when the topic cannot be seen" do
      fab!(:group)
      fab!(:private_category) { Fabricate(:private_category, group:) }
      fab!(:private_topic) do
        Fabricate(:topic, user: current_user, category: private_category, tags: [tag])
      end
      fab!(:private_post) do
        Fabricate(:post, user: current_user, topic: private_topic, post_number: 1)
      end
      fab!(:private_event) do
        Fabricate(
          :event,
          post: private_post,
          livestream: true,
          location: "https://zoom.us/j/123456789?pwd=secret",
        )
      end
      fab!(:outsider, :user)

      let(:params) { { topic_id: private_topic.id } }
      let(:guardian) { outsider.guardian }

      it { is_expected.to fail_a_policy(:can_see_topic) }
    end

    context "when there is no first-post event" do
      fab!(:topic_without_event) { Fabricate(:topic, user: current_user, tags: [tag]) }
      fab!(:topic_without_event_post) do
        Fabricate(:post, user: current_user, topic: topic_without_event, post_number: 1)
      end

      let(:params) { { topic_id: topic_without_event.id } }

      it { is_expected.to fail_to_find_a_model(:event) }
    end

    context "when the event is not a livestream" do
      before { event.update!(livestream: false) }

      it { is_expected.to fail_a_policy(:event_has_livestream) }
    end

    context "when the livestream has no location or URL" do
      before { event.update_columns(location: nil, url: nil) }

      it { is_expected.to fail_a_policy(:event_has_livestream) }
    end

    context "when the livestream URL is not a supported Zoom URL" do
      before { event.update!(location: "https://example.com/stream") }

      it { is_expected.to fail_to_find_a_model(:zoom_join_data) }
    end

    context "when everything is valid" do
      it { is_expected.to run_successfully }

      it "returns the Zoom join payload" do
        expect(result.zoom_join_payload).to include(
          sdk_key: "sdk-key",
          signature: be_present,
          meeting_number: "123456789",
          password: "secret",
          user_name: current_user.display_name,
          user_email: current_user.email,
          leave_url: topic.relative_url,
        )
      end
    end
  end
end
