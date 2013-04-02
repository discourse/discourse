require_dependency 'email_builder'

class TestMailer < ActionMailer::Base
  include EmailBuilder

  def send_test(to_address)
    build_email to_address, 'test_mailer'
  end

end
