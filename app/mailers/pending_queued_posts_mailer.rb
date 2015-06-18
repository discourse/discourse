require_dependency 'email/message_builder'

class PendingQueuedPostsMailer < ActionMailer::Base
  include Email::BuildEmailHelper

  def notify(opts={})
    return unless SiteSetting.contact_email
    build_email(SiteSetting.contact_email, template: 'queued_posts_reminder', count: opts[:count])
  end
end
