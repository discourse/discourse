# frozen_string_literal: true

module Email
  class MessageIdGenerator
    class << self
      def for_post(post, use_incoming_email_if_present: false)
        host = Email::Sender.host_for(Discourse.base_url)

        if use_incoming_email_if_present && post.incoming_email&.message_id.present?
          return "<#{post.incoming_email.message_id}>"
        end

        "<topic/#{post.topic_id}/#{post.id}.#{random_chunk}@#{host}>"
      end

      def for_topic(topic, use_incoming_email_if_present: false)
        host = Email::Sender.host_for(Discourse.base_url)
        first_post = topic.ordered_posts.first

        if use_incoming_email_if_present && first_post.incoming_email&.message_id.present?
          return "<#{first_post.incoming_email.message_id}>"
        end

        "<topic/#{topic.id}.#{random_chunk}@#{host}>"
      end

      def random_chunk
        SecureRandom.hex(12)
      end
    end
  end
end
