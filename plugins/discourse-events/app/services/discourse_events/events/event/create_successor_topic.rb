# frozen_string_literal: true

module DiscourseEvents
  module Events
    class Event::CreateSuccessorTopic
      QUOTATION_MARKS = [
        %w[" "],
        %w[' '],
        %w[« »],
        %w[“ ”],
        %w[” ”],
        %w[‘ ’],
        %w[„ “],
        %w[‚ ’],
        %w[‹ ›],
      ].freeze

      EVENT_OPEN_TAG =
        /
        \[event(?=\s|\])
        (?:
          [^"'«“”‘„‚‹\]]+
          | "[^"]*"
          | '[^']*'
          | «[^»]*»
          | “[^”]*”
          | ”[^”]*”
          | ‘[^’]*’
          | „[^“]*“
          | ‚[^’]*’
          | ‹[^›]*›
        )*
        \]
      /ix

      ATTRIBUTE_VALUE =
        /
        (?:
          "[^"]*"
          | '[^']*'
          | «[^»]*»
          | “[^”]*”
          | ”[^”]*”
          | ‘[^’]*’
          | „[^“]*“
          | ‚[^’]*’
          | ‹[^›]*›
          | [^\s\]]+
        )
      /x

      def self.call(event_date)
        new(event_date).call
      end

      def initialize(event_date)
        @event_date = event_date
        @event = event_date.event
      end

      def call
        original_raw = post.raw
        original_title = topic.title
        event_open_tag_match = rendered_event_open_tag_match(original_raw)
        raise Discourse::InvalidParameters.new(:event) unless event_open_tag_match

        invitees = snapshot_invitees

        next_occurrence = event.calculate_next_occurrence_from(event_date.starts_at + 1.second)

        successor_post = nil

        Event.transaction do
          topic.acting_user = Discourse.system_user

          archived_raw =
            rewrite_event_attributes(
              original_raw,
              event_open_tag_match,
              "start" => format_date(event_date.starts_at),
              "end" => formatted_end(event_date.ends_at),
              "recurrence" => nil,
              "recurrence-until" => nil,
              "recurrenceUntil" => nil,
            )

          revisor = PostRevisor.new(post)
          revised =
            revisor.revise!(
              Discourse.system_user,
              { raw: archived_raw, title: archived_title(original_title) },
              bypass_bump: true,
            )

          unless revised
            errors = (topic.errors.full_messages + post.errors.full_messages).uniq
            raise ActiveRecord::RecordNotSaved.new(errors.to_sentence)
          end

          if next_occurrence
            successor_raw =
              rewrite_event_attributes(
                original_raw,
                event_open_tag_match,
                "start" => format_date(next_occurrence[:starts_at]),
                "end" => formatted_end(next_occurrence[:ends_at]),
              )

            successor_post = create_successor_post(successor_raw, original_title)
            copy_recurring_invitees(invitees, successor_post)
          end
        end

        successor_post&.topic
      end

      private

      attr_reader :event_date, :event

      def post
        event.post
      end

      def topic
        post.topic
      end

      def create_successor_post(raw, title)
        PostCreator.create!(
          post.user || Discourse.system_user,
          guardian: Discourse.system_user.guardian,
          title:,
          raw:,
          category: topic.category_id,
          tags: topic.tags.pluck(:name),
        ).reload
      end

      def snapshot_invitees
        Invitee
          .unscoped
          .where(post_id: event.id)
          .pluck(:user_id, :status, :recurring, :notified)
          .map do |user_id, status, recurring, notified|
            { user_id:, status:, recurring:, notified: }
          end
      end

      def copy_recurring_invitees(invitees, successor_post)
        successor_event = successor_post.event
        going = Invitee.statuses[:going]

        invitees
          .select { |invitee| invitee[:status] == going && invitee[:recurring] }
          .each do |invitee|
            successor_invitee =
              Invitee.create!(
                post_id: successor_event.id,
                user_id: invitee[:user_id],
                status: going,
                recurring: true,
                notified: invitee[:notified],
              )

            successor_invitee.update_topic_tracking!
          end
      end

      def archived_title(original_title)
        date =
          if event.all_day
            event_date.starts_at.utc.strftime("%Y-%m-%d")
          else
            event_date.starts_at.in_time_zone(event.rrule_timezone).strftime("%Y-%m-%d")
          end

        suffix = " — #{date}"
        candidate = title_with_suffix(original_title, suffix)
        return candidate unless archived_title_taken?(candidate)

        suffix = " — #{date} ##{topic.id}"
        candidate = title_with_suffix(original_title, suffix)
        return candidate unless archived_title_taken?(candidate)

        counter = 2

        loop do
          suffix = " — #{date} ##{topic.id}-#{counter}"
          candidate = title_with_suffix(original_title, suffix)
          return candidate unless archived_title_taken?(candidate)

          counter += 1
        end
      end

      def title_with_suffix(original_title, suffix)
        max_length = SiteSetting.max_topic_title_length
        return suffix[-max_length, max_length] if suffix.length >= max_length

        title_length = max_length - suffix.length
        "#{original_title.truncate(title_length, omission: "").rstrip}#{suffix}"
      end

      def archived_title_taken?(candidate)
        return false if SiteSetting.duplicate_topic_titles.allowed?

        topic
          .duplicate_title_candidates
          .where.not(id: topic.id)
          .where("lower(title) = ?", candidate.downcase)
          .exists?
      end

      def formatted_end(value)
        return nil if event.original_ends_at.nil?
        return nil if value.nil?

        format_date(value)
      end

      def format_date(value)
        if event.all_day
          value.utc.strftime("%Y-%m-%d")
        else
          value.in_time_zone(event.rrule_timezone).strftime("%Y-%m-%d %H:%M")
        end
      end

      def rewrite_event_attributes(raw, match, attributes)
        opening_tag = match[0]

        attributes.each { |name, value| opening_tag = rewrite_attribute(opening_tag, name, value) }

        raw[0...match.begin(0)] + opening_tag + raw[match.end(0)..]
      end

      def rendered_event_open_tag_match(raw)
        matches = raw.to_enum(:scan, EVENT_OPEN_TAG).map { Regexp.last_match.dup }
        return if matches.empty?
        return matches.first if matches.one?

        marked_raw =
          raw
            .gsub(EVENT_OPEN_TAG)
            .with_index do |opening_tag, index|
              opening_tag.sub(/\]\z/, %( rolloverMarker="candidate-#{index}"]))
            end

        cooked = PrettyText.cook(marked_raw, topic_id: post.topic_id, user_id: post.user_id)

        marker =
          Nokogiri::HTML5
            .fragment(cooked)
            .at_css("div.discourse-post-event[data-rollover-marker]")
            &.[]("data-rollover-marker")

        return if !marker&.match?(/\Acandidate-\d+\z/)

        matches[marker.delete_prefix("candidate-").to_i]
      end

      def rewrite_attribute(opening_tag, name, value)
        pattern =
          /
            \s+#{Regexp.escape(name)}
            (?:=#{ATTRIBUTE_VALUE})?
            (?=\s|\])
          /ix

        opening_tag = opening_tag.gsub(pattern, "")
        return opening_tag if value.nil?

        serialized = serialize_attribute(name, value)
        opening_tag.sub(/\]\z/, " #{serialized}]")
      end

      def serialize_attribute(name, value)
        string_value = value.to_s

        return "#{name}=#{string_value}" unless string_value.match?(/[\s\]]/)

        QUOTATION_MARKS.each do |open_quote, close_quote|
          if string_value.exclude?(open_quote) && string_value.exclude?(close_quote)
            return "#{name}=#{open_quote}#{string_value}#{close_quote}"
          end
        end

        %(#{name}="#{string_value.delete('"')}")
      end
    end
  end
end
