# frozen_string_literal: true

module Jobs
  class DiscoursePostEventBulkInvite < ::Jobs::Base
    sidekiq_options retry: false

    def initialize
      super

      @logs = []
      @processed = 0
      @failed = 0
    end

    def execute(args)
      invitees = args[:invitees]
      raise Discourse::InvalidParameters.new(:invitees) if invitees.blank?

      @current_user = User.find_by(id: args[:current_user_id])
      raise Discourse::InvalidParameters.new(:current_user_id) unless @current_user

      @event = DiscoursePostEvent::Event.find_by(id: args[:event_id])
      raise Discourse::InvalidParameters.new(:event_id) unless @event

      @guardian = Guardian.new(@current_user)
      @guardian.ensure_can_edit!(@event.post)

      process_invitees(invitees)
    ensure
      notify_user
    end

    private

    def process_invitees(invitees)
      invitees = filter_out_unavailable_groups(invitees)

      max_bulk_invitees = SiteSetting.discourse_post_event_max_bulk_invitees

      invitees.each do |invitee|
        break if @processed >= max_bulk_invitees
        process_invitee(invitee)
      end

      if @processed > 0
        @event.publish_update!
        @event.notify_invitees!(predefined_attendance: true)
      end
    rescue Exception => e
      save_log "Bulk Invite Process Failed -- '#{e.message}'"
      @failed += 1
    end

    def process_invitee(invitee)
      if @event.public?
        users = User.where(username: invitee["identifier"]).pluck(:id)
      else
        group = Group.find_by(name: invitee["identifier"])
        if group
          users = group.users.pluck(:id)
          @event.update_with_params!(
            raw_invitees: (@event.raw_invitees || []).push(group.name).uniq,
          )
        end
      end

      if users.blank?
        save_log "Couldn't find user or group: '#{invitee["identifier"]}' or the groups provided contained no users. Note that public events can't bulk invite groups. And other events can't bulk invite usernames."
        @failed += 1
        return
      end

      users.each do |user_id|
        create_attendance(user_id, @event.post.id, invitee["attendance"] || "going")
      end

      @processed += 1
    rescue Exception => e
      save_log "Bulk Invite Process Failed -- '#{e.message}'"
      @failed += 1
    end

    def create_attendance(user_id, post_id, attendance)
      unknown = DiscoursePostEvent::Invitee::UNKNOWN_ATTENDANCE

      if attendance == unknown
        DiscoursePostEvent::Invitee.where(user_id: user_id, post_id: post_id).destroy_all
      else
        status = DiscoursePostEvent::Invitee.statuses[attendance.to_sym]
        invitee =
          DiscoursePostEvent::Invitee.find_or_initialize_by(user_id: user_id, post_id: post_id)
        invitee.notified = false
        invitee.status = status
        invitee.save!
      end
    end

    def save_log(message)
      @logs << "[#{Time.zone.now}] #{message}"
    end

    def notify_user
      if @current_user
        if @processed > 0 && @failed == 0
          SystemMessage.create_from_system_user(
            @current_user,
            :discourse_post_event_bulk_invite_succeeded,
            processed: @processed,
          )
        else
          SystemMessage.create_from_system_user(
            @current_user,
            :discourse_post_event_bulk_invite_failed,
            processed: @processed,
            failed: @failed,
            logs: @logs.join("\n"),
          )
        end
      end
    end

    def invitee_groups(invitees)
      Group.where(name: invitees.map { |i| i[:identifier] })
    end

    def filter_out_unavailable_groups(invitees)
      groups = invitee_groups(invitees)
      invitees.filter do |i|
        group = groups.find { |g| g.name === i[:identifier] }

        !group || (@guardian.can_see_group?(group) && @guardian.can_see_group_members?(group))
      end
    end
  end
end
