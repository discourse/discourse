require_dependency 'email/message_builder'

class SubscriptionMailer < ActionMailer::Base
  include Email::BuildEmailHelper

  def confirm_unsubscribe(user, opts={})
    unsubscribe_key = DigestUnsubscribeKey.create_key_for(user)
    build_email user.email,
                template: "unsubscribe_mailer",
                site_title: SiteSetting.title,
                site_domain_name: Discourse.current_hostname,
                confirm_unsubscribe_link: "#{Discourse.base_url}/unsubscribe/#{unsubscribe_key}?from_all=true"
  end
end
