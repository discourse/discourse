# frozen_string_literal: true

require 'rails_helper'

describe Jobs::ActivationReminderEmails do
  before { Jobs.run_immediately! }

  # should be between 2 and 3 days
  let(:created_at) { 50.hours.ago }

  it 'should email inactive users' do
    user = Fabricate(:user, active: false, created_at: created_at)

    expect { described_class.new.execute({}) }
      .to change { ActionMailer::Base.deliveries.size }.by(1)
      .and change { user.email_tokens.count }.by(1)

    expect(user.custom_fields['activation_reminder']).to eq("t")
    expect { described_class.new.execute({}) }.to change { ActionMailer::Base.deliveries.size }.by(0)

    user.activate
    expect(user.reload.custom_fields['activation_reminder']).to eq(nil)
  end

  it 'should not email active users' do
    user = Fabricate(:user, active: true, created_at: created_at)

    expect { described_class.new.execute({}) }
      .to change { ActionMailer::Base.deliveries.size }.by(0)
      .and change { user.email_tokens.count }.by(0)
  end

  it 'should not email staged users' do
    user = Fabricate(:user, active: false, staged: true, created_at: created_at)

    expect { described_class.new.execute({}) }
      .to change { ActionMailer::Base.deliveries.size }.by(0)
      .and change { user.email_tokens.count }.by(0)
  end
end
