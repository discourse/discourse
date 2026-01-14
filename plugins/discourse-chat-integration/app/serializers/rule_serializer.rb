# frozen_string_literal: true

class DiscourseChatIntegration::RuleSerializer < ApplicationSerializer
  attributes :id, :channel_id, :type, :group_id, :group_name, :category_id, :tags, :filter

  def group_name
    if object.group_id
      if group = Group.find_by(id: object.group_id)
        group.name
      else
        I18n.t("chat_integration.deleted_group")
      end
    end
  end
end
