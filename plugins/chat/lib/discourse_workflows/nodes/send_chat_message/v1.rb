# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module SendChatMessage
        class V1 < DiscourseWorkflows::NodeType
          include ChatChannelSelection

          TARGETS = %w[channel user group].freeze
          DM_TARGETS = %w[user group].freeze

          # Per-item state passed through the send helpers.
          ItemRun =
            Data.define(:exec_ctx, :item, :item_index, :message) do
              def parameter(path, default: nil)
                exec_ctx.get_node_parameter(path, item_index, default:)
              end
            end

          description(
            name: "action:send_chat_message",
            version: "1.0",
            defaults: {
              icon: "comment",
              color: "teal",
            },
            group: "discourse_actions",
            available: -> { SiteSetting.chat_enabled },
            unavailable_reason_key: "discourse_workflows.node_unavailable.requires_chat",
            capabilities: {
              run_scope: "per_item",
            },
            output_contracts: [
              {
                schema: {
                  "$schema" => DiscourseWorkflows::Schema::DRAFT_URI,
                  "type" => "object",
                  "properties" => {
                    "channel_id" => {
                      "type" => "integer",
                    },
                    "message_id" => {
                      "type" => "integer",
                    },
                    "message" => {
                      "type" => "string",
                    },
                    "username" => {
                      "type" => "string",
                    },
                    "usernames" => {
                      "type" => "array",
                      "items" => {
                        "type" => "string",
                      },
                    },
                  },
                },
              },
            ],
            properties: {
              target: {
                type: :options,
                required: true,
                options: TARGETS,
                default: "channel",
              },
              channel_id: {
                type: :integer,
                required: true,
                display_options: {
                  show: {
                    target: ["channel"],
                  },
                },
                type_options: {
                  load_options_method: "chat_channels",
                },
                ui: {
                  control: :combo_box,
                  dynamic_value: :chat_channel_id,
                },
                control_options: {
                  filterable: true,
                  value_property: :id,
                  name_property: :name,
                  set_from_option: {
                    channel_name: "name",
                  },
                },
              },
              channel_name: {
                type: :string,
                ui: {
                  hidden: true,
                },
              },
              target_usernames: {
                type: :array,
                required: true,
                display_options: {
                  show: {
                    target: DM_TARGETS,
                  },
                },
                ui: {
                  control: :user,
                  expression: true,
                  multiple: true,
                },
              },
              message: {
                type: :string,
                required: true,
                ui: {
                  control: :textarea,
                },
              },
              **actor_property(
                allow_anonymous: false,
                display_options: {
                  show: {
                    target: DM_TARGETS,
                  },
                },
              ),
            },
          )

          def self.load_options_context(context)
            case context.method_name
            when "chat_channels"
              ChatChannelSelection.load_options(context)
            end
          end

          def execute(exec_ctx)
            items =
              exec_ctx.each_item do |item, item_index|
                run =
                  ItemRun.new(
                    exec_ctx:,
                    item:,
                    item_index:,
                    message: exec_ctx.get_node_parameter("message", item_index),
                  )
                target = run.parameter("target", default: "channel")
                if DM_TARGETS.include?(target)
                  send_direct_messages(run, group: target == "group")
                else
                  send_to_channel(run)
                end
              end
            [items]
          end

          private

          def send_to_channel(run)
            channel_id = run.parameter("channel_id")
            channel = selectable_chat_channel(channel_id)

            node_error!(run, :channel_not_found, channel_id:) if channel.blank?

            wrap(
              create_message(
                run,
                :channel,
                Discourse.system_user.guardian,
                channel,
                channel_id: channel.id,
              ),
            )
          end

          def send_direct_messages(run, group:)
            sender = run.exec_ctx.actor_from_parameter("actor_username", run.item_index)
            # `allow_anonymous: false` only hides the option in the UI.
            node_error!(run, :sender_anonymous) if sender.is_a?(DiscourseWorkflows::AnonymousActor)

            # Account states are checked for every recipient before anything is sent.
            recipients = resolve_recipients!(run)
            ensure_sender_can_chat!(run, sender)

            if group
              members = recipients.reject { |recipient| recipient.id == sender.id }.presence
              members ||= recipients
              result = deliver_dm(run, sender, members)
              return wrap(result.merge("usernames" => members.map(&:username)))
            end

            recipients.map do |recipient|
              run
                .exec_ctx
                .guard_item(run.item, run.item_index) do
                  result = deliver_dm(run, sender, [recipient])
                  wrap(result.merge("username" => recipient.username))
                end
            end
          end

          # A single recipient gets a 1:1 DM, several share one group DM.
          def deliver_dm(run, sender, recipients)
            usernames = recipients.map(&:username)
            target, labels =
              if recipients.one?
                [:user, { sender: sender.username, username: usernames.first }]
              else
                [
                  :group,
                  {
                    sender: sender.username,
                    usernames: usernames.map { |username| "'#{username}'" }.join(", "),
                  },
                ]
              end

            # Rolls back a newly created DM channel when the message itself is rejected. Jobs
            # enqueued by the message are deferred until commit.
            result =
              ActiveRecord::Base.transaction(requires_new: true) do
                channel = create_direct_message_channel(run, sender, usernames, target, labels)
                create_message(run, target, sender.guardian, channel, **labels)
              end

            # Step metadata keeps hints even when the step fails, so only add them once delivered.
            add_delivery_hints(run, sender, recipients)
            result
          end

          def add_delivery_hints(run, sender, recipients)
            recipients.each do |recipient|
              if recipient.id == sender.id
                add_hint(run, :self_message, username: sender.username)
              elsif preferences_bypassed?(sender, recipient)
                add_hint(
                  run,
                  :preferences_bypassed,
                  sender: sender.username,
                  username: recipient.username,
                )
              end
            end
          end

          # Mirrors UserCommScreener, which skips these checks entirely for staff senders.
          def preferences_bypassed?(sender, recipient)
            return false if !sender.staff?

            options = recipient.user_option
            guardian = sender.guardian

            !options.allow_private_messages || guardian.is_muted_by_user?(recipient) ||
              guardian.is_ignored_by_user?(recipient) ||
              (
                options.enable_allowed_pm_users &&
                  !::AllowedPmUser.exists?(user_id: recipient.id, allowed_pm_user_id: sender.id)
              )
          end

          def resolve_recipients!(run)
            usernames = normalize_usernames(run.parameter("target_usernames"))
            node_error!(run, :recipient_blank) if usernames.empty?

            usernames.map { |username| resolve_recipient!(run, username) }
          end

          def normalize_usernames(value)
            Array
              .wrap(value)
              .flat_map { |entry| entry.to_s.split(",") }
              .map { |username| username.strip.delete_prefix("@") }
              .reject(&:blank?)
              .uniq(&:downcase)
          end

          def resolve_recipient!(run, username)
            recipient = run.exec_ctx.find_user(username:, item_index: run.item_index)

            # Checked upfront because the chat services either silently drop such recipients
            # (falling back to a self-DM) or let staff senders store messages nobody will see.
            reason =
              if recipient.staged?
                :recipient_staged
              elsif recipient.suspended?
                :recipient_suspended
              elsif !recipient.active?
                :recipient_inactive
              elsif !recipient.user_option&.chat_enabled
                :recipient_chat_disabled
              elsif !recipient.guardian.can_chat?
                :recipient_cannot_chat
              end
            node_error!(run, reason, username: recipient.username) if reason

            recipient
          end

          # DM permissions are left to the service's policies; these would otherwise surface as
          # a missing target or a vague failure after the DM channel was created.
          def ensure_sender_can_chat!(run, sender)
            reason =
              if !sender.user_option&.chat_enabled
                :sender_chat_disabled
              elsif !sender.guardian.can_chat?
                :sender_cannot_chat
              end
            node_error!(run, reason, sender: sender.username) if reason
          end

          def create_direct_message_channel(run, sender, usernames, target, labels)
            Chat::CreateDirectMessageChannel.call(
              guardian: sender.guardian,
              # Upserting makes re-runs reuse the group DM with the same members.
              params: {
                target_usernames: usernames,
                upsert: true,
              },
            ) do |result|
              on_success { |channel:| channel }
              %i[targets_allow_dms_from_user satisfies_dms_max_users_limit].each do |policy_name|
                on_failed_policy(policy_name) do |policy|
                  node_error!(run, :"#{target}_blocked", **labels, reason: policy.reason)
                end
              end
              on_failed_policy(:can_create_direct_message) do
                node_error!(run, :sender_cannot_create_dm, **labels)
              end
              on_failed_policy(:actor_allows_dms) do
                node_error!(run, :sender_dms_disabled, **labels)
              end
              on_failure do
                node_error!(run, :failed, step: ChatServiceFailure.failed_step_name(result))
              end
            end
          end

          def create_message(run, target, guardian, channel, **labels)
            Chat::CreateMessage.call(
              guardian:,
              params: {
                chat_channel_id: channel.id,
                message: run.message,
              },
            ) do |result|
              on_success do |message_instance:|
                run.exec_ctx.log.info(
                  I18n.t(
                    "discourse_workflows.logs.send_chat_message.sent_to_#{target}",
                    item_index: run.item_index,
                    message_id: message_instance.id,
                    **labels,
                  ),
                )
                {
                  "channel_id" => channel.id,
                  "message_id" => message_instance.id,
                  "message" => run.message,
                }
              end
              on_failed_contract { |contract| invalid_params!(run, contract) }
              on_model_errors(:message_instance) do |message_instance|
                invalid_params!(run, message_instance)
              end
              on_failed_policy(:channel_allows_message_creation) do |policy|
                node_error!(run, :"#{target}_blocked", **labels, reason: policy.reason)
              end
              on_failure do
                node_error!(run, :failed, step: ChatServiceFailure.failed_step_name(result))
              end
            end
          end

          def invalid_params!(run, record)
            node_error!(run, :invalid_params, errors: record.errors.full_messages.join(", "))
          end

          def add_hint(run, key, **args)
            run.exec_ctx.add_execution_hints(
              {
                message: I18n.t("discourse_workflows.hints.send_chat_message.#{key}", **args),
                location: "outputPane",
              },
            )
          end

          def node_error!(run, key, **args)
            raise_node_error!(
              I18n.t("discourse_workflows.errors.send_chat_message.#{key}", **args),
              item_index: run.item_index,
            )
          end
        end
      end
    end
  end
end
