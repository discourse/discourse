# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module TopicTags
      class V2 < V1
        MODIFY = "modify"
        REPLACE = "replace"
        MODES = [MODIFY, REPLACE].freeze

        description(
          V1.description.merge(
            version: "2.0",
            properties: {
              mode: {
                type: :options,
                options: MODES,
                default: MODIFY,
                no_data_expression: true,
              },
              topic_id: V1.properties[:topic_id],
              add_tag_names:
                V1.properties[:tag_names].merge(display_options: { hide: { mode: [REPLACE] } }),
              remove_tag_names:
                V1.properties[:tag_names].merge(display_options: { hide: { mode: [REPLACE] } }),
              replace_tag_names:
                V1.properties[:tag_names].merge(display_options: { show: { mode: [REPLACE] } }),
              actor_username: V1.properties[:actor_username],
            },
          ),
        )

        def execute(exec_ctx)
          items =
            exec_ctx.input_items.map.with_index do |_item, item_index|
              wrap(process(exec_ctx, item_index))
            end

          [items]
        end

        private

        def process(exec_ctx, item_index)
          mode = exec_ctx.get_node_parameter("mode", item_index, default: MODIFY)
          if MODES.exclude?(mode)
            raise_node_error!(
              I18n.t("discourse_workflows.errors.topic_tags.unknown_mode", mode: mode),
            )
          end

          topic = ::Topic.find(exec_ctx.get_node_parameter("topic_id", item_index))
          tag_names, removed_names = configured_tags(exec_ctx, item_index, mode)
          actor = exec_ctx.actor_from_parameter("actor_username", item_index)
          exec_ctx.ensure_no_expression_errors!
          ensure_can_tag_personal_message!(topic, actor)

          topic.with_lock do
            desired_names =
              mode == REPLACE ? tag_names : (topic.tags.pluck(:name) - removed_names) | tag_names
            if desired_names.size > SiteSetting.max_tags_per_topic
              raise_node_error!(
                I18n.t("tags.too_many_tags_for_topic", count: SiteSetting.max_tags_per_topic),
              )
            end

            tag_topic!(topic, actor.guardian, desired_names) do |tags|
              resolved_names = tags.map(&:name)
              unexpected_names =
                mode == REPLACE ? resolved_names - desired_names : removed_names & resolved_names
              unapplied_names = (desired_names - resolved_names) | unexpected_names
              if unapplied_names.present?
                raise_node_error!(
                  I18n.t(
                    "discourse_workflows.errors.topic_tags.unapplied_tag_names",
                    tag_names: unapplied_names.sort.join(", "),
                  ),
                )
              end
            end

            { topic_id: topic.id, tag_names: topic.tags.map(&:name).sort }
          end
        end

        def configured_tags(exec_ctx, item_index, mode)
          if mode == REPLACE
            return [
              canonical_tag_names(exec_ctx.get_node_parameter("replace_tag_names", item_index)),
              []
            ]
          end

          added_names =
            canonical_tag_names(exec_ctx.get_node_parameter("add_tag_names", item_index))
          removed_names =
            canonical_tag_names(exec_ctx.get_node_parameter("remove_tag_names", item_index))
          if added_names.empty? && removed_names.empty?
            raise_node_error!(I18n.t("discourse_workflows.errors.topic_tags.no_tag_names"))
          end

          overlapping_names = added_names.map(&:downcase) & removed_names.map(&:downcase)
          if overlapping_names.present?
            raise_node_error!(
              I18n.t(
                "discourse_workflows.errors.topic_tags.overlapping_tag_names",
                tag_names: overlapping_names.sort.join(", "),
              ),
            )
          end

          [added_names, removed_names]
        end

        def canonical_tag_names(value)
          names =
            normalize_tag_names(value).to_h { |name| [name, DiscourseTagging.clean_tag(name)] }
          return [] if names.empty?

          existing_names =
            ::Tag
              .where_name(names.keys | names.values)
              .includes(:target_tag)
              .to_h { |tag| [tag.name.downcase, tag.target_tag&.name || tag.name] }

          names
            .map do |name, cleaned_name|
              canonical_name =
                existing_names[name.downcase] || existing_names[cleaned_name.downcase] ||
                  cleaned_name.presence
              if canonical_name.nil?
                raise_node_error!(
                  I18n.t(
                    "discourse_workflows.errors.topic_tags.unapplied_tag_names",
                    tag_names: name,
                  ),
                )
              end

              canonical_name
            end
            .uniq(&:downcase)
        end
      end
    end
  end
end
