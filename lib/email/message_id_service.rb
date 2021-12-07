# frozen_string_literal: true

module Email
  ##
  # Email Message-IDs are used in both our outbound and inbound email
  # flow. For the outbound flow via Email::Sender, we assign a unique
  # Message-ID for any emails sent out from the application.
  # If we are sending an email related to a topic, such as through the
  # PostAlerter class, then the Message-ID will contain references to
  # the topic ID, and if it is for a specific post, the post ID,
  # along with a random suffix to make the Message-ID truly unique.
  # The host must also be included on the Message-IDs.
  #
  # For the inbound email flow via Email::Receiver, we use Message-IDs
  # to discern which topic or post the inbound email reply should be
  # in response to. In this case, the Message-ID is extracted from the
  # References and/or In-Reply-To headers, and compared with either
  # the IncomingEmail table, the Post table, or the IncomingEmail to
  # determine where to send the reply.
  #
  # See https://datatracker.ietf.org/doc/html/rfc2822#section-3.6.4 for
  # more specific information around Message-IDs in email.
  #
  # See https://tools.ietf.org/html/rfc850#section-2.1.7 for the
  # Message-ID format specification.
  class MessageIdService
    class << self
      def generate_default
        "<#{SecureRandom.uuid}@#{host}>"
      end

      def generate_for_post(post, use_incoming_email_if_present: false)
        if use_incoming_email_if_present && post.incoming_email&.message_id.present?
          return "<#{post.incoming_email.message_id}>"
        end

        "<topic/#{post.topic_id}/#{post.id}.#{random_suffix}@#{host}>"
      end

      def generate_for_topic(topic, use_incoming_email_if_present: false, canonical: false)
        first_post = topic.ordered_posts.first

        if use_incoming_email_if_present && first_post.incoming_email&.message_id.present?
          return "<#{first_post.incoming_email.message_id}>"
        end

        if canonical
          "<topic/#{topic.id}@#{host}>"
        else
          "<topic/#{topic.id}.#{random_suffix}@#{host}>"
        end
      end

      def find_post_from_message_ids(message_ids)
        message_ids = message_ids.map { |message_id| message_id_clean(message_id) }
        post_ids =  message_ids.map { |message_id| message_id[message_id_post_id_regexp, 1] }.compact.map(&:to_i)
        post_ids << Post.where(
          topic_id: message_ids.map { |message_id| message_id[message_id_topic_id_regexp, 1] }.compact,
          post_number: 1
        ).pluck(:id)
        post_ids << EmailLog.where(message_id: message_ids).pluck(:post_id)
        post_ids << IncomingEmail.where(message_id: message_ids).pluck(:post_id)

        post_ids.flatten!
        post_ids.compact!
        post_ids.uniq!

        return if post_ids.empty?

        Post.where(id: post_ids).order(:created_at).last
      end

      def random_suffix
        SecureRandom.hex(12)
      end

      def discourse_generated_message_id?(message_id)
        !!(message_id =~ message_id_post_id_regexp) ||
          !!(message_id =~ message_id_topic_id_regexp)
      end

      def message_id_post_id_regexp
        @message_id_post_id_regexp ||= Regexp.new "topic/\\d+/(\\d+|\\d+\.\\w+)@#{Regexp.escape(host)}"
      end

      def message_id_topic_id_regexp
        @message_id_topic_id_regexp ||= Regexp.new "topic/(\\d+|\\d+\.\\w+)@#{Regexp.escape(host)}"
      end

      def message_id_rfc_format(message_id)
        message_id.present? && !is_message_id_rfc?(message_id) ? "<#{message_id}>" : message_id
      end

      def message_id_clean(message_id)
        message_id.present? && is_message_id_rfc?(message_id) ? message_id.gsub(/^<|>$/, "") : message_id
      end

      def is_message_id_rfc?(message_id)
        message_id.start_with?('<') && message_id.include?('@') && message_id.end_with?('>')
      end

      def host
        @host ||= Email::Sender.host_for(Discourse.base_url)
      end
    end
  end
end
