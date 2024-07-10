# frozen_string_literal: true

module ActiveRecordSerializationSafety
  class BlockedSerializationError < StandardError
  end

  def serializable_hash(options = nil)
    if options.nil? || options[:only].nil?
      message =
        "Serializing ActiveRecord models (#{self.class.name}) without specifying fields is not allowed. Use a Serializer, or pass the :only option to #serializable_hash. More info: https://meta.discourse.org/t/-/314495"

      if Rails.env == "production"
        Rails.logger.info(message)
      else
        raise BlockedSerializationError.new(message)
      end
    end
    super
  end
end

ActiveRecord::Base.prepend(ActiveRecordSerializationSafety)
