# frozen_string_literal: true

module DiscourseEvents
  module Events
    class Registration < ActiveRecord::Base
      self.table_name = "discourse_event_registrations"

      class InvalidSubmission < StandardError
      end

      belongs_to :event
      after_create_commit { Jobs.enqueue(:report_event_registrations, event_id:) }

      def self.record_attendance!(event:, user:, acting_user:, params:)
        return yield unless params.status == :going

        event.with_lock do
          return yield unless event.registration_form || params.registration
          raise Discourse::InvalidAccess unless user == acting_user

          data = JSON.parse(params.registration.to_s)
          unless data.is_a?(Hash) && data["key"].is_a?(String) &&
                   /\A[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\z/i.match?(data["key"]) &&
                   data["answers"].is_a?(Hash)
            raise InvalidSubmission, I18n.t("event_registration.required")
          end

          if exists?(event:, user_id: user.id, submission_key: data["key"])
            return Invitee.find_by!(post_id: event.id, user_id: user.id)
          end
          unless event.registration_form && data["revision"] == event.registration_revision
            raise InvalidSubmission, I18n.t("event_registration.changed")
          end

          fields = event.registration_form.fetch("fields")
          answers = data["answers"].slice(*fields.pluck("id"))
          invalid = FormDefinition.new(event.registration_form).invalid_answers(answers).first
          if invalid
            raise InvalidSubmission, I18n.t("event_registration.invalid", label: invalid["label"])
          end

          raise Discourse::InvalidAccess unless event.can_user_update_attendance?(user)
          create!(
            event:,
            user_id: user.id,
            submission_key: data["key"],
            username: user.username,
            email: user.email,
            occurrence_starts_at: occurrence(event, data),
            recurring: params.recurring,
            definition: event.registration_form,
            answers:,
          )
          yield
        end
      rescue JSON::ParserError
        raise InvalidSubmission, I18n.t("event_registration.required")
      end

      def self.occurrence(event, data)
        return event.starts_at if data["occurrence"].blank?
        requested = Time.iso8601(data["occurrence"])
        return event.starts_at if requested.to_i == event.starts_at.to_i
        if requested > event.starts_at && event.recurrence.present?
          next_date = event.calculate_next_occurrence_from(requested)&.fetch(:starts_at)
          return next_date if next_date && next_date.to_i == requested.to_i
        end
        raise InvalidSubmission, I18n.t("event_registration.changed")
      rescue ArgumentError, TypeError
        raise InvalidSubmission, I18n.t("event_registration.changed")
      end

      def display_answer(field)
        value = answers[field["id"]]
        return value unless field["choices"]
        field["choices"].find { |option| option["id"] == value }&.fetch("label")
      end

      def report_body
        metadata =
          I18n.t(
            "event_registration.report_body",
            event: event.post.topic.title,
            form: definition["title"],
            username:,
            email:,
            submitted_at: created_at.utc.iso8601,
            occurrence: occurrence_starts_at.utc.iso8601,
            rsvp_scope:
              I18n.t(recurring ? "event_registration.recurring" : "event_registration.single"),
          )
        rows =
          definition.fetch("fields").map { |field| "#{field["label"]}: #{display_answer(field)}" }
        (metadata.lines(chomp: true) + rows).join("\n").lines.map { |line| "    #{line}" }.join
      end
    end
  end
end

# == Schema Information
#
# Table name: discourse_event_registrations
#
#  id                   :bigint           not null, primary key
#  answers              :jsonb            not null
#  definition           :jsonb            not null
#  email                :string           not null
#  occurrence_starts_at :datetime         not null
#  recurring            :boolean          not null
#  submission_key       :uuid             not null
#  username             :string           not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  event_id             :bigint           not null
#  report_post_id       :bigint
#  user_id              :integer          not null
#
# Indexes
#
#  idx_on_event_id_user_id_submission_key_d4b3cd1ae8  (event_id,user_id,submission_key) UNIQUE
#
