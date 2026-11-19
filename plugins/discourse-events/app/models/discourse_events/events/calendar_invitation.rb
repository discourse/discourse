# frozen_string_literal: true

module DiscourseEvents
  module Events
    class CalendarInvitation < ActiveRecord::Base
      self.table_name = "discourse_event_calendar_invitations"

      belongs_to :user
      belongs_to :event, optional: true

      after_commit :enqueue_delivery

      scope :pending, -> { where("sequence > delivered_sequence") }

      def self.enabled?
        SiteSetting.discourse_events_enabled && SiteSetting.discourse_post_event_enabled &&
          SiteSetting.event_calendar_invitations_enabled &&
          SiteSetting.event_calendar_invitations_organizer.present?
      end

      def self.invite!(event, user)
        return unless enabled?
        return if event.recurring? || event.deleted_at || event.original_starts_at <= Time.current
        return unless user.guardian.can_see?(event.post)

        event.with_lock do
          invitation = find_or_initialize_by(event_id: event.id, user_id: user.id)
          if invitation.new_record?
            identity = where(event_id: event.id).pick(:uid, :organizer)
            invitation.assign_attributes(
              uid:
                identity&.first ||
                  "discourse-event-#{event.id}-#{event.post.created_at.to_i}@#{Discourse.current_hostname}",
              organizer: identity&.last || SiteSetting.event_calendar_invitations_organizer,
              recipient: user.email,
              snapshot: snapshot_for(event),
            )
            invitation.save!
          elsif invitation.cancelled?
            invitation.update!(
              cancelled: false,
              snapshot: snapshot_for(event),
              sequence: invitation.sequence + 1,
            )
          end
        end
      end

      def self.snapshot_for(event)
        {
          "starts_at" => event.original_starts_at.utc.iso8601,
          "ends_at" => event.original_ends_at&.utc&.iso8601,
          "all_day" => event.all_day,
          "summary" => event.name.presence || event.post.topic.title,
          "description" => event.description.to_s,
          "location" => event.location.to_s,
          "url" => event.post.full_url,
          "event_url" => event.url,
        }
      end

      def self.sync_event!(event)
        where(event_id: event.id).find_each do |invitation|
          if event.destroyed? || event.deleted_at || event.recurring?
            invitation.cancel!
          else
            invitation.with_lock do
              next if invitation.cancelled?
              snapshot = snapshot_for(event)
              if snapshot != invitation.snapshot
                invitation.update!(snapshot: snapshot, sequence: invitation.sequence + 1)
              end
            end
          end
        end
      end

      def cancel!
        with_lock do
          return if cancelled?
          # Cancellation must never reveal edits made after a recipient lost access.
          update!(cancelled: true, snapshot: delivered_snapshot, sequence: sequence + 1)
        end
      end

      def deliver!
        return unless self.class.enabled?
        return if SiteSetting.private_email?

        with_lock do
          return if delivered_sequence >= sequence
          return unless deliverable_user?
          return unless Configuration::CalendarOrganizerValidator.new.valid_value?(organizer)

          unless cancelled?
            current_event = Event.find_by(id: event_id)
            if !current_event || current_event.deleted_at || current_event.recurring? ||
                 !user.guardian.can_see?(current_event.post) ||
                 (delivered_sequence < 0 && current_event.original_starts_at <= Time.current)
              cancel!
            end
          end

          if cancelled? && delivered_snapshot.empty?
            update!(delivered_sequence: sequence)
            return
          end

          log =
            I18n.with_locale(user.effective_locale) do
              message = CalendarInvitationMailer.invitation(self)
              Email::Sender.new(message, :event_calendar_invitation, user).send
            end
          if log.is_a?(EmailLog) && log.persisted?
            update!(delivered_sequence: sequence, delivered_snapshot: snapshot)
          end
        end
      end

      private

      def deliverable_user?
        user && user.human? && user.active && !user.staged? && !user.suspended? &&
          !user.silenced? && user.email == recipient &&
          user.user_option.email_level != UserOption.email_level_types[:never] &&
          user.user_stat.bounce_score < SiteSetting.bounce_score_threshold
      end

      def enqueue_delivery
        if sequence > delivered_sequence
          Jobs.enqueue(:deliver_event_calendar_invitation, invitation_id: id)
        end
      end
    end
  end
end

# == Schema Information
#
# Table name: discourse_event_calendar_invitations
#
#  id                 :bigint           not null, primary key
#  cancelled          :boolean          default(FALSE), not null
#  delivered_sequence :integer          default(-1), not null
#  delivered_snapshot :jsonb            not null
#  organizer          :string           not null
#  recipient          :string           not null
#  sequence           :integer          default(0), not null
#  snapshot           :jsonb            not null
#  uid                :string           not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  event_id           :bigint           not null
#  user_id            :bigint           not null
#
# Indexes
#
#  idx_on_event_id_user_id_ac31a754df                     (event_id,user_id) UNIQUE
#  index_discourse_event_calendar_invitations_on_user_id  (user_id)
#
