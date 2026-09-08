# frozen_string_literal: true

module Jobs
  module Boards
    class CardPostProcess < ::Jobs::Base
      def execute(args)
        return unless SiteSetting.boards_enabled?

        card_id = args[:card_id]
        title = args[:title]
        return if card_id.blank? || title.blank?

        card = ::Boards::Card.find_by(id: card_id)
        return unless current_floater?(card, title)

        inline_onebox_data = ::Boards::Action::CardInlineOnebox.call(title:)
        return if card.inline_onebox_data == inline_onebox_data

        updated =
          ::Boards::Card.where(id: card.id, card_type: :floater, title:).update_all(
            inline_onebox_data:,
          )
        return if updated.zero?

        card.reload
        payload = ::Boards::CardSerializer.new(card, root: false).as_json
        ::Boards::Publisher.publish_card_updated!(card.board, payload, client_id: nil)
      end

      private

      def current_floater?(card, title)
        card&.floater? && card.title == title
      end
    end
  end
end
