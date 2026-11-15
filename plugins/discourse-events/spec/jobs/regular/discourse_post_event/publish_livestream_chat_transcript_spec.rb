# frozen_string_literal: true

RSpec.describe Jobs::PublishLivestreamChatTranscript do
  subject(:job) { described_class.new }

  let(:service) { DiscourseEvents::Livestream::PublishChatTranscript }
  let(:conflict) { DiscourseEvents::Livestream::PublishChatTranscript::EventPostChanged }

  it "publishes again from a fresh post when the event post changed meanwhile" do
    calls = 0
    allow(service).to receive(:call) { (calls += 1) == 1 ? raise(conflict) : nil }

    job.execute(event_date_id: 1)

    expect(service).to have_received(:call).twice
  end

  it "gives up once the event post keeps changing" do
    allow(service).to receive(:call).and_raise(conflict)

    expect { job.execute(event_date_id: 1) }.to raise_error(conflict)
    expect(service).to have_received(:call).exactly(described_class::MAX_ATTEMPTS).times
  end
end
