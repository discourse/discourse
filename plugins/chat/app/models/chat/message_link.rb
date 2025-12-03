# frozen_string_literal: true

module Chat
  class MessageLink < ActiveRecord::Base
    self.table_name = "chat_message_links"

    belongs_to :chat_message, class_name: "Chat::Message"
    belongs_to :chat_channel, class_name: "Chat::Channel"
    belongs_to :user

    validates :url, presence: true, length: { maximum: 500 }

    def self.extract_from(message)
      return if message.blank? || message.user_id.blank? || message.deleted_at.present?

      current_urls = []

      PrettyText
        .extract_links(message.cooked)
        .map { |link| UrlHelper.relaxed_parse(link.url) }
        .compact
        .reject { |uri| uri.scheme == "mailto" }
        .uniq
        .each do |parsed|
          url = parsed.to_s[0...500]
          next if parsed.host.blank? || parsed.host.length > 100

          current_urls << url
          upsert_link(message, url, parsed.host)
        end

      cleanup_entries(message, current_urls)
    end

    def self.upsert_link(message, url, domain)
      sql = <<~SQL
        INSERT INTO chat_message_links (chat_message_id, chat_channel_id, user_id, url, domain, created_at, updated_at)
        VALUES (:chat_message_id, :chat_channel_id, :user_id, :url, :domain, :now, :now)
        ON CONFLICT (chat_message_id, url) DO NOTHING
      SQL

      DB.exec(
        sql,
        chat_message_id: message.id,
        chat_channel_id: message.chat_channel_id,
        user_id: message.user_id,
        url: url,
        domain: domain,
        now: Time.current,
      )
    end

    def self.cleanup_entries(message, current_urls)
      if current_urls.present?
        where(
          "chat_message_id = :id AND url NOT IN (:urls)",
          id: message.id,
          urls: current_urls,
        ).delete_all
      else
        where(chat_message_id: message.id).delete_all
      end
    end
  end
end
