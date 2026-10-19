# frozen_string_literal: true

class DsaStatementsController < ApplicationController
  requires_login

  def classify
    DsaStatementOfRecord::Classify.call(service_params) do
      on_success do |reviewable:|
        statement_ids =
          reviewable.dsa_statement_of_records.pending.order(:created_at, :id).pluck(:id)
        notes = reviewable.reviewable_notes.preload(:user).to_a

        render_json_dump(
          dsa_classification: {
            statement_ids:,
          },
          reviewable_notes:
            serialize_data(
              notes,
              ReviewableNoteSerializer,
              root: false,
              reviewable_note_mention_usernames:
                PlaintextMentions.known_usernames(notes.map(&:content)),
            ),
        )
      end
      on_failed_policy(:staff) { raise Discourse::InvalidAccess }
      on_failed_policy(:classification_enabled) { raise Discourse::InvalidAccess }
      on_model_not_found(:reviewable) { raise Discourse::NotFound }
      on_model_not_found(:statements) do
        render_json_error(I18n.t("dsa_statements.errors.statements_changed"), status: :conflict)
      end
      on_failed_policy(:current_statements) do
        render_json_error(I18n.t("dsa_statements.errors.statements_changed"), status: :conflict)
      end
      on_failed_contract do |contract|
        render_json_error(contract.errors.full_messages, status: :unprocessable_entity)
      end
      on_failure do
        render_json_error(I18n.t("dsa_statements.errors.failed"), status: :unprocessable_entity)
      end
    end
  end
end
