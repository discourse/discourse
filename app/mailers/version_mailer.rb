require_dependency 'email/message_builder'

class VersionMailer < ActionMailer::Base
  include Email::BuildEmailHelper

  def send_notice
    if SiteSetting.contact_email.present?
      build_email( SiteSetting.contact_email,
                   template: 'new_version_mailer',
                   new_version: DiscourseUpdates.latest_version,
                   installed_version: Discourse::VERSION::STRING )
    end
  end
end
