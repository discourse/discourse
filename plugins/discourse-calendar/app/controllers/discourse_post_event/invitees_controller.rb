# frozen_string_literal: true

module DiscoursePostEvent
  class InviteesController < DiscoursePostEventController
    requires_login except: %i[index]

    def index
      event = Event.find(params[:post_id])
      guardian.ensure_can_see!(event.post)

      filter = params[:filter].downcase if params[:filter]

      event_invitees = event.invitees
      if params[:type]
        unless Invitee.statuses.valid?(params[:type].to_sym)
          raise Discourse::InvalidParameters.new(:type)
        end
        event_invitees = event_invitees.with_status(params[:type].to_sym)
      end

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
      DiscoursePostEvent::UpdateInvitee.call(
        params: {
          status: params[:invitee][:status],
          event_id: params[:event_id],
          invitee_id: params[:invitee_id],
        },
        guardian:,
      ) do
        on_success { |invitee:| render json: InviteeSerializer.new(invitee) }
        on_failed_policy(:can_act_on_invitee) { raise Discourse::InvalidAccess }
        on_failed_policy(:can_see_event) { raise Discourse::InvalidAccess }
        on_failed_policy(:can_update_attendance) { raise Discourse::InvalidAccess }
        on_failed_policy(:has_capacity) do
          render_json_error(
            I18n.t("discourse_post_event.errors.models.event.max_attendees_reached"),
            422,
          )
        end
        on_model_not_found(:invitee) { raise Discourse::NotFound }
        on_model_not_found(:event) { raise Discourse::NotFound }
        on_failed_contract { raise Discourse::InvalidParameters }
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
      end
    end

    def create
      DiscoursePostEvent::CreateInvitee.call(
        params: {
          status: params[:invitee][:status],
          user_id: params[:invitee][:user_id],
          event_id: params[:event_id],
        },
        guardian:,
      ) do
        on_success { |invitee:| render json: InviteeSerializer.new(invitee) }
        on_failed_policy(:can_see_event) { raise Discourse::InvalidAccess }
        on_failed_policy(:can_update_attendance) { raise Discourse::InvalidAccess }
        on_failed_policy(:can_invite_user) { raise Discourse::InvalidAccess }
        on_failed_policy(:has_capacity) do
          render_json_error(
            I18n.t("discourse_post_event.errors.models.event.max_attendees_reached"),
            422,
          )
        end
        on_model_not_found(:event) { raise Discourse::NotFound }
        on_model_not_found(:user) { raise Discourse::NotFound }
        on_failed_contract { raise Discourse::InvalidParameters }
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
      end
    end

    def destroy
      DiscoursePostEvent::DestroyInvitee.call(
        params: {
          post_id: params[:post_id],
          id: params[:id],
        },
        guardian:,
      ) do
        on_success { render json: success_json }
        on_failed_policy(:can_act_on_invitee) { raise Discourse::InvalidAccess }
        on_failed_policy(:can_see_event) { raise Discourse::InvalidAccess }
        on_failed_policy(:can_update_attendance) { raise Discourse::InvalidAccess }
        on_model_not_found(:event) { raise Discourse::NotFound }
        on_model_not_found(:invitee) { raise Discourse::NotFound }
        on_failed_contract { raise Discourse::InvalidParameters }
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
      end
    end
  end
end
