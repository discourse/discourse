# frozen_string_literal: true

module DiscourseWireframe
  # Records that a local theme component is the block-layout "companion" of a
  # parent theme that can't be published to directly (a core system theme or a
  # Git theme). The block-layout editor publishes the parent's overrides to this
  # component; the mapping lets the editor recognize it again on re-entry — even
  # after the component is renamed or while it is still empty — without re-running
  # the "set up a companion" flow.
  #
  # The mapping is editor metadata, so it lives here in the plugin rather than on
  # the core `themes` table.
  class BlockLayoutCompanion < ActiveRecord::Base
    self.table_name = "wireframe_block_layout_companions"

    belongs_to :parent_theme, class_name: "Theme"
    belongs_to :component_theme, class_name: "Theme"

    validates :parent_theme_id, presence: true
    validates :component_theme_id, presence: true, uniqueness: true

    # The id of a parent theme's block-layout companion, or nil when none.
    #
    # The stored mapping survives renaming or emptying the component, but it is
    # only honoured while the component is STILL a live child of the parent: once
    # the component is unlinked it leaves the parent's `transform_ids` stack (its
    # layouts stop rendering), so it must stop being treated as the companion. A
    # mapping pointing at a deleted component is likewise ignored.
    #
    # @param parent_theme_id [Integer]
    # @return [Integer, nil]
    def self.companion_id_for(parent_theme_id)
      mapping = find_by(parent_theme_id: parent_theme_id)
      return nil if mapping.nil?

      parent = Theme.find_by(id: parent_theme_id)
      return nil if parent.nil?
      return nil if parent.child_theme_ids.exclude?(mapping.component_theme_id)

      mapping.component_theme_id
    end
  end
end

# == Schema Information
#
# Table name: wireframe_block_layout_companions
#
#  id                 :bigint           not null, primary key
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  component_theme_id :integer          not null
#  parent_theme_id    :integer          not null
#
# Indexes
#
#  index_wireframe_block_layout_companions_on_component_theme_id  (component_theme_id) UNIQUE
#  index_wireframe_block_layout_companions_on_parent_theme_id     (parent_theme_id)
#
