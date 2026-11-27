# frozen_string_literal: true

module DiscourseEvents
  module Events
    class RegistrationForm < ActiveRecord::Base
      include Trashable

      ACCOUNT_ONLY = "account"

      self.table_name = "discourse_event_registration_forms"

      belongs_to :created_by, class_name: "User", optional: true

      validate :valid_definition

      def self.account_only_definition
        {
          "builtin" => ACCOUNT_ONLY,
          "title" =>
            I18n.t("js.event_registration.account_only", locale: SiteSetting.default_locale),
          "fields" => [],
        }
      end

      def self.definition_error(definition, allow_account_only: false)
        form = FormDefinition.new(definition)
        return "invalid_registration_form" unless form.valid?
        if definition.key?("builtin")
          if allow_account_only && definition["builtin"] == ACCOUNT_ONLY &&
               definition["fields"].empty?
            return
          end
          return "invalid_registration_form"
        end
        "registration_form_needs_field" if form.answer_fields.empty?
      end

      def self.in_use_ids(form_ids)
        linked =
          Event.visible.with_library_form.joins(post: :topic).where(registration_form_id: form_ids)
        now = Time.current
        in_use =
          linked
            .where(<<~SQL, now:, today: now.beginning_of_day)
          original_ends_at > :now OR (original_ends_at IS NULL AND original_starts_at >= :today)
          OR (NULLIF(recurrence, '') IS NOT NULL AND recurrence_until IS NULL)
        SQL
            .distinct
            .pluck(:registration_form_id)
            .to_set

        # A series cutoff is the last permitted start, which can be before the
        # final occurrence ends or several days after its actual start.
        linked
          .where.not(recurrence: [nil, ""])
          .where.not(recurrence_until: nil)
          .where.not(registration_form_id: in_use.to_a)
          .select(
            :id,
            :registration_form_id,
            :recurrence,
            :recurrence_until,
            :original_starts_at,
            :original_ends_at,
            :timezone,
            :all_day,
          )
          .find_each do |event|
            next if in_use.include?(event.registration_form_id)
            duration =
              event.original_ends_at ? event.original_ends_at - event.original_starts_at : 1.day
            after = now - duration
            next if event.recurrence_until < after
            if event
                 .recurring_occurrences(after:, limit: 2)
                 .any? { |date| (date[:ends_at] || date[:starts_at].end_of_day) > now }
              in_use << event.registration_form_id
            end
          end
        in_use
      end

      def in_use?
        self.class.in_use_ids([id]).include?(id)
      end

      def trash!(user = nil)
        with_lock do
          if in_use?
            errors.add(:base, I18n.t("event_registration.form_in_use"))
            raise ActiveRecord::RecordInvalid, self
          end
          super(user)
        end
      end

      private

      def valid_definition
        error = self.class.definition_error(definition)
        errors.add(:base, I18n.t("discourse_post_event.errors.models.event.#{error}")) if error
      end
    end
  end
end

# == Schema Information
#
# Table name: discourse_event_registration_forms
#
#  id            :bigint           not null, primary key
#  definition    :jsonb            not null
#  deleted_at    :datetime
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  created_by_id :integer
#  deleted_by_id :integer
#
