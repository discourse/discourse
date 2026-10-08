# frozen_string_literal: true
class DsaStatementsController < ApplicationController
  requires_login
  before_action :ensure_reporting_enabled

  def classify
    DsaStatementOfReason::Classify.call(service_params) do
      on_success do |reviewable:|
        render_serialized(
          reviewable,
          reviewable.serializer,
          rest_serializer: true,
          root: "reviewable",
        )
      end
      on_failed_policy(:reporting_enabled) { raise Discourse::InvalidAccess }
      on_model_not_found(:reviewable) { raise Discourse::NotFound }
      on_model_not_found(:statements) do
        render_json_error(I18n.t("reviewables.conflict"), status: 409)
      end
      on_failed_policy(:can_correct_classification) { raise Discourse::InvalidAccess }
      on_failed_contract do |contract|
        render_json_error(contract.errors.full_messages, status: 422)
      end
    end
  end

  def retry_submission
    raise Discourse::InvalidAccess unless guardian.is_admin?

    statements =
      DsaStatementOfReason.failed.where(
        reviewable_id: params[:reviewable_id],
        decision_key: params.require(:decision_key),
      )
    raise Discourse::NotFound if statements.empty?

    statements.find_each(&:retry!)
    Jobs.enqueue(:submit_dsa_statements)
    head :no_content
  end

  private

  def ensure_reporting_enabled
    unless SiteSetting.dsa_reporting_enabled && guardian.can_see_review_queue?
      raise Discourse::InvalidAccess
    end
  end
end
