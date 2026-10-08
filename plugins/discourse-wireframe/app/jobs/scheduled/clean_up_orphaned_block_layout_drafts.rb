# frozen_string_literal: true

module Jobs
  # Reclaims private layout drafts whose owning user or theme no longer exists.
  # The `on(:user_destroyed)`/`on(:theme_destroyed)` hooks handle this inline,
  # but they only run while the plugin is enabled; this sweep is the backstop
  # for anything deleted while it was disabled. `destroy_all` fires each draft's
  # `dependent: :destroy` so its claimed uploads become collectable again.
  class CleanUpOrphanedBlockLayoutDrafts < ::Jobs::Scheduled
    every 1.day

    def execute(_args)
      return unless SiteSetting.wireframe_enabled

      DiscourseWireframe::BlockLayoutDraft.where.missing(:user).destroy_all
      DiscourseWireframe::BlockLayoutDraft.where.missing(:theme).destroy_all
    end
  end
end
