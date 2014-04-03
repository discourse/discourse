require_dependency 'email/message_builder'
require_dependency 'flag_query'

class PendingFlagsMailer < ActionMailer::Base
  include Email::BuildEmailHelper

  def notify
    return unless SiteSetting.contact_email

    @posts, users = FlagQuery.flagged_posts_report(Discourse.system_user, 'active', 0, 20)

    @posts.each do |post| # Note: post is a Hash, not a Post.
      counts = flag_reason_counts(post)
      post[:reason_counts] = counts.map do |reason, count|
        "#{I18n.t('post_action_types.' + reason.to_s + '.title')}: #{count}"
      end.join(', ')
    end

    @hours = SiteSetting.notify_about_flags_after

    build_email( SiteSetting.contact_email,
                 subject: "[#{SiteSetting.title}] " + I18n.t('flags_reminder.subject_template', {count: PostAction.flagged_posts_count}) )
  end

  private

  def flag_reason_counts(post)
    post[:post_actions].inject({}) {|h,v| h[v[:name_key]] ||= 0; h[v[:name_key]] += 1; h }
  end
end
