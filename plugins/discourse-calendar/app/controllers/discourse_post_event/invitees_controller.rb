# frozen_string_literal: true

module DiscoursePostEvent
  class InviteesController < DiscoursePostEventController
    requires_login except: %i[index]

    def index
      DiscoursePostEvent::ListInvitees.call(
        params: {
          post_id: params[:post_id],
          filter: params[:filter],
          type: params[:type],
        },
        guardian:,
      ) do
        on_success do |invitees:, suggested_users:|
          render json: InviteeListSerializer.new(invitees:, suggested_users:)
        end
        on_failed_policy(:can_see_event) { raise Discourse::InvalidAccess }
        on_model_not_found(:event) { raise Discourse::NotFound }
        on_failed_contract { raise Discourse::InvalidParameters }
      end
    end

    def update
      DiscoursePostEvent::UpdateInvitee.call(
        params: {
          status: params.dig(:invitee, :status),
          recurring: params.dig(:invitee, :recurring) || false,
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
          recurring: params[:invitee][:recurring] || false,
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
