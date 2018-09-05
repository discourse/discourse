class TestMailer < ApplicationMailer

  def send_test(to_address)
    build_email(to_address, template: 'test_mailer')
  end
end
