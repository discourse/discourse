require_dependency 'email/message_builder'
require_dependency 'flag_query'

class PendingFlagsMailer < ActionMailer::Base
  include Email::BuildEmailHelper

  def notify
    return unless SiteSetting.contact_email

    @posts, @topics, @users = FlagQuery.flagged_posts_report(Discourse.system_user, 'active', 0, 20)

    @posts.each do |post| # Note: post is a Hash, not a Post.
      topic = @topics.select { |t| t[:id] == post[:topic_id] }.first

      post[:title] = topic[:title]
      post[:url] = "#{Discourse.base_url}#{Post.url(topic[:slug], topic[:id], post[:post_number])}"
      post[:user] = @users.select { |u| u[:id] == post[:user_id] }.first

      counts = flag_reason_counts(post)
      post[:reason_counts] = counts.map { |reason, count| "#{I18n.t('post_action_types.' + reason.to_s + '.title')}: #{count}" }.join(', ')
      post[:html_reason_counts] = counts.map { |reason, count| "<strong>#{I18n.t('post_action_types.' + reason.to_s + '.title')}:</strong> #{count}" }.join(', ')
    end

    @hours = SiteSetting.notify_about_flags_after

    subject = "[#{SiteSetting.title}] " + I18n.t('flags_reminder.subject_template', { count: PostAction.flagged_posts_count })
    build_email(SiteSetting.contact_email, subject: subject)
  end

  private

  def flag_reason_counts(post)
    post[:post_actions].inject({}) do |h,v|
      h[v[:name_key]] ||= 0
      h[v[:name_key]] += 1
      h
    end
  end
end
