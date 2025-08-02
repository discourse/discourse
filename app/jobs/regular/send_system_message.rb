# frozen_string_literal: true

require "image_sizer"

module Jobs
  class SendSystemMessage < ::Jobs::Base
    def execute(args)
      raise Discourse::InvalidParameters.new(:user_id) if args[:user_id].blank?
      raise Discourse::InvalidParameters.new(:message_type) if args[:message_type].blank?

      user = User.find_by(id: args[:user_id])
      return if user.blank?

      system_message = SystemMessage.new(user)
      system_message.create(args[:message_type], args[:message_options]&.symbolize_keys || {})
    end
  end
end
