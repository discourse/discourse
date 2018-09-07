require_dependency 'email/message_builder'

class ApplicationMailer < ActionMailer::Base
  include Email::BuildEmailHelper

  after_action :secondary_delivery, if: proc { SiteSetting.enable_secondary_smtp }

  private
  def secondary_delivery
    mail.delivery_method.settings = self.class.secondary_smtp_settings
  end

  def self.secondary_smtp_settings
    settings = {
      address:              SiteSetting.smtp_address,
      port:                 SiteSetting.smtp_port,
      domain:               SiteSetting.smtp_domain,
      user_name:            SiteSetting.smtp_user_name,
      password:             SiteSetting.smtp_password,
      authentication:       SiteSetting.smtp_authentication,
      enable_starttls_auto: SiteSetting.smtp_enable_start_tls
    }

    settings[:openssl_verify_mode] = SiteSetting.smtp_openssl_verify_mode if SiteSetting.smtp_openssl_verify_mode
    settings.reject { |_, y| y.blank? }
  end
end
