# frozen_string_literal: true

module DiscoursePostEvent
  class InviteesController < DiscoursePostEventController
    def index
      event = Event.find(params[:post_id])
      guardian.ensure_can_see!(event.post)

      filter = params[:filter].downcase if params[:filter]

      event_invitees = event.invitees
      event_invitees = event_invitees.with_status(params[:type].to_sym) if params[:type]

      suggested_users = []
      if filter.present? && guardian.can_act_on_discourse_post_event?(event)
        missing_users = event.missing_users(event_invitees.select(:user_id))

        if filter
          missing_users = missing_users.where("LOWER(username) LIKE :filter", filter: "%#{filter}%")

          custom_order = <<~SQL
            CASE
              WHEN LOWER(username) = ? THEN 0
              ELSE 1
            END ASC,
            LOWER(username) ASC
          SQL

          custom_order = ActiveRecord::Base.sanitize_sql_array([custom_order, filter])
          missing_users = missing_users.order(custom_order).limit(10)
        else
          missing_users = missing_users.order(:username_lower).limit(10)
        end

        suggested_users = missing_users
      end

      if filter
        event_invitees =
          event_invitees.joins(:user).where(
            "LOWER(users.username) LIKE :filter",
            filter: "%#{filter}%",
          )
      end

      event_invitees = event_invitees.order(%i[status username_lower]).limit(200)

      render json:
               InviteeListSerializer.new(invitees: event_invitees, suggested_users: suggested_users)
    end

    def update
      invitee = Invitee.find_by(id: params[:invitee_id], post_id: params[:event_id])
      guardian.ensure_can_act_on_invitee!(invitee)
      invitee.update_attendance!(invitee_params[:status])
      render json: InviteeSerializer.new(invitee)
    end

    def create
      event = Event.find(params[:event_id])
      guardian.ensure_can_see!(event.post)

      invitee_params = invitee_params(event)

      user = current_user
      if user_id = invitee_params[:user_id]
        user = User.find(user_id.to_i)
      end

      raise Discourse::InvalidAccess if !event.can_user_update_attendance(user)

      if current_user.id != user.id
        raise Discourse::InvalidAccess if !guardian.can_act_on_discourse_post_event?(event)
      end

      invitee = Invitee.create_attendance!(user.id, params[:event_id], invitee_params[:status])
      render json: InviteeSerializer.new(invitee)
    end

    def destroy
      event = Event.find_by(id: params[:post_id])
      invitee = event.invitees.find_by(id: params[:id])
      guardian.ensure_can_act_on_invitee!(invitee)
      invitee.destroy!
      event.publish_update!
      render json: success_json
    end

    private

    def invitee_params(event = nil)
      if event && guardian.can_act_on_discourse_post_event?(event)
        params.require(:invitee).permit(:status, :user_id)
      else
        params.require(:invitee).permit(:status)
      end
    end
  end
end
