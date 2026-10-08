# frozen_string_literal: true

module DiscourseWireframe
  module PluginSetup
    # Cascade-clean a user's or theme's private layout drafts when the owner is
    # destroyed, so their claimed uploads stop being protected and become
    # collectable again. `destroy_all` fires each draft's `dependent: :destroy`
    # to prune its UploadReferences. These hooks only run while the plugin is
    # enabled; the scheduled `CleanUpOrphanedBlockLayoutDrafts` job catches
    # anything deleted while it was disabled.
    module DraftCleanup
      def self.apply(plugin)
        plugin.on(:user_destroyed) do |user|
          DiscourseWireframe::BlockLayoutDraft.where(user_id: user.id).destroy_all
        end

        plugin.on(:theme_destroyed) do |theme|
          DiscourseWireframe::BlockLayoutDraft.where(theme_id: theme.id).destroy_all
        end
      end
    end
  end
end
