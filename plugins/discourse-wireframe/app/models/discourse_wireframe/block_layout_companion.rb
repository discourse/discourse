# frozen_string_literal: true

module DiscourseWireframe
  # Records that a local theme component is a block-layout "design" of a parent
  # theme. The editor always publishes to a design rather than to the parent
  # itself, so the parent stays untouched. A parent can have several designs but
  # only one is installed (a live child of the parent) at a time; the mapping lets
  # the editor list the others and switch between them, even after a component is
  # renamed or while it is still empty.
  #
  # The mapping is editor metadata, so it lives here in the plugin rather than on
  # the core `themes` table.
  class BlockLayoutCompanion < ActiveRecord::Base
    self.table_name = "wireframe_block_layout_companions"

    belongs_to :parent_theme, class_name: "Theme"
    belongs_to :component_theme, class_name: "Theme"

    validates :parent_theme_id, presence: true
    validates :component_theme_id, presence: true, uniqueness: true

    # The parent's designs, newest first, with whether each is the installed one.
    #
    # @param parent_theme_id [Integer]
    # @return [Array<Hash>] `{ id:, name:, active: }` per design.
    def self.designs_for(parent_theme_id)
      installed_id = companion_id_for(parent_theme_id)
      where(parent_theme_id: parent_theme_id)
        .includes(:component_theme)
        .order(id: :desc)
        .filter_map do |mapping|
          component = mapping.component_theme
          next if component.nil?
          { id: component.id, name: component.name, active: component.id == installed_id }
        end
    end

    # Every design across all themes, newest first, for the admin designs list.
    #
    # @return [Array<Hash>] `{ id:, name:, theme_id:, theme_name:, active:, updated_at: }`.
    def self.all_designs
      mappings = includes(:parent_theme, :component_theme).order(id: :desc).to_a
      installed =
        ChildTheme
          .where(
            parent_theme_id: mappings.map(&:parent_theme_id),
            child_theme_id: mappings.map(&:component_theme_id),
          )
          .pluck(:parent_theme_id, :child_theme_id)
          .to_set

      mappings.filter_map do |mapping|
        design = mapping.component_theme
        theme = mapping.parent_theme
        next if design.nil? || theme.nil?
        {
          id: design.id,
          name: design.name,
          theme_id: theme.id,
          theme_name: theme.name,
          active: installed.include?([theme.id, design.id]),
          updated_at: design.updated_at,
        }
      end
    end

    # One design with its published layouts, so the editor can preview a design
    # its theme doesn't use yet.
    #
    # @param design_id [Integer]
    # @return [Hash, nil] nil when the theme isn't a design.
    def self.design_detail(design_id)
      mapping = includes(:parent_theme, :component_theme).find_by(component_theme_id: design_id)
      design = mapping&.component_theme
      return nil if design.nil? || mapping.parent_theme.nil?

      layouts =
        design
          .theme_fields
          .where(type_id: ThemeField.types[:block_layout], error: nil)
          .order(:name)
          .filter_map do |field|
            next if field.value_baked.blank?
            parsed = JSON.parse(field.value_baked)
            {
              theme_id: design.id,
              outlet: field.name,
              schema_version: parsed["schema_version"],
              layout: parsed["layout"],
              version_token: Themes::BlockLayoutVersion.token_for(field.value_baked),
            }
          rescue JSON::ParserError
            nil
          end

      {
        id: design.id,
        name: design.name,
        theme_id: mapping.parent_theme_id,
        active: mapping.parent_theme.child_theme_ids.include?(design.id),
        layouts: layouts,
      }
    end

    # Unlinks every mapped design from the parent, leaving the components intact.
    #
    # @param parent [Theme]
    def self.uninstall_all(parent)
      ids = where(parent_theme_id: parent.id).pluck(:component_theme_id)
      return if ids.empty?
      ChildTheme.where(parent_theme_id: parent.id, child_theme_id: ids).destroy_all
      parent.child_themes.reload
      Theme.clear_cache!
    end

    # Installs one of the parent's designs and unlinks the others.
    #
    # @param parent [Theme]
    # @param component_theme_id [Integer]
    # @return [Boolean] false when the component is not a design of the parent.
    def self.install(parent, component_theme_id)
      return false if !exists?(parent_theme_id: parent.id, component_theme_id: component_theme_id)

      transaction do
        uninstall_all(parent)
        parent.add_relative_theme!(:child, Theme.find(component_theme_id))
      end
      true
    end

    # The id of a parent theme's installed design, or nil when none.
    #
    # The stored mapping survives renaming or emptying the component, but it is
    # only honoured while the component is STILL a live child of the parent: once
    # the component is unlinked it leaves the parent's `transform_ids` stack (its
    # layouts stop rendering), so it is no longer the installed design. A mapping
    # pointing at a deleted component is likewise ignored.
    #
    # @param parent_theme_id [Integer]
    # @return [Integer, nil]
    def self.companion_id_for(parent_theme_id)
      parent = Theme.find_by(id: parent_theme_id)
      return nil if parent.nil?

      mapped_ids =
        where(parent_theme_id: parent_theme_id).order(id: :desc).pluck(:component_theme_id)
      (mapped_ids & parent.child_theme_ids).first
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
