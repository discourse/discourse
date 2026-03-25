# frozen_string_literal: true

class AppreciationsController < ApplicationController
  skip_before_action :check_xhr

  def given
    list_appreciations(direction: "given")
  end

  def received
    list_appreciations(direction: "received")
  end

  private

  def list_appreciations(direction:)
    Appreciations::List.call(service_params.deep_merge(params: { direction: })) do
      on_success do |appreciations:|
        render json: appreciations,
               each_serializer: AppreciationSerializer,
               scope: guardian,
               root: "appreciations"
      end
      on_failed_contract do |contract|
        render json: failed_json.merge(errors: contract.errors.full_messages), status: :bad_request
      end
      on_model_not_found(:target_user) { raise Discourse::NotFound }
      on_failed_policy(:can_see) do
        direction == "received" ? raise(Discourse::InvalidAccess) : raise(Discourse::NotFound)
      end
      on_failure { render(json: failed_json, status: :unprocessable_entity) }
    end
  end
end
