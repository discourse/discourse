# frozen_string_literal: true

module DiscourseEvents
  module Events
    module ExportCsvReportExtension
      def post_event_export(&block)
        return enum_for(:post_event_export) unless block_given?

        guardian = Guardian.new(current_user)

        event = DiscourseEvents::Events::Event.includes(invitees: :user).find(@extra[:id])

        guardian.ensure_can_act_on_discourse_post_event!(event)

        event
          .invitees
          .order(:id)
          .each do |invitee|
            yield(
              [
                invitee.user.username,
                DiscourseEvents::Events::Invitee.statuses[invitee.status],
                invitee.created_at,
                invitee.updated_at,
              ]
            )
          end
      end

      def event_registrations_export
        return enum_for(__method__) unless block_given?
        identity = registration_identity_columns
        rows =
          registration_rows.select(
            :id,
            :definition,
            :answers,
            :created_at,
            :occurrence_starts_at,
            :recurring,
            *identity,
          )
        rows.find_each do |row|
          fields = row.answer_fields.index_by { |field| field["id"] }
          values =
            registration_columns.keys.map { |id| row.display_answer(fields[id]) if fields[id] }
          yield(
            [
              *row.slice(*identity).values,
              row.created_at.utc.iso8601,
              row.occurrence_starts_at.utc.iso8601,
              row.recurring,
              *values,
            ].map { |value| safe_registration_cell(value) }
          )
        end
      end

      def get_header(entity)
        if entity == "event_registrations"
          return(
            registration_identity_columns + %w[submitted_at occurrence_starts_at recurring] +
              registration_columns.values.map { |label| safe_registration_cell(label) }
          )
        end
        if SiteSetting.discourse_post_event_enabled && entity === "post_event"
          %w[username status first_answered_at last_updated_at]
        else
          super
        end
      end

      private

      def registration_identity_columns
        current_user.admin? ? %w[username email] : %w[username]
      end

      def registration_rows
        @registration_rows ||=
          begin
            event = DiscourseEvents::Events::Event.find(@extra[:id])
            Guardian.new(current_user).ensure_can_export_event_registrations!(event)
            event.registrations.where("id <= ?", event.registrations.maximum(:id) || 0)
          end
      end

      def registration_columns
        @registration_columns ||=
          begin
            columns = {}
            registration_rows
              .select(:id, :definition)
              .find_each do |row|
                row.answer_fields.each { |field| columns[field["id"]] = field["label"] }
              end
            seen = Set.new(%w[username email submitted_at occurrence_starts_at recurring])
            columns.transform_values! do |label|
              candidate = label
              suffix = 1
              while !seen.add?(candidate)
                suffix += 1
                candidate = "#{label} (#{suffix})"
              end
              candidate
            end
            columns
          end
      end

      def safe_registration_cell(value)
        return value unless value.is_a?(String) && value.match?(/\A(?:\s*[=+@-]|[\t\r\n])/)
        "'#{value}"
      end
    end
  end
end
