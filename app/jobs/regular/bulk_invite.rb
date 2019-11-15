# frozen_string_literal: true

module Jobs
  class BulkInvite < ::Jobs::Base
    sidekiq_options retry: false

    def initialize
      super
      @logs    = []
      @sent    = 0
      @failed  = 0
      @groups = {}
      @valid_groups = {}
    end

    def execute(args)
      invites = args[:invites]
      raise Discourse::InvalidParameters.new(:invites) if invites.blank?

      @current_user = User.find_by(id: args[:current_user_id])
      raise Discourse::InvalidParameters.new(:current_user_id) unless @current_user
      @guardian = Guardian.new(@current_user)
      @total_invites = invites.length

      process_invites(invites)

      if @total_invites > Invite::BULK_INVITE_EMAIL_LIMIT
        ::Jobs.enqueue(:process_bulk_invite_emails)
      end
    ensure
      notify_user
    end

    private

    def process_invites(invites)
      invites.each do |invite|
        if (EmailValidator.email_regex =~ invite[:email])
          # email is valid
          send_invite(invite)
          @sent += 1
        else
          # invalid email
          save_log "Invalid Email '#{invite[:email]}"
          @failed += 1
        end
      end
    rescue Exception => e
      save_log "Bulk Invite Process Failed -- '#{e.message}'"
      @failed += 1
    end

    def get_groups(group_names)
      groups = []

      if group_names
        group_names = group_names.split(';')

        group_names.each { |group_name|
          group = fetch_group(group_name)

          if group && can_edit_group?(group)
            # valid group
            groups.push(group)
          else
            # invalid group
            save_log "Invalid Group '#{group_name}'"
            @failed += 1
          end
        }
      end

      groups
    end

    def get_topic(topic_id)
      topic = nil

      if topic_id
        topic = Topic.find_by_id(topic_id)
        if topic.nil?
          save_log "Invalid Topic ID '#{topic_id}'"
          @failed += 1
        end
      end

      topic
    end

    def send_invite(invite)
      email = invite[:email]
      groups = get_groups(invite[:groups])
      topic = get_topic(invite[:topic_id])

      begin
        if user = Invite.find_user_by_email(email)
          if groups.present?
            Group.transaction do
              groups.each do |group|
                group.add(user)

                GroupActionLogger
                  .new(@current_user, group)
                  .log_add_user_to_group(user)
              end
            end
          end
        else
          if @total_invites > Invite::BULK_INVITE_EMAIL_LIMIT
            invite = Invite.create_invite_by_email(email, @current_user,
              topic: topic,
              group_ids: groups.map(&:id),
              emailed_status: Invite.emailed_status_types[:bulk_pending]
            )
          else
            Invite.invite_by_email(email, @current_user, topic, groups.map(&:id))
          end
        end
      rescue => e
        save_log "Error inviting '#{email}' -- #{Rails::Html::FullSanitizer.new.sanitize(e.message)}"
        @sent -= 1
        @failed += 1
      end
    end

    def save_log(message)
      @logs << "[#{Time.now}] #{message}"
    end

    def notify_user
      if @current_user
        if (@sent > 0 && @failed == 0)
          SystemMessage.create_from_system_user(
            @current_user,
            :bulk_invite_succeeded,
            sent: @sent
          )
        else
          SystemMessage.create_from_system_user(
            @current_user,
            :bulk_invite_failed,
            sent: @sent,
            failed: @failed,
            logs: @logs.join("\n")
          )
        end
      end
    end

    def fetch_group(group_name)
      group_name = group_name.downcase
      group = @groups[group_name]

      unless group
        group = Group.find_by("lower(name) = ?", group_name)
        @groups[group_name] = group
      end

      group
    end

    def can_edit_group?(group)
      group_name = group.name.downcase
      result = @valid_groups[group_name]

      unless result
        result = @guardian.can_edit_group?(group)
        @valid_groups[group_name] = result
      end

      result
    end
  end
end
