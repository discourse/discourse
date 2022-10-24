# frozen_string_literal: true

RSpec.describe Jobs::CleanUpEmailChangeRequests do
  it "deletes records older than 1 month" do
    very_old = Fabricate(:email_change_request, updated_at: 32.days.ago)
    yesterday = Fabricate(:email_change_request, updated_at: 1.day.ago)
    today = Fabricate(:email_change_request, updated_at: Time.zone.now)

    expect { described_class.new.execute({}) }.to change { EmailChangeRequest.count }.by(-1)
    expect { very_old.reload }.to raise_error(ActiveRecord::RecordNotFound)
    expect(yesterday.reload).to be_present
    expect(today.reload).to be_present
  end
end
