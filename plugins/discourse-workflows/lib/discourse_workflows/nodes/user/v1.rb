# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module User
      class V1 < NodeType
        OPERATIONS = %w[get edit].freeze
        UPDATE_OPTIONS = [
          { name: "bio_raw", type: :string, required: false, ui: { control: :textarea } },
          { name: "website", type: :string, required: false },
          { name: "location", type: :string, required: false },
          { name: "title", type: :string, required: false },
          { name: "remove_avatar", type: :boolean, required: false },
          { name: "remove_profile_background", type: :boolean, required: false },
          { name: "remove_card_background", type: :boolean, required: false },
          { name: "trust_level", type: :options, required: true, options: trust_level_options },
          { name: "trust_level_locked", type: :boolean, required: false },
        ].freeze
        MISSING = DiscourseWorkflows::Executor::NodeExecutionContext::MISSING
        TEXT_UPDATES = %w[title website location].freeze
        BACKGROUND_REMOVALS = {
          "remove_profile_background" => :profile_background_upload_url,
          "remove_card_background" => :card_background_upload_url,
        }.freeze

        EXTENSIONS = {
          "stats" => :stats_extension,
          "external_ids" => :external_ids_extension,
          "emails" => :emails_extension,
          "ips" => :ips_extension,
        }.freeze
        STAT_FIELDS = %i[
          topics_entered
          posts_read_count
          time_read
          days_visited
          post_count
          topic_count
          likes_given
          likes_received
          first_post_created_at
        ].freeze

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
          output_contracts: [
            {
              schema: Schema::USER_ACTION_SCHEMA,
              extensions:
                Schema::USER_EXTENSION_SCHEMAS.map do |name, schema|
                  { schema:, display_options: { show: { include_extensions: [name] } } }
                end,
            },
          ],
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
            include_extensions: {
              type: :multi_options,
              required: false,
              options: EXTENSIONS.keys,
              default: [],
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
          extensions = requested_extensions(exec_ctx, item_index)

          case operation
          when "get"
            get_user(user, actor.guardian, extensions:)
          when "edit"
            edit_user(exec_ctx, user, actor, item_index, extensions:)
          else
            raise_node_error!(
              I18n.t("discourse_workflows.errors.unknown_operation", operation: operation),
            )
          end
        end

        def requested_extensions(exec_ctx, item_index)
          requested = exec_ctx.get_node_parameter("include_extensions", item_index, default: [])
          requested = [requested] unless requested.is_a?(Array)
          requested = requested.compact.map(&:to_s)
          unknown = requested - EXTENSIONS.keys

          if unknown.any?
            raise_node_error!(
              I18n.t(
                "discourse_workflows.errors.user.unknown_extensions",
                extensions: unknown.sort.join(", "),
              ),
            )
          end

          requested
        end

        def get_user(user, guardian, extensions:)
          guardian.ensure_can_see_profile!(user)
          { user: user_data(user, guardian, extensions:) }
        end

        def edit_user(exec_ctx, user, actor, item_index, extensions:)
          guardian = actor.guardian
          updates = update_parameters(exec_ctx, item_index)
          attributes = editable_attributes(updates)
          trust_level = updates.fetch("trust_level", MISSING)
          trust_level_locked = updates.fetch("trust_level_locked", MISSING)

          update_profile_fields(user, actor, guardian, attributes) if attributes.present?
          remove_avatar(user, actor, guardian) if updates["remove_avatar"]
          change_trust_level(user, actor, guardian, trust_level) unless trust_level.equal?(MISSING)
          unless trust_level_locked.equal?(MISSING)
            update_trust_level_lock(user, actor, guardian, trust_level_locked)
          end

          { user: user_data(user.reload, guardian, extensions:) }
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
            next if value.equal?(MISSING)

            value = ActiveModel::Type::Boolean.new.cast(value) == true if field[:type] == :boolean
            updates[name] = value
          end
        end

        def editable_attributes(updates)
          {}.tap do |attributes|
            attributes[:bio_raw] = updates["bio_raw"] if updates.key?("bio_raw")
            TEXT_UPDATES.each do |name|
              attributes[name.to_sym] = updates[name].to_s if updates.key?(name)
            end
            BACKGROUND_REMOVALS.each do |flag, attribute|
              attributes[attribute] = "" if updates[flag]
            end
          end
        end

        def remove_avatar(user, actor, guardian)
          guardian.ensure_can_edit!(user)
          user.remove_avatar!(actor)
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

        def user_data(user, guardian, extensions:)
          profile = user.user_profile if include_profile_details?(user, guardian)

          serialize_user(user, guardian: guardian).merge(
            title: user.title,
            bio_raw: profile&.bio_raw,
            website: profile&.website,
            profile_background_upload_id: profile&.profile_background_upload_id,
            card_background_upload_id: profile&.card_background_upload_id,
            manual_locked_trust_level: user.manual_locked_trust_level,
            trust_level_locked: !user.manual_locked_trust_level.nil?,
            user_fields: profile ? user.user_fields(guardian.allowed_user_field_ids(user)) : {},
            groups: groups_data(user, guardian),
          ).merge(extensions_data(user, guardian, extensions))
        end

        def extensions_data(user, guardian, extensions)
          extensions.reduce({}) do |data, extension|
            data.merge(send(EXTENSIONS.fetch(extension), user, guardian))
          end
        end

        def external_ids_extension(user, guardian)
          {
            external_id: connect_external_id(user, guardian),
            external_ids: associated_account_ids(user, guardian),
          }
        end

        def stats_extension(user, _guardian)
          stat = user.user_stat
          return { stats: nil } if stat.blank?

          { stats: STAT_FIELDS.index_with { |field| stat.public_send(field) } }
        end

        def emails_extension(user, guardian)
          return { email: nil, secondary_emails: [] } unless guardian.can_check_emails?(user)

          log_email_check(user, guardian)

          { email: user.email, secondary_emails: user.secondary_emails }
        end

        def log_email_check(user, guardian)
          return if guardian.user.blank? || guardian.user == user

          StaffActionLogger.new(guardian.user).log_check_email(
            user,
            context: I18n.t("discourse_workflows.user.check_email_context"),
          )
        end

        def ips_extension(user, guardian)
          return blank_ips unless guardian.can_see_ip?

          {
            registration_ip_address: user.registration_ip_address&.to_s,
            registration_location: ip_location(user.registration_ip_address),
            ip_address: user.ip_address&.to_s,
            last_location: ip_location(user.ip_address),
          }
        end

        def blank_ips
          {
            registration_ip_address: nil,
            registration_location: nil,
            ip_address: nil,
            last_location: nil,
          }
        end

        def ip_location(ip)
          return nil if ip.blank?

          DiscourseIpInfo.get(ip.to_s).presence
        end

        def connect_external_id(user, guardian)
          return nil unless guardian.can_check_sso_details?(user)

          user.single_sign_on_record&.external_id
        end

        def associated_account_ids(user, guardian)
          return {} unless guardian.is_admin?

          user.user_associated_accounts.to_h do |account|
            [account.provider_name, account.provider_uid]
          end
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
