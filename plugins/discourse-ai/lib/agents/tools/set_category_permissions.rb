# frozen_string_literal: true

module DiscourseAi
  module Agents
    module Tools
      class SetCategoryPermissions < Tool
        FEATURE = :category_permissions

        # Parameter name for each permission level, from most to least access.
        LEVEL_PARAMS = {
          full: :create_reply_see_groups,
          create_post: :reply_see_groups,
          readonly: :see_groups,
        }.freeze

        MAX_SUGGESTED_GROUPS = 50

        def self.signature
          {
            name: name,
            description:
              "Replaces who can access a category. List every group that should keep access, because groups left out lose it. Use `everyone` for all users, `staff` for admins and moderators, or `trust_level_0` to `trust_level_4` for trust levels. Making a category private means leaving out `everyone`. Administrators can always see every category.",
            parameters: [
              {
                name: "category_id",
                description: "The ID of the category",
                type: "integer",
                required: true,
              },
              {
                name: "create_reply_see_groups",
                description: "Names of groups that can create topics, reply, and see the category",
                type: "array",
                item_type: "string",
              },
              {
                name: "reply_see_groups",
                description:
                  "Names of groups that can reply and see the category, but not create topics",
                type: "array",
                item_type: "string",
              },
              {
                name: "see_groups",
                description: "Names of groups that can only see the category",
                type: "array",
                item_type: "string",
              },
              {
                name: "reason",
                description: "Short explanation of why the permissions are being changed",
                type: "string",
                required: true,
              },
            ],
          }
        end

        def self.name
          "set_category_permissions"
        end

        def self.requires_approval?
          true
        end

        def self.attribute_to_approver?
          true
        end

        def invoke
          if (error = validation_error)
            return error
          end
          perform_update
        end

        def validation_error
          access =
            AdminAssistantAccess.check(feature: FEATURE, user: context.user, phase: execution_phase)
          if !access.allowed
            return(
              error_response(
                access.message.presence ||
                  I18n.t("discourse_ai.ai_bot.set_category_permissions.errors.unavailable"),
              )
            )
          end

          if category.blank? || !guardian.can_see_category?(category)
            return(
              error_response(
                I18n.t("discourse_ai.ai_bot.set_category_permissions.errors.not_found"),
              )
            )
          end

          if !guardian.can_edit_category?(category)
            return(
              error_response(
                I18n.t("discourse_ai.ai_bot.set_category_permissions.errors.not_allowed"),
              )
            )
          end

          if category.uncategorized?
            return(
              error_response(
                I18n.t("discourse_ai.ai_bot.set_category_permissions.errors.uncategorized"),
              )
            )
          end

          if reason.blank?
            return(
              error_response(
                I18n.t("discourse_ai.ai_bot.set_category_permissions.errors.no_reason"),
              )
            )
          end

          if requested_group_names.empty?
            return(
              error_response(
                I18n.t("discourse_ai.ai_bot.set_category_permissions.errors.no_groups"),
              )
            )
          end

          if (duplicates = duplicate_group_names).present?
            return(
              error_response(
                I18n.t(
                  "discourse_ai.ai_bot.set_category_permissions.errors.duplicate_groups",
                  groups: duplicates.join(", "),
                ),
              )
            )
          end

          if (missing = missing_group_names).present?
            return(
              error_response(
                I18n.t(
                  "discourse_ai.ai_bot.set_category_permissions.errors.unknown_groups",
                  groups: missing.join(", "),
                  available: suggested_group_names.join(", "),
                ),
              )
            )
          end

          if !changed?
            return(
              error_response(
                I18n.t("discourse_ai.ai_bot.set_category_permissions.errors.unchanged"),
              )
            )
          end

          # Runs the model validations, such as subcategory compatibility and
          # seeded category rules, so an invalid request is rejected before it
          # is queued for approval.
          candidate = Category.find(category.id)
          candidate.permissions = permissions
          return error_response(candidate.errors.full_messages.to_sentence) if !candidate.valid?

          nil
        end

        def description_args
          {
            category_name:
              (
                if category
                  DiscourseAi::AiBot::ChatToolApproval.format_category(category)
                else
                  parameters[:category_id]
                end
              ),
          }
        end

        def approval_title
          return super if !previewable?(category)

          I18n.t(
            "discourse_ai.ai_bot.chat_tool_approval.category_title",
            category: DiscourseAi::AiBot::ChatToolApproval.format_category(category),
          )
        end

        def approval_changes
          return [] if !previewable_change?

          access_changes.map do |group, before, after|
            {
              label:
                I18n.t(
                  "discourse_ai.ai_bot.chat_tool_approval.category_group_access_label",
                  group:,
                ),
              before: access_level_label(before),
              after: access_level_label(after),
            }
          end
        end

        def approval_details
          return super if !previewable_change?

          details =
            access_changes.map do |group, before, after|
              I18n.t(
                "discourse_ai.ai_bot.chat_tool_approval.category_group_access_change",
                group:,
                before: access_level_label(before),
                after: access_level_label(after),
              )
            end
          if becomes_private?
            details << I18n.t("discourse_ai.ai_bot.chat_tool_approval.category_becomes_private")
          end
          details.join("\n\n")
        end

        def approval_question
          if previewable_change? && becomes_private?
            return(I18n.t("discourse_ai.ai_bot.chat_tool_approval.category_make_private_question"))
          end

          I18n.t("discourse_ai.ai_bot.chat_tool_approval.category_permissions_question")
        end

        def approval_parameters
          []
        end

        private

        def category
          @category ||= Category.find_by(id: parameters[:category_id])
        end

        def previewable_change?
          previewable?(category) && requested_group_names.present? && missing_group_names.empty?
        end

        # [group name, permission type before, permission type after] for each
        # group whose access changes, with nil meaning no access.
        def access_changes
          @access_changes ||=
            begin
              before =
                effective_access(current_permissions, read_restricted: category.read_restricted)
              after = effective_access(new_permissions, read_restricted: new_read_restricted)
              names = Group.where(id: before.keys | after.keys).pluck(:id, :name).to_h

              (after.keys | before.keys).filter_map do |group_id|
                next if before[group_id] == after[group_id]
                [names[group_id] || group_id.to_s, before[group_id], after[group_id]]
              end
            end
        end

        def execution_phase
          context.reviewable_id.present? ? :approval : :request
        end

        def requested_groups
          @requested_groups ||=
            LEVEL_PARAMS.flat_map do |level, param|
              Array(parameters[param]).filter_map do |name|
                name = name.to_s.strip.delete_prefix("@")
                [name, level] if name.present?
              end
            end
        end

        def requested_group_names
          requested_groups.map(&:first)
        end

        def duplicate_group_names
          requested_group_names.group_by(&:downcase).select { |_, names| names.size > 1 }.keys
        end

        # Groups the user could pick in the category form, so a moderator
        # managing categories can't use or discover groups hidden from them.
        def selectable_groups
          Group.visible_groups(guardian.user, "groups.name ASC", include_everyone: true)
        end

        # Groups that can be kept or granted: the selectable ones, plus any the
        # category already includes, which the category form lists too.
        def assignable_groups
          current_group_ids = category ? category.category_groups.select(:group_id) : []
          Group.where(id: selectable_groups.select(:id)).or(Group.where(id: current_group_ids))
        end

        def group_ids_by_name
          @group_ids_by_name ||=
            assignable_groups
              .where("LOWER(name) IN (?)", requested_group_names.map(&:downcase))
              .pluck(:name, :id)
              .to_h { |name, id| [name.downcase, [name, id]] }
        end

        def missing_group_names
          requested_group_names.reject { |name| group_ids_by_name.key?(name.downcase) }
        end

        def suggested_group_names
          selectable_groups.limit(MAX_SUGGESTED_GROUPS).pluck(:name)
        end

        # { "group_name" => permission_type }, keyed by name like the category
        # form so the staff action log records it the same way.
        def permissions
          @permissions ||=
            requested_groups.to_h do |name, level|
              [group_ids_by_name[name.downcase].first, CategoryGroup.permission_types[level]]
            end
        end

        def new_permissions
          Category.resolve_permissions(permissions).last
        end

        def current_permissions
          category.category_groups.pluck(:group_id, :permission_type)
        end

        def new_read_restricted
          Category.resolve_permissions(permissions).first
        end

        def changed?
          new_read_restricted != category.read_restricted ||
            new_permissions.sort != current_permissions.sort
        end

        def becomes_private?
          !category.read_restricted && new_read_restricted
        end

        # { group_id => permission_type } as the category form shows it: a
        # category without group permissions is open to everyone, unless it is
        # restricted, in which case only administrators can see it.
        def effective_access(pairs, read_restricted:)
          if pairs.empty? && !read_restricted
            return { Group::AUTO_GROUPS[:everyone] => CategoryGroup.permission_types[:full] }
          end

          pairs.to_h
        end

        def access_level_label(permission_type)
          level = CategoryGroup.permission_types.key(permission_type) || :none
          I18n.t("discourse_ai.ai_bot.chat_tool_approval.category_access_levels.#{level}")
        end

        def perform_update
          old_permissions = category.permissions_params
          if old_permissions.empty?
            old_permissions = { Group[:everyone].name => CategoryGroup.permission_types[:full] }
          end

          if CategoryUpdater.update(guardian, category, { permissions: }, old_permissions:)
            {
              status: "success",
              message:
                I18n.t("discourse_ai.ai_bot.set_category_permissions.success", name: category.name),
            }
          else
            error_response(category.errors.full_messages.to_sentence)
          end
        rescue Discourse::InvalidAccess
          error_response(I18n.t("discourse_ai.ai_bot.set_category_permissions.errors.not_allowed"))
        end
      end
    end
  end
end
