# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    # Suspend, unsuspend, silence and unsilence user go through the services behind the admin user page, for
    # staff only. Each node defines NOT_ALLOWED_ERROR, the full key of its permission error.
    module UserModerationAction
      include UserChangeAction

      I18N_SCOPE = "user_moderation_action"
      SCHEDULES = %w[after_duration at_time].freeze
      DURATION_UNITS = %w[hours days weeks months years].freeze
      # Core's own "forever" penalties last 1000 years.
      MAX_DURATION = 1000.years

      def self.description(name:, icon:, changed:, properties: {}, output: {})
        UserChangeAction.description(
          name:,
          icon:,
          color: "red",
          i18n_scope: I18N_SCOPE,
          changed:,
          properties:,
          output:,
        )
      end

      # Suspend and silence user: the penalty's end (after a duration or at a time named after the core
      # field), its reason, the message to the user and the post it's for.
      def self.penalty_description(name:, icon:, end_field:, changed:)
        at_time = { display_options: { show: { schedule: ["at_time"] } } }
        after_duration = { display_options: { show: { schedule: ["after_duration"] } } }
        end_time = {
          end_field => {
            type: :string,
            required: false,
            ui: {
              control: :date_time,
            },
            **at_time,
          },
        }

        description(
          name:,
          icon:,
          changed:,
          properties: {
            schedule: {
              type: :options,
              required: true,
              default: "after_duration",
              options: SCHEDULES,
            },
            duration: {
              type: :integer,
              required: false,
              default: 7,
              **after_duration,
            },
            duration_unit: {
              type: :options,
              required: false,
              default: "days",
              options: DURATION_UNITS,
              **after_duration,
            },
            **end_time,
            **NodeType.timezone_property(
              none: "discourse_workflows.user_moderation_action.timezone_none",
              **at_time,
            ),
            reason: {
              type: :string,
              required: true,
              ui: {
                control: :textarea,
              },
            },
            message: {
              type: :string,
              required: false,
              ui: {
                control: :textarea,
              },
            },
            post_id: {
              type: :string,
              required: false,
            },
          },
          output: {
            "expires_at" => {
              "type" => "string",
              "format" => "date-time",
              "description" =>
                "When the penalty in force ends, whether it's new or was already there",
            },
          },
        )
      end

      private

      # Checked before looking at the user's state, so reporting nothing changed still needs the permission.
      def ensure_allowed!(allowed, actor, user, item_index)
        return if allowed

        moderation_error!(
          self.class::NOT_ALLOWED_ERROR,
          item_index,
          username: actor.username,
          target: user.username,
        )
      end

      def penalty_end(exec_ctx, field, item_index)
        schedule =
          exec_ctx.get_node_parameter("schedule", item_index, default: "after_duration").to_s
        case schedule
        when "after_duration"
          penalty_duration(exec_ctx, item_index).from_now
        when "at_time"
          penalty_time(exec_ctx, field, item_index)
        else
          moderation_error!(
            "discourse_workflows.errors.user_moderation_action.invalid_schedule",
            item_index,
            schedule:,
          )
        end
      end

      def penalty_duration(exec_ctx, item_index)
        value = exec_ctx.get_node_parameter("duration", item_index, default: 7)
        unit = exec_ctx.get_node_parameter("duration_unit", item_index, default: "days").to_s
        if DURATION_UNITS.exclude?(unit)
          moderation_error!(
            "discourse_workflows.errors.user_moderation_action.invalid_duration_unit",
            item_index,
            duration_unit: unit,
          )
        end

        amount = Integer(value.to_s, 10, exception: false)
        duration = amount&.public_send(unit)
        if duration.nil? || duration <= 0 || duration > MAX_DURATION
          moderation_error!(
            "discourse_workflows.errors.user_moderation_action.invalid_duration",
            item_index,
            value:,
          )
        end

        duration
      end

      def penalty_time(exec_ctx, field, item_index)
        time =
          parse_time_in_timezone(
            exec_ctx,
            exec_ctx.get_node_parameter(field, item_index),
            item_index:,
            field:,
            error_key: "discourse_workflows.errors.user_moderation_action.invalid_time",
          )
        if time.nil?
          moderation_error!(
            "discourse_workflows.errors.user_moderation_action.time_required",
            item_index,
            field:,
          )
        end
        if time <= Time.zone.now
          moderation_error!(
            "discourse_workflows.errors.user_moderation_action.time_in_past",
            item_index,
            field:,
            value: time.iso8601,
          )
        end

        time
      end

      # Deleted posts count: penalising the author of a post just deleted is the usual case.
      def penalty_post_id(exec_ctx, item_index)
        value = exec_ctx.get_node_parameter("post_id", item_index).to_s.presence
        return if value.nil?

        post_id = Integer(value, 10, exception: false)
        if post_id.nil? || !::Post.with_deleted.exists?(id: post_id)
          moderation_error!(
            "discourse_workflows.errors.user_moderation_action.post_not_found",
            item_index,
            post_id: value,
          )
        end

        post_id
      end

      def penalty_params(exec_ctx, user, item_index)
        {
          user_id: user.id,
          reason: exec_ctx.get_node_parameter("reason", item_index).to_s,
          message: exec_ctx.get_node_parameter("message", item_index).to_s.presence,
          post_id: penalty_post_id(exec_ctx, item_index),
        }
      end

      # Returns whether the service penalised the user: false when a concurrent request got there first.
      def apply_penalty(service, actor, user, params, item_index, already:, allowed:)
        service.call(guardian: actor.guardian, params:, options: { raise_on_failure: true }) do
          on_success { true }
          on_failed_policy(already) { false }
          on_failed_policy(allowed) { ensure_allowed!(false, actor, user, item_index) }
          on_failed_contract do |contract|
            penalty_invalid!(contract.errors.full_messages, user, item_index)
          end
          on_failure do
            moderation_error!(
              "discourse_workflows.errors.user_moderation_action.failed",
              item_index,
              username: user.username,
            )
          end
        end
      rescue ActiveRecord::RecordInvalid => e
        penalty_invalid!(e.record.errors.full_messages, user, item_index)
      end

      def penalty_invalid!(messages, user, item_index)
        if messages.blank?
          moderation_error!(
            "discourse_workflows.errors.user_moderation_action.failed",
            item_index,
            username: user.username,
          )
        end

        moderation_error!(
          "discourse_workflows.errors.user_moderation_action.invalid",
          item_index,
          username: user.username,
          errors: messages.join(", "),
        )
      end

      def moderation_error!(key, item_index, **args)
        raise_node_error!(I18n.t(key, **args), item_index:)
      end
    end
  end
end
