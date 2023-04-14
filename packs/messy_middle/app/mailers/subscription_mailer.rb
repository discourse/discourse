# frozen_string_literal: true

class SubscriptionMailer < ActionMailer::Base
  include Email::BuildEmailHelper

  def confirm_unsubscribe(user, opts = {})
    unsubscribe_key = UnsubscribeKey.create_key_for(user, UnsubscribeKey::ALL_TYPE)
    build_email user.email,
                template: "unsubscribe_mailer",
                site_title: SiteSetting.title,
                site_domain_name: Discourse.current_hostname,
                confirm_unsubscribe_link:
                  email_unsubscribe_url(unsubscribe_key, host: Discourse.base_url)
  end
end
