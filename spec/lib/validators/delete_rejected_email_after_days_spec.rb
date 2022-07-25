# frozen_string_literal: true

describe DeleteRejectedEmailAfterDaysValidator do

  it 'will not set delete rejected emails setting earlier than removing the email logs' do
    SiteSetting.delete_email_logs_after_days = 90

    expect { SiteSetting.delete_rejected_email_after_days = 89 }.to raise_error(Discourse::InvalidParameters)
  end

end
