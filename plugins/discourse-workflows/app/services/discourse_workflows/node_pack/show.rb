# frozen_string_literal: true

module DiscourseWorkflows
  class NodePack::Show
    include Service::Base

    params do
      attribute :node_pack_id, :integer
      validates :node_pack_id, presence: true
    end

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows
    model :node_pack

    private

    def fetch_node_pack(params:)
      NodePack.installed.includes(:definitions, :installed_by).find_by(id: params.node_pack_id)
    end
  end
end
