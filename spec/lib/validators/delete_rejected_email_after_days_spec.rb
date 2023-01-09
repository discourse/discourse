# frozen_string_literal: true

describe DeleteRejectedEmailAfterDaysValidator do
  it "is not valid if value is smaller than the value of SiteSetting.delete_email_logs_after_days" do
    SiteSetting.delete_email_logs_after_days = 90

    expect { SiteSetting.delete_rejected_email_after_days = 89 }.to raise_error(
      Discourse::InvalidParameters,
    )
  end

  it "is not valid if value is greater than #{DeleteRejectedEmailAfterDaysValidator::MAX}" do
    expect {
      SiteSetting.delete_rejected_email_after_days = DeleteRejectedEmailAfterDaysValidator::MAX + 1
    }.to raise_error(Discourse::InvalidParameters)
  end
end
