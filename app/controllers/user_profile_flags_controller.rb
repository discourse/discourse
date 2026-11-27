# frozen_string_literal: true

class UserProfileFlagsController < ApplicationController
  requires_login

  def create
    User::FlagProfile.call(service_params) do
      on_success do |score:|
        status = score.previously_new_record? ? :created : :ok
        render json: { profile_flag: { id: score.id } }, status:
      end
      on_failed_contract { |contract| render_json_error(contract.errors.full_messages) }
      on_model_not_found(:user) { raise Discourse::NotFound }
      on_failed_policy(:can_flag_profile) { raise Discourse::NotFound }
      on_model_not_found(:flag) { raise Discourse::InvalidParameters.new(:flag_type_id) }
      on_failed_policy(:message_meets_minimum) { raise Discourse::InvalidParameters.new(:message) }
      on_failed_policy(:illegal_flag_confirmed) do
        raise Discourse::InvalidParameters.new(:confirmed)
      end
    end
  end
end
