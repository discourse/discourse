require 'rails_helper'

describe Jobs::ActivationReminderEmails do
  before do
    Jobs.run_immediately!
  end

  it 'should email inactive users' do
    user = Fabricate(:user, active: false, created_at: 3.days.ago)

    expect { described_class.new.execute({}) }
      .to change { ActionMailer::Base.deliveries.size }.by(1)
      .and change { user.email_tokens.count }.by(1)

    expect(user.custom_fields['activation_reminder']).to eq("t")
    expect { described_class.new.execute({}) }.to change { ActionMailer::Base.deliveries.size }.by(0)

    user.activate
    expect(user.reload.custom_fields['activation_reminder']).to eq(nil)
  end

  it 'should not email active users' do
    user = Fabricate(:user, active: true, created_at: 3.days.ago)

    expect { described_class.new.execute({}) }
      .to change { ActionMailer::Base.deliveries.size }.by(0)
      .and change { user.email_tokens.count }.by(0)
  end
end
