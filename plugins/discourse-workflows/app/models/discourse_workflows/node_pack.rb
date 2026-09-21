# frozen_string_literal: true

module DiscourseWorkflows
  class NodePack < ActiveRecord::Base
    self.table_name = "discourse_workflows_node_packs"

    has_many :definitions,
             class_name: "DiscourseWorkflows::NodePackDefinition",
             foreign_key: :node_pack_id,
             inverse_of: :node_pack
    belongs_to :installed_by, class_name: "User", optional: true
    belongs_to :updated_by, class_name: "User", optional: true

    scope :installed, -> { where(removed_at: nil) }
    scope :enabled, -> { installed.where(enabled: true) }

    validates :key, presence: true, length: { maximum: 32 }, uniqueness: true
    validates :name, presence: true, length: { maximum: 60 }
    validates :version, presence: true, length: { maximum: 32 }
    validates :manifest_sha256, presence: true, length: { is: 64 }
    validates :manifest, :approved_destinations, presence: true
  end
end

# == Schema Information
#
# Table name: discourse_workflows_node_packs
#
#  id                    :bigint           not null, primary key
#  approved_destinations :jsonb            not null
#  enabled               :boolean          default(TRUE), not null
#  key                   :string(32)       not null
#  manifest              :jsonb            not null
#  manifest_sha256       :string(64)       not null
#  name                  :string(60)       not null
#  palette_visible       :boolean          default(TRUE), not null
#  removed_at            :datetime
#  version               :string(32)       not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  installed_by_id       :integer          not null
#  updated_by_id         :integer
#
# Indexes
#
#  index_discourse_workflows_node_packs_on_key  (key) UNIQUE
#
