# frozen_string_literal: true

module DiscourseEvents
  module Events
    class Validator
      MAX_LENGTHS = {
        description: Event::MAX_DESCRIPTION_LENGTH,
        url: Event::MAX_URL_LENGTH,
        location: Event::MAX_LOCATION_LENGTH,
      }

      def initialize(post)
        @post = post
      end

      def validate_event
        extracted_events = Parser.extract_events(@post)

        return if extracted_events.empty?

        if extracted_events.size > 1
          add_error("only_one_event")
          return
        end

        if !@post.is_first_post?
          add_error("must_be_in_first_post")
          return
        end

        extracted_event = extracted_events.first
        attributes =
          Event::Action::AttributesFromRaw.new(
            raw_event: extracted_event,
            current_status: @post.event&.status || Event.statuses[:standalone],
          )

        group_names = attributes.raw_invitees.to_a
        invitees = group_names - [Event::PUBLIC_GROUP]

        if attributes.status == Event.statuses[:private] && invitees.size > Event::MAX_RAW_INVITEES
          add_error("raw_invitees_length", count: Event::MAX_RAW_INVITEES)
          return
        end

        return unless can_invite_groups?(group_names)

        if @post.acting_user && @post.event
          if !@post.acting_user.guardian.can_act_on_discourse_post_event?(@post.event)
            add_error("acting_user_not_allowed_to_act_on_this_event")
            return
          end
        else
          if !@post.acting_user.guardian.can_create_discourse_post_event?
            add_error("acting_user_not_allowed_to_create_event")
            return
          end
        end

        if extracted_event[:timezone].present? &&
             ActiveSupport::TimeZone[extracted_event[:timezone]].nil?
          add_error("invalid_timezone", timezone: extracted_event[:timezone])
          return
        end

        starts_at = parse_date { attributes.starts_at }

        if starts_at.nil?
          add_error("start_must_be_present_and_a_valid_date")
          return
        end

        ends_at = parse_date { attributes.ends_at }

        if extracted_event[:end].present? && ends_at.nil?
          add_error("end_must_be_a_valid_date")
          return
        end

        if ends_at && ends_at <= starts_at
          add_error("ends_at_before_starts_at")
          return
        end

        if extracted_event[:name].present? &&
             !(Event::MIN_NAME_LENGTH..Event::MAX_NAME_LENGTH).cover?(extracted_event[:name].length)
          add_error("name.length", minimum: Event::MIN_NAME_LENGTH, maximum: Event::MAX_NAME_LENGTH)
          return
        end

        MAX_LENGTHS.each do |field, maximum|
          if extracted_event[field].present? && extracted_event[field].length > maximum
            add_error("#{field}.length", maximum:)
          end
        end

        if extracted_event[:"max-attendees"].present? &&
             !extracted_event[:"max-attendees"].to_i.between?(1, Event::MAX_ATTENDEES_LIMIT)
          add_error("invalid_max_attendees", maximum: Event::MAX_ATTENDEES_LIMIT)
        end

        if extracted_event[:"recurrence-until"].present? &&
             parse_date { attributes.recurrence_until }.nil?
          add_error("recurrence_until_must_be_a_valid_date")
        end

        if extracted_event[:reminders].present?
          invalid_reminders =
            extracted_event[:reminders].split(",").reject { |r| Event.valid_reminder?(r) }
          if invalid_reminders.any?
            add_error("invalid_reminders", reminders: invalid_reminders.join(", "))
          end
        end

        if extracted_event[:recurrence].present? &&
             !RRuleConfigurator::RECURRENCES.include?(extracted_event[:recurrence].to_s)
          add_error("invalid_recurrence", recurrences: RRuleConfigurator::RECURRENCES.join(", "))
        end

        add_error("invalid_url") if !Parser.valid_url?(extracted_event[:url])
      end

      private

      def add_error(key, **args)
        @post.errors.add(:base, I18n.t("discourse_post_event.errors.models.event.#{key}", **args))
      end

      def parse_date
        yield
      rescue StandardError
        nil
      end

      def can_invite_groups?(group_names)
        group_names.each do |group_name|
          group =
            begin
              Group.lookup_group(group_name.to_sym)
            rescue ArgumentError
              nil
            end

          if !group || !@post.acting_user.guardian.can_see_group?(group)
            add_error("invalid_allowed_groups")
            return false
          end

          if !@post.acting_user.guardian.can_see_group_members?(group)
            add_error("acting_user_not_allowed_to_invite_these_groups")
            return false
          end
        end

        true
      end
    end
  end
end
