# frozen_string_literal: true

RSpec.describe Jobs::SendEmailLoginCode do
  before { SiteSetting.enable_local_logins_via_code = true }

  it "raises an error without a to_address" do
    expect { described_class.new.execute(code: "123456") }.to raise_error(
      Discourse::InvalidParameters,
      /to_address/,
    )
  end

  it "raises an error without a code" do
    expect { described_class.new.execute(to_address: "foo@example.com") }.to raise_error(
      Discourse::InvalidParameters,
      /code/,
    )
  end

  it "does not send an email when the setting is disabled" do
    SiteSetting.enable_local_logins_via_code = false

    described_class.new.execute(to_address: "foo@example.com", code: "123456")

    expect(ActionMailer::Base.deliveries).to be_empty
  end

  it "sends an email containing the code" do
    described_class.new.execute(to_address: "foo@example.com", code: "123456")

    email = ActionMailer::Base.deliveries.last
    expect(email.to).to contain_exactly("foo@example.com")
    expect(email.subject).to include("123456")
    expect(email.body.to_s).to include("123456")
  end
end
