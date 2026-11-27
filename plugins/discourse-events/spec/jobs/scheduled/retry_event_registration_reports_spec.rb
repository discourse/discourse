# frozen_string_literal: true

RSpec.describe Jobs::RetryEventRegistrationReports do
  fab!(:event)
  fab!(:submission) { Fabricate(:event_registration, event:, created_at: 1.hour.ago) }

  before do
    SiteSetting.discourse_events_enabled = true
    SiteSetting.discourse_post_event_enabled = true
  end

  shared_examples "reports after restoration" do
    it "skips scheduled and already-queued reports until the source is restored" do
      record.trash!(Discourse.system_user)
      Jobs::ReportEventRegistrations.clear
      described_class.new.execute({})
      expect(Jobs::ReportEventRegistrations.jobs).to be_empty
      Jobs::ReportEventRegistrations.new.execute(event_id: event.id)
      expect(submission.reload.report_post_id).to be_nil
      expect(event.reload.registration_topic_id).to be_nil

      record.recover!
      described_class.new.execute({})
      Jobs::ReportEventRegistrations.drain
      expect(submission.reload.report_post_id).to be_present
    end
  end

  context "when the event post is trashed" do
    let(:record) { event.post }

    include_examples "reports after restoration"
  end

  context "when the event topic is trashed" do
    let(:record) { event.post.topic }

    include_examples "reports after restoration"
  end
end
