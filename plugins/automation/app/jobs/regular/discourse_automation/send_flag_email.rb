# frozen_string_literal: true

module Jobs
  module DiscourseAutomation
    class SendFlagEmail < ::Jobs::Base
      def execute(args)
        post_action = PostAction.find_by(id: args[:post_action_id])
        return if post_action.blank?

        post = post_action&.post
        return if post.blank?

        email = args[:email]
        raise Discourse::InvalidParameters.new(:email) if email.blank?

        email_template =
          ::DiscourseAutomation::Field.where(id: args[:email_template_automation_field_id]).pick(
            :metadata,
          )[
            "value"
          ]

        if email_template.blank?
          raise Discourse::InvalidParameters.new(:email_template_automation_field_id)
        end

        placeholders = build_placeholders(post_action, post)

        subject =
          I18n.t(
            "discourse_automation.scriptables.email_on_flagged_post.subject",
            topic_title: placeholders[:topic_title],
            flagger_username: placeholders[:flagger_username],
          )

        body =
          ::DiscourseAutomation::Scriptable::Utils.apply_placeholders(email_template, placeholders)

        ::DiscourseAutomation::FlagMailer.send_flag_email(email, subject:, body:).deliver_now
      end

      private

      def build_placeholders(post_action, post)
        topic = post.topic
        flagger = post_action.user
        target_user = post.user

        {
          topic_url: topic.url,
          post_url: post.full_url,
          topic_title: topic&.title,
          post_number: post.post_number,
          flagger_username: flagger.username,
          flagged_username: target_user.username,
          flag_type: PostActionTypeView.new.names[post_action.post_action_type_id],
          category: topic.category&.name,
          tags: topic.tags&.map(&:name)&.join(", "),
          site_title: SiteSetting.title,
          post_excerpt: post.excerpt_for_topic,
        }.compact
      end
    end
  end
end
