# frozen_string_literal: true

require Rails.root.join("db/migrate/20230728055813_delete_orphaned_draft_upload_references.rb")

RSpec.describe DeleteOrphanedDraftUploadReferences do
  subject(:migration) { described_class.new }

  describe "#up" do
    let(:user) { Fabricate(:user) }
    let(:draft) { Draft.create!(user: user, draft_key: "foo", data: "") }
    let(:nonexistent_draft_id) { 31_337 }

    let!(:upload_reference_with_existing_draft) do
      UploadReference.create!(target: draft, upload_id: 1)
    end

    let!(:upload_reference_with_deleted_draft) do
      UploadReference.create!(target_type: "Draft", target_id: nonexistent_draft_id, upload_id: 2)
    end

    let!(:upload_reference_with_other_target) do
      UploadReference.create!(target_type: "UserAvatar", target_id: 1, upload_id: 3)
    end

    it "deletes only orphaned draft upload references" do
      expect { migration.up }.to change { UploadReference.pluck(:upload_id) }.from([1, 2, 3]).to(
        [1, 3],
      )
    end
  end
end
