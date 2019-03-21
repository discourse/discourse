require 'image_sizer'
require_dependency 'system_message'

module Jobs
  class SendSystemMessage < Jobs::Base
    def execute(args)
      unless args[:user_id].present?
        raise Discourse::InvalidParameters.new(:user_id)
      end
      unless args[:message_type].present?
        raise Discourse::InvalidParameters.new(:message_type)
      end

      user = User.find_by(id: args[:user_id])
      return if user.blank?

      system_message = SystemMessage.new(user)
      system_message.create(
        args[:message_type],
        args[:message_options]&.symbolize_keys || {}
      )
    end
  end
end
