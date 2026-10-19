# frozen_string_literal: true

module Voice
  class ContactsController < ApplicationController
    def index
      raise Discourse::NotFound unless SiteSetting.voice_analytics_enabled

      contacts = Voice::CoPresence.top_contacts_for(current_user.id, since: 30.days.ago, limit: 10)

      users = User.where(id: contacts.map(&:contact_id)).index_by(&:id)

      render json: {
               contacts:
                 contacts.filter_map do |row|
                   user = users[row.contact_id]
                   next unless user

                   BasicUserSerializer
                     .new(user, scope: guardian, root: false)
                     .as_json
                     .merge(
                       total_seconds: row.total_seconds,
                       session_count: row.session_count,
                       last_co_present_on: row.last_co_present_on,
                     )
                 end,
             }
    end
  end
end
