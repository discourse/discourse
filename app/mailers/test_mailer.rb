require_dependency 'email/builder'

class TestMailer < ActionMailer::Base
  default charset: 'UTF-8'
  include Email::Builder

  def send_test(to_address)
    build_email to_address, 'test_mailer'
  end

end
