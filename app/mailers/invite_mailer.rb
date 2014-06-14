require_dependency 'email/message_builder'

class InviteMailer < ActionMailer::Base
  include Email::BuildEmailHelper

  def send_invite(invite)
    # Find the first topic they were invited to
    first_topic = invite.topics.order(:created_at).first

    # If they were invited to a topic
    if first_topic.present?
      build_email(invite.email,
                  template: 'invite_mailer',
                  invitee_name: invite.invited_by.username,
                  invite_link: "#{Discourse.base_url}/invites/#{invite.invite_key}",
                  topic_title: first_topic.try(:title),
                  site_description: SiteSetting.site_description,
                  site_title: SiteSetting.title)
    else
      build_email(invite.email,
                  template: 'invite_forum_mailer',
                  invitee_name: invite.invited_by.username,
                  invite_link: "#{Discourse.base_url}/invites/#{invite.invite_key}",
                  site_description: SiteSetting.site_description,
                  site_title: SiteSetting.title)
    end

  end

end
