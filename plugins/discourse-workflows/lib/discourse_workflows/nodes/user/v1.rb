# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module User
      class V1 < NodeType
        OPERATIONS = %w[get edit].freeze
        UPDATE_OPTIONS = [
          { name: "bio_raw", type: :string, required: false, ui: { control: :textarea } },
          { name: "title", type: :string, required: false },
          { name: "trust_level", type: :options, required: true, options: trust_level_options },
          { name: "trust_level_locked", type: :boolean, required: false },
        ].freeze
        MISSING = DiscourseWorkflows::Executor::NodeExecutionContext::MISSING

        description(
          name: "action:user",
          version: "1.0",
          defaults: {
            icon: "user",
            color: "blue",
          },
          group: "discourse_actions",
          capabilities: {
            run_scope: "per_item",
          },
          output_contracts: [{ schema: Schema::USER_ACTION_SCHEMA }],
          properties: {
            operation: {
              type: :options,
              required: true,
              options: OPERATIONS,
              default: "get",
              ui: {
                expression: true,
              },
            },
            username: {
              type: :string,
              required: true,
              ui: {
                control: :user,
              },
            },
            updates: {
              type: :collection,
              required: false,
              options: UPDATE_OPTIONS,
              type_options: {
                add_optional_field_button_text: "discourse_workflows.property_engine.add_field",
              },
              display_options: {
                show: {
                  operation: ["edit"],
                },
              },
            },
            actor_username: {
              type: :string,
              required: false,
              default: "system",
              ui: {
                control: :actor,
              },
            },
          },
        )

        def execute(exec_ctx)
          items =
            exec_ctx.input_items.map.with_index do |_item, item_index|
              operation = exec_ctx.get_node_parameter("operation", item_index, default: "get")
              user =
                exec_ctx.find_user(username: exec_ctx.get_node_parameter("username", item_index))
              actor = exec_ctx.actor_from_parameter("actor_username", item_index)

              wrap(process(exec_ctx, user, actor, operation, item_index))
            end

          [items]
        end

        private

        def process(exec_ctx, user, actor, operation, item_index)
          case operation
          when "get"
            get_user(user, actor.guardian)
          when "edit"
            edit_user(exec_ctx, user, actor, item_index)
          else
            raise_node_error!(
              I18n.t("discourse_workflows.errors.user.unknown_operation", operation: operation),
            )
          end
        end

        def get_user(user, guardian)
          guardian.ensure_can_see_profile!(user)
          { user: user_data(user, guardian) }
        end

        def edit_user(exec_ctx, user, actor, item_index)
          guardian = actor.guardian
          updates = update_parameters(exec_ctx, item_index)
          attributes = editable_attributes(updates)
          trust_level = updates.fetch("trust_level", MISSING)
          trust_level_locked = updates.fetch("trust_level_locked", MISSING)

          update_profile_fields(user, actor, guardian, attributes) if attributes.present?
          change_trust_level(user, actor, guardian, trust_level) unless trust_level.equal?(MISSING)
          unless trust_level_locked.equal?(MISSING)
            update_trust_level_lock(user, actor, guardian, trust_level_locked)
          end

          { user: user_data(user.reload, guardian) }
        end

        def update_parameters(exec_ctx, item_index)
          updates = exec_ctx.get_node_parameter("updates", item_index, default: {})
          return legacy_update_parameters(exec_ctx, item_index) if updates.blank?
          return updates.deep_stringify_keys if updates.is_a?(Hash)

          raise_node_error!(I18n.t("discourse_workflows.errors.user.invalid_updates"))
        end

        def legacy_update_parameters(exec_ctx, item_index)
          UPDATE_OPTIONS.each_with_object({}) do |field, updates|
            name = field[:name]
            value = exec_ctx.get_node_parameter(name, item_index, default: MISSING)
            updates[name] = value unless value.equal?(MISSING)
          end
        end

        def editable_attributes(updates)
          {}.tap do |attributes|
            attributes[:bio_raw] = updates["bio_raw"] if updates.key?("bio_raw")
            attributes[:title] = updates["title"].to_s if updates.key?("title")
          end
        end

        def update_profile_fields(user, actor, guardian, attributes)
          guardian.ensure_can_edit!(user)
          guardian.ensure_can_grant_title!(user, attributes[:title]) if attributes.key?(:title)

          return if UserUpdater.new(actor, user).update(attributes)

          errors = validation_errors_for(user)
          raise_node_error!(
            I18n.t(
              "discourse_workflows.errors.user.update_failed",
              errors: errors.presence || I18n.t("errors.messages.invalid"),
            ),
          )
        end

        def change_trust_level(user, actor, guardian, trust_level)
          guardian.ensure_can_change_trust_level!(user)
          trust_level = normalize_trust_level(trust_level)

          if user.manual_locked_trust_level.nil?
            lock_trust_level_for_manual_change(user, trust_level)
          end
          user.change_trust_level!(trust_level, log_action_for: actor)
        end

        def lock_trust_level_for_manual_change(user, trust_level)
          if [0, 1, 2].include?(trust_level) &&
               Promotion.public_send("tl#{trust_level + 1}_met?", user)
            user.manual_locked_trust_level = trust_level
            user.save!
          elsif trust_level == 3 && Promotion.tl3_lost?(user)
            user.manual_locked_trust_level = trust_level
            user.save!
          end
        end

        def update_trust_level_lock(user, actor, guardian, trust_level_locked)
          guardian.ensure_can_change_trust_level!(user)

          user.manual_locked_trust_level = trust_level_locked ? user.trust_level : nil
          user.save!

          StaffActionLogger.new(actor).log_lock_trust_level(user)
          Promotion.recalculate(user, actor)
        end

        def normalize_trust_level(value)
          trust_level = Integer(value, exception: false)
          return trust_level if trust_level && TrustLevel.valid?(trust_level)

          raise_node_error!(
            I18n.t("discourse_workflows.errors.user.invalid_trust_level", level: value.inspect),
          )
        end

        def user_data(user, guardian)
          include_profile_details = include_profile_details?(user, guardian)

          serialize_user(user, guardian: guardian).merge(
            title: user.title,
            bio_raw: include_profile_details ? user.user_profile.bio_raw : nil,
            manual_locked_trust_level: user.manual_locked_trust_level,
            trust_level_locked: !user.manual_locked_trust_level.nil?,
            user_fields:
              (
                if include_profile_details
                  user.user_fields(guardian.allowed_user_field_ids(user))
                else
                  {}
                end
              ),
            groups: groups_data(user, guardian),
          )
        end

        def include_profile_details?(user, guardian)
          guardian.public_can_see_profiles? && !guardian.restrict_user_fields?(user)
        end

        def groups_data(user, guardian)
          groups = user.groups.visible_groups(guardian.user)
          groups = groups.members_visible_groups(guardian.user) if guardian.user != user

          groups
            .order(:name)
            .map do |group|
              {
                id: group.id,
                name: group.name,
                full_name: group.full_name,
                automatic: group.automatic,
              }
            end
        end

        def validation_errors_for(user)
          [user, user.user_profile, user.user_option].compact
            .flat_map { |record| record.errors.full_messages }
            .join(", ")
        end
      end
    end
  end
end
