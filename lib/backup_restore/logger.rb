# frozen_string_literal: true

module BackupRestore
  class Logger
    attr_reader :logs

    def initialize(user_id: nil, client_id: nil)
      @user_id = user_id
      @client_id = client_id
      @publish_to_message_bus = @user_id.present? && @client_id.present?

      @logs = []
    end

    def log(message, ex = nil)
      return if Rails.env.test?

      timestamp = Time.now.strftime("%Y-%m-%d %H:%M:%S")
      puts(message)
      publish_log(message, timestamp)
      save_log(message, timestamp)
      Rails.logger.error("#{ex}\n" + ex.backtrace.join("\n")) if ex
    end

    protected

    def publish_log(message, timestamp)
      return unless @publish_to_message_bus
      data = { timestamp: timestamp, operation: "restore", message: message }
      MessageBus.publish(BackupRestore::LOGS_CHANNEL, data, user_ids: [@user_id], client_ids: [@client_id])
    end

    def save_log(message, timestamp)
      @logs << "[#{timestamp}] #{message}"
    end
  end
end
