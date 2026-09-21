# frozen_string_literal: true

module DiscourseWorkflows
  class NodePackDefinition < ActiveRecord::Base
    self.table_name = "discourse_workflows_node_pack_definitions"

    belongs_to :node_pack, class_name: "DiscourseWorkflows::NodePack", inverse_of: :definitions

    scope :active, -> { where(retired_at: nil) }

    validates :identifier, presence: true, length: { maximum: 100 }
    validates :version, presence: true, length: { maximum: 16 }
    validates :definition_sha256, presence: true, length: { is: 64 }
    validates :introduced_in, presence: true, length: { maximum: 32 }
    validates :identifier, uniqueness: { scope: :version }
  end
end

# == Schema Information
#
# Table name: discourse_workflows_node_pack_definitions
#
#  id                :bigint           not null, primary key
#  definition        :jsonb            not null
#  definition_sha256 :string(64)       not null
#  identifier        :string(100)      not null
#  introduced_in     :string(32)       not null
#  retired_at        :datetime
#  version           :string(16)       not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  node_pack_id      :bigint           not null
#
# Indexes
#
#  idx_on_node_pack_id_2efbcacff5               (node_pack_id)
#  idx_workflow_node_pack_definitions_identity  (identifier,version) UNIQUE
#
