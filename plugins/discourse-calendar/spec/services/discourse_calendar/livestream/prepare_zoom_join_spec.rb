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
      Fabricate(:event, post: post, url: "https://us06web.zoom.us/j/123456789?pwd=secret")
    end

    let(:guardian) { current_user.guardian }
    let(:params) { { topic_id: topic.id } }

    before do
      SiteSetting.calendar_enabled = true
      SiteSetting.discourse_post_event_enabled = true
      SiteSetting.livestream_enabled = true
      SiteSetting.livestream_zoom_enabled = true
      SiteSetting.livestream_zoom_sdk_key = "sdk-key"
      SiteSetting.livestream_zoom_sdk_secret = "sdk-secret"
    end

    context "when the contract is invalid" do
      let(:params) { { topic_id: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when livestream is disabled" do
      before { SiteSetting.livestream_enabled = false }

      it { is_expected.to fail_a_policy(:livestream_enabled) }
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
        Fabricate(:event, post: private_post, url: "https://zoom.us/j/123456789?pwd=secret")
      end
      fab!(:outsider, :user)

      let(:params) { { topic_id: private_topic.id } }
      let(:guardian) { outsider.guardian }

      it { is_expected.to fail_a_policy(:can_see_topic) }
    end

    context "when the topic is not tagged as a livestream" do
      fab!(:regular_topic) { Fabricate(:topic, user: current_user) }
      fab!(:regular_post) do
        Fabricate(:post, user: current_user, topic: regular_topic, post_number: 1)
      end
      fab!(:regular_event) do
        Fabricate(:event, post: regular_post, url: "https://zoom.us/j/123456789?pwd=secret")
      end

      let(:params) { { topic_id: regular_topic.id } }

      it { is_expected.to fail_a_policy(:topic_has_livestream_tag) }
    end

    context "when there is no first-post event" do
      fab!(:topic_without_event) { Fabricate(:topic, user: current_user, tags: [tag]) }
      fab!(:topic_without_event_post) do
        Fabricate(:post, user: current_user, topic: topic_without_event, post_number: 1)
      end

      let(:params) { { topic_id: topic_without_event.id } }

      it { is_expected.to fail_a_policy(:topic_has_first_post_event) }
    end

    context "when the event URL is not a supported Zoom URL" do
      before { event.update!(url: "https://example.com/stream") }

      it { is_expected.to fail_a_policy(:event_has_zoom_url) }
    end

    context "when everything is valid" do
      it { is_expected.to run_successfully }

      it "returns the Zoom join payload" do
        expect(result.sdk_key).to eq("sdk-key")
        expect(result.signature).to be_present
        expect(result.meeting_number).to eq("123456789")
        expect(result.password).to eq("secret")
        expect(result.user_name).to eq(current_user.name)
        expect(result.user_email).to eq(current_user.email)
        expect(result.leave_url).to eq(topic.relative_url)
      end
    end
  end
end
