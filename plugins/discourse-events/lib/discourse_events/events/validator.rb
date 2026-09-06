# frozen_string_literal: true

module DiscourseEvents
  module Events
    class Validator
      VALID_RECURRENCES = %w[
        every_month
        every_week
        every_two_weeks
        every_four_weeks
        every_day
        every_weekday
      ]

      def initialize(post)
        @post = post
      end

      def validate_event
        extracted_events = DiscourseEvents::Events::Parser.extract_events(@post)

        return false if extracted_events.count == 0

        if extracted_events.count > 1
          @post.errors.add(:base, I18n.t("discourse_post_event.errors.models.event.only_one_event"))
          return false
        end

        if !@post.is_first_post?
          @post.errors.add(
            :base,
            I18n.t("discourse_post_event.errors.models.event.must_be_in_first_post"),
          )
          return false
        end

        extracted_event = extracted_events.first

        return false unless can_invite_groups?(extracted_event)
        return false unless valid_hosts?(extracted_event)

        if @post.acting_user && @post.event
          if !@post.acting_user.guardian.can_act_on_discourse_post_event?(@post.event)
            @post.errors.add(
              :base,
              I18n.t(
                "discourse_post_event.errors.models.event.acting_user_not_allowed_to_act_on_this_event",
              ),
            )
            return false
          end
        else
          if !@post.acting_user.guardian.can_create_discourse_post_event?
            @post.errors.add(
              :base,
              I18n.t(
                "discourse_post_event.errors.models.event.acting_user_not_allowed_to_create_event",
              ),
            )
            return false
          end
        end

        if extracted_event[:start].blank? ||
             (
               begin
                 DateTime.parse(extracted_event[:start])
               rescue StandardError
                 nil
               end
             ).nil?
          @post.errors.add(
            :base,
            I18n.t(
              "discourse_post_event.errors.models.event.start_must_be_present_and_a_valid_date",
            ),
          )
          return false
        end

        if extracted_event[:end].present? &&
             (
               begin
                 DateTime.parse(extracted_event[:end])
               rescue StandardError
                 nil
               end
             ).nil?
          @post.errors.add(
            :base,
            I18n.t("discourse_post_event.errors.models.event.end_must_be_a_valid_date"),
          )
          return false
        end

        if extracted_event[:start].present? && extracted_event[:end].present?
          if Time.parse(extracted_event[:start]) > Time.parse(extracted_event[:end])
            @post.errors.add(
              :base,
              I18n.t("discourse_post_event.errors.models.event.ends_at_before_starts_at"),
            )
            return false
          end
        end

        if extracted_event[:name].present?
          if !(Event::MIN_NAME_LENGTH..Event::MAX_NAME_LENGTH).cover?(extracted_event[:name].length)
            @post.errors.add(
              :base,
              I18n.t(
                "discourse_post_event.errors.models.event.name.length",
                minimum: Event::MIN_NAME_LENGTH,
                maximum: Event::MAX_NAME_LENGTH,
              ),
            )
            return false
          end
        end

        if extracted_event[:recurrence].present?
          if !VALID_RECURRENCES.include?(extracted_event[:recurrence].to_s)
            @post.errors.add(
              :base,
              I18n.t("discourse_post_event.errors.models.event.invalid_recurrence"),
            )
          end
        end

        if extracted_event[:timezone].present?
          if !ActiveSupport::TimeZone[extracted_event[:timezone]].present?
            @post.errors.add(
              :base,
              I18n.t(
                "discourse_post_event.errors.models.event.invalid_timezone",
                timezone: extracted_event[:timezone],
              ),
            )
          end
        end

        if !Parser.valid_url?(extracted_event[:url])
          @post.errors.add(:base, I18n.t("discourse_post_event.errors.models.event.invalid_url"))
        end

        true
      end

      private

      def valid_hosts?(event)
        usernames = extract_hosts(event)
        return true if usernames.empty?

        if usernames.length > Event::MAX_HOSTS
          @post.errors.add(
            :base,
            I18n.t(
              "discourse_post_event.errors.models.event.too_many_hosts",
              count: Event::MAX_HOSTS,
            ),
          )
          return false
        end

        hosts = User.human_users.where(username_lower: usernames).to_a
        if hosts.length != usernames.length
          @post.errors.add(:base, I18n.t("discourse_post_event.errors.models.event.invalid_hosts"))
          return false
        end

        # Only newly added hosts are held to the eligibility bar, so an event
        # keeps hosts that were valid when they were named.
        existing_ids = @post.event ? @post.event.host_user_ids : []
        added = hosts.reject { |host| existing_ids.include?(host.id) }
        return true if added.empty?

        return true if added.all? { |host| eligible_host?(host) }

        @post.errors.add(:base, I18n.t("discourse_post_event.errors.models.event.invalid_hosts"))
        false
      end

      def eligible_host?(host)
        return false if !host.active? || host.suspended?

        category = @post.topic&.category
        return true if category.blank?

        host.guardian.can_see_category?(category)
      end

      def extract_hosts(event)
        event[:hosts]
          .to_s
          .split(",")
          .map { |username| username.strip.downcase }
          .reject(&:blank?)
          .uniq
      end

      def can_invite_groups?(event)
        return true unless event[:"allowed-groups"]

        event[:"allowed-groups"]
          .split(",")
          .each do |group_name|
            group =
              begin
                Group.lookup_group(group_name.to_sym)
              rescue ArgumentError
                nil
              end

            if !group || !@post.acting_user.guardian.can_see_group?(group)
              @post.errors.add(
                :base,
                I18n.t("discourse_post_event.errors.models.event.invalid_allowed_groups"),
              )
              return false
            end

            if !@post.acting_user.guardian.can_see_group_members?(group)
              @post.errors.add(
                :base,
                I18n.t(
                  "discourse_post_event.errors.models.event.acting_user_not_allowed_to_invite_these_groups",
                ),
              )
              return false
            end
          end

        true
      end
    end
  end
end
