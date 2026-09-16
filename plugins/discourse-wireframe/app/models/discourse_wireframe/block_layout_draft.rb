# frozen_string_literal: true

module DiscourseWireframe
  # A per-user, never-live draft of a single block-layout outlet. Edit-driven
  # tooling saves these privately; publishing (the core `Themes::SaveBlockLayout`
  # service) promotes a draft to the live `block_layout` ThemeField. Unlike a
  # baked ThemeField, draft `data` is stored verbatim and is NOT validated/baked
  # — it may hold an invalid mid-edit layout.
  class BlockLayoutDraft < ActiveRecord::Base
    self.table_name = "wireframe_block_layout_drafts"

    # Matches the live publish cap (`Themes::SaveBlockLayout` layout_json size).
    MAX_DATA_BYTES = 1024**2

    belongs_to :user
    belongs_to :theme

    has_many :upload_references, as: :target, dependent: :destroy

    validates :outlet, presence: true, format: { with: /\A[a-z0-9_:\-]+\z/ }
    validates :data, presence: true, length: { maximum: MAX_DATA_BYTES }

    # Claim the uploads embedded in this draft's layout JSON so the orphaned
    # upload cleanup job spares them while the draft is unpublished. Gated on a
    # `data` change to skip metadata-only updates; `sync!` reconciles (prunes
    # removed images, adds new ones) on every change.
    after_save { BlockLayoutUploads.sync!(target: self, value: data) if saved_change_to_data? }
  end
end

# == Schema Information
#
# Table name: wireframe_block_layout_drafts
#
#  id                 :bigint           not null, primary key
#  base_version_token :string
#  data               :text             not null
#  outlet             :string           not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  theme_id           :integer          not null
#  user_id            :integer          not null
#
# Indexes
#
#  idx_wireframe_block_layout_drafts_unique                    (user_id,theme_id,outlet) UNIQUE
#  index_wireframe_block_layout_drafts_on_theme_id_and_outlet  (theme_id,outlet)
#
