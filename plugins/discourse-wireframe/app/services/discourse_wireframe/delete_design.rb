# frozen_string_literal: true

module DiscourseWireframe
  # Deletes one of a theme's designs: the local component that holds its
  # block-layout overrides, its parent↔component mapping, and any drafts authors
  # saved against it. When the design was installed, the theme goes back to its
  # own layouts.
  #
  # @example
  #   DiscourseWireframe::DeleteDesign.call(
  #     guardian: guardian,
  #     params: { theme_id: parent.id, design_id: component.id },
  #   )
  class DeleteDesign
    include Service::Base

    params do
      attribute :theme_id, :integer
      attribute :design_id, :integer

      # Core system themes (Foundation, Horizon) have negative ids.
      validates :theme_id, presence: true, numericality: { only_integer: true, other_than: 0 }
      validates :design_id, presence: true
    end

    policy :current_user_is_admin
    model :mapping
    model :design

    transaction do
      step :delete_drafts
      step :destroy_design
    end

    private

    def current_user_is_admin(guardian:)
      guardian.is_admin?
    end

    def fetch_mapping(params:)
      DiscourseWireframe::BlockLayoutCompanion.find_by(
        parent_theme_id: params.theme_id,
        component_theme_id: params.design_id,
      )
    end

    def fetch_design(mapping:)
      mapping.component_theme
    end

    def delete_drafts(design:)
      DiscourseWireframe::BlockLayoutDraft.where(theme_id: design.id).delete_all
    end

    def destroy_design(mapping:, design:)
      mapping.destroy!
      design.destroy!
    end
  end
end
