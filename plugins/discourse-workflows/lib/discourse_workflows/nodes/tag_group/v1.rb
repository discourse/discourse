# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module TagGroup
      class V1 < NodeType
        OPERATIONS = %w[add remove].freeze

        description(
          name: "action:tag_group",
          version: "1.0",
          defaults: {
            icon: "tags",
            color: "orange",
          },
          group: "discourse_actions",
          capabilities: {
            run_scope: "per_item",
          },
          output_contracts: [
            {
              schema: {
                "$schema" => Schema::DRAFT_URI,
                "type" => "object",
                "properties" => {
                  "tag_group_id" => {
                    "type" => "integer",
                  },
                  "tag_group_name" => {
                    "type" => "string",
                  },
                  "tag_names" => {
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
            operation: {
              type: :options,
              required: true,
              options: OPERATIONS,
              default: "add",
              ui: {
                expression: true,
              },
            },
            tag_group_id: {
              type: :integer,
              required: true,
              type_options: {
                load_options_method: "tag_groups",
              },
              ui: {
                control: :combo_box,
                dynamic_value: :tag_group_id,
              },
              control_options: {
                value_property: "id",
                name_property: "name",
                filterable: true,
                none: "discourse_workflows.tag_group.tag_group_id_placeholder",
              },
            },
            tag_names: {
              type: :string,
              required: true,
              ui: {
                control: :tags,
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

        def self.load_options_context(context)
          case context.method_name
          when "tag_groups"
            ::TagGroup
              .order(:name)
              .pluck(:id, :name)
              .select { |_, name| context.matches_filter?(name) }
              .map { |id, name| { id:, name: } }
          end
        end

        def execute(exec_ctx)
          items =
            exec_ctx.input_items.map.with_index do |_item, item_index|
              config = {
                "operation" => exec_ctx.get_node_parameter("operation", item_index, default: "add"),
                "tag_group_id" => exec_ctx.get_node_parameter("tag_group_id", item_index),
                "tag_names" => exec_ctx.get_node_parameter("tag_names", item_index),
              }

              wrap(process(exec_ctx, config, item_index))
            end

          [items]
        end

        private

        def process(exec_ctx, config, item_index)
          tag_group = ::TagGroup.find(config["tag_group_id"])
          actor = exec_ctx.actor_from_parameter("actor_username", item_index)
          actor.guardian.ensure_can_admin_tag_groups!
          requested_tag_names = normalized_tag_names(config["tag_names"])

          result = nil
          ::TagGroup.transaction do
            tag_group.lock!
            before_tag_names = tag_group.base_tags.order(:name).pluck(:name)
            before_data = serialized_tag_group(tag_group)
            desired_tags = desired_tags_for(tag_group, requested_tag_names, config["operation"])

            if desired_tags.map(&:name).sort != before_tag_names
              tag_group.tag_ids = desired_tags.map(&:id)
              tag_group.save!
              tag_group.reload

              after_data = serialized_tag_group(tag_group)
              StaffActionLogger.new(actor).log_tag_group_change(
                tag_group.name,
                before_data,
                after_data,
              )
            end

            result = output_for(tag_group)
          end

          result
        rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => error
          errors = error.record&.errors&.full_messages&.presence&.join(", ") || error.message
          raise_node_error!(
            I18n.t("discourse_workflows.errors.tag_group.operation_failed", errors: errors),
          )
        end

        def normalized_tag_names(value)
          names = normalize_tag_names(value)
          if names.empty?
            raise_node_error!(I18n.t("discourse_workflows.errors.tag_group.no_tag_names"))
          end

          names.each do |name|
            next if ::Tag.find_by_name(name)

            cleaned_name = DiscourseTagging.clean_tag(name)
            next if ::Tag.find_by_name(cleaned_name)

            validate_new_tag_name!(cleaned_name)
          end

          normalized_names =
            DiscourseTagging.tags_for_saving(
              names,
              Guardian.new(Discourse.system_user),
              unlimited: true,
            )

          if normalized_names.blank?
            raise_node_error!(I18n.t("discourse_workflows.errors.tag_group.no_valid_tag_names"))
          end

          normalized_names.uniq
        end

        def validate_new_tag_name!(name)
          tag = ::Tag.new(name: name)
          return if tag.valid?

          raise_node_error!(
            I18n.t(
              "discourse_workflows.errors.tag_group.operation_failed",
              errors: tag.errors.full_messages.join(", "),
            ),
          )
        end

        def desired_tags_for(tag_group, requested_tag_names, operation)
          if OPERATIONS.exclude?(operation)
            raise_node_error!(
              I18n.t("discourse_workflows.errors.unknown_operation", operation: operation),
            )
          end

          current_tags = tag_group.base_tags.to_a
          requested_tags = resolve_tags(requested_tag_names, create: operation == "add")

          tags =
            operation == "remove" ? current_tags - requested_tags : current_tags | requested_tags
          tags.reject { |tag| tag.id == tag_group.parent_tag_id }.sort_by(&:name)
        end

        def resolve_tags(tag_names, create:)
          tag_names
            .filter_map do |name|
              tag = ::Tag.find_by_name(name)
              tag ||= ::Tag.create!(name: name) if create
              tag&.target_tag || tag
            end
            .uniq
        end

        def serialized_tag_group(tag_group)
          ::TagGroupSerializer.new(tag_group).to_json(root: false)
        end

        def output_for(tag_group)
          {
            tag_group_id: tag_group.id,
            tag_group_name: tag_group.name,
            tag_names: tag_group.base_tags.order(:name).pluck(:name),
          }
        end
      end
    end
  end
end
