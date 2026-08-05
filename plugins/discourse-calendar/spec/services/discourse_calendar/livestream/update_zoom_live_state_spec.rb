# frozen_string_literal: true

RSpec.describe DiscourseCalendar::Livestream::UpdateZoomLiveState do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:meeting_number) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:topic)
    fab!(:post) { Fabricate(:post, topic: topic, post_number: 1) }
    fab!(:event) do
      Fabricate(
        :event,
        post: post,
        livestream: true,
        location: "https://us06web.zoom.us/j/123456789?pwd=secret",
      )
    end

    let(:dependencies) { {} }
    let(:meeting_number) { "123456789" }
    let(:live) { true }
    let(:params) { { meeting_number:, live: } }
    let(:channel) { "/discourse-calendar/livestream/zoom/#{topic.id}" }
    let(:messages) { MessageBus.track_publish(channel) { result } }

    before do
      SiteSetting.calendar_enabled = true
      SiteSetting.discourse_post_event_enabled = true
      SiteSetting.livestream_zoom_enabled = true
    end

    context "when the contract is invalid" do
      let(:meeting_number) { "" }

      it { is_expected.to fail_a_contract }
    end

    context "when no event points at the meeting number" do
      let(:meeting_number) { "999999999" }

      it { is_expected.to fail_to_find_a_model(:events) }

      it "does not record the meeting as live" do
        result

        expect(DiscourseCalendar::Livestream::ZoomLiveMeetings.live?(meeting_number)).to eq(false)
      end
    end

    context "when the meeting started" do
      it { is_expected.to run_successfully }

      it "records the meeting as live" do
        expect { result }.to change {
          DiscourseCalendar::Livestream::ZoomLiveMeetings.live?(meeting_number)
        }.from(false).to(true)
      end

      it "pushes the live state to the event's topic" do
        expect(messages.map(&:data)).to eq([{ live: true }])
      end
    end

    context "when the meeting ended" do
      let(:live) { false }

      before { DiscourseCalendar::Livestream::ZoomLiveMeetings.started(meeting_number) }

      it { is_expected.to run_successfully }

      it "records the meeting as no longer live" do
        expect { result }.to change {
          DiscourseCalendar::Livestream::ZoomLiveMeetings.live?(meeting_number)
        }.from(true).to(false)
      end

      it "pushes the live state to the event's topic" do
        expect(messages.map(&:data)).to eq([{ live: false }])
      end
    end

    context "with several events on the same meeting" do
      fab!(:other_topic, :topic)
      fab!(:other_post) { Fabricate(:post, topic: other_topic, post_number: 1) }
      fab!(:other_event) do
        Fabricate(
          :event,
          post: other_post,
          livestream: true,
          location: "https://zoom.us/j/123456789",
        )
      end

      let(:messages) { MessageBus.track_publish { result } }

      it "pushes to each topic's own channel" do
        livestream_messages =
          messages.select do |message|
            message.channel.start_with?("/discourse-calendar/livestream")
          end

        expect(livestream_messages.map(&:channel)).to contain_exactly(
          "/discourse-calendar/livestream/zoom/#{topic.id}",
          "/discourse-calendar/livestream/zoom/#{other_topic.id}",
        )
      end
    end
  end
end
