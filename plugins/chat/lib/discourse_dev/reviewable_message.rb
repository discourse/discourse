# frozen_string_literal: true

module DiscourseDev
  class ReviewableMessage < Reviewable
    def populate!
      channel = CategoryChannel.new.create!
      message = Message.new(channel_id: channel.id, count: 1).create!
      user = @users.sample

      ::Chat::FlagMessage.call(
        guardian: user.guardian,
        params: {
          channel_id: channel.id,
          message_id: message.id,
          flag_type_id:
            ReviewableScore.types.slice(:off_topic, :inappropriate, :spam, :illegal).values.sample,
        },
      )
    end
  end
end
