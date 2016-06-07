require_dependency 'email/message_builder'

class InviteMailer < ActionMailer::Base
  include Email::BuildEmailHelper

  class UserNotificationRenderer < ActionView::Base
    include UserNotificationsHelper
  end

  def send_invite(invite, custom_message=nil)
    # Find the first topic they were invited to
    first_topic = invite.topics.order(:created_at).first

    # get invitee name (based on site setting)
    invitee_name = invite.invited_by.username
    if SiteSetting.enable_names && invite.invited_by.name.present?
      invitee_name = "#{invite.invited_by.name} (#{invite.invited_by.username})"
    end

    # custom message
    html = nil
    if custom_message.present? && custom_message =~ /{invite_link}/
      custom_message.gsub!("{invite_link}", "#{Discourse.base_url}/invites/#{invite.invite_key}")
      custom_message.gsub!("{site_title}", SiteSetting.title) if custom_message =~ /{site_title}/
      custom_message.gsub!("{site_description}", SiteSetting.site_description) if custom_message =~ /{site_description}/

      html = UserNotificationRenderer.new(Rails.configuration.paths["app/views"]).render(
        template: 'email/invite',
        format: :html,
        locals: { message: PrettyText.cook(custom_message).html_safe,
                  classes: 'custom-invite-email' }
      )
    end

    # If they were invited to a topic
    if first_topic.present?
      # get topic excerpt
      topic_excerpt = ""
      if first_topic.excerpt
        topic_excerpt = first_topic.excerpt.gsub("\n", " ")
      end

      html.gsub!("{topic_title}", first_topic.try(:title)) if html.present? && html =~ /{topic_title}/
      html.gsub!("{topic_excerpt}", topic_excerpt) if html.present? && html =~ /{topic_excerpt}/

      build_email(invite.email,
                  template: 'invite_mailer',
                  html_override: html,
                  invitee_name: invitee_name,
                  site_domain_name: Discourse.current_hostname,
                  invite_link: "#{Discourse.base_url}/invites/#{invite.invite_key}",
                  topic_title: first_topic.try(:title),
                  topic_excerpt: topic_excerpt,
                  site_description: SiteSetting.site_description,
                  site_title: SiteSetting.title)
    else
      build_email(invite.email,
                  template: 'invite_forum_mailer',
                  html_override: html,
                  invitee_name: invitee_name,
                  site_domain_name: Discourse.current_hostname,
                  invite_link: "#{Discourse.base_url}/invites/#{invite.invite_key}",
                  site_description: SiteSetting.site_description,
                  site_title: SiteSetting.title)
    end
  end

  def send_password_instructions(user)
    if user.present?
      email_token = user.email_tokens.create(email: user.email)
      build_email(user.email,
                  template: 'invite_password_instructions',
                  email_token: email_token.token)
    end
  end

end
