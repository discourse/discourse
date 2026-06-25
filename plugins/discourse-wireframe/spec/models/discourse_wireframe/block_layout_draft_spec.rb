# frozen_string_literal: true

RSpec.describe DiscourseWireframe::BlockLayoutDraft do
  fab!(:user)
  fab!(:theme)

  it "validates presence of outlet and data and the outlet format" do
    expect(described_class.new(user:, theme:, outlet: "homepage-blocks", data: "{}")).to be_valid
    expect(described_class.new(user:, theme:, outlet: "", data: "{}")).not_to be_valid
    expect(described_class.new(user:, theme:, outlet: "Bad Name!", data: "{}")).not_to be_valid
    expect(described_class.new(user:, theme:, outlet: "homepage-blocks", data: "")).not_to be_valid
  end

  it "accepts a namespaced outlet name" do
    expect(described_class.new(user:, theme:, outlet: "chat:thread-blocks", data: "{}")).to be_valid
  end

  it "caps data at MAX_DATA_BYTES" do
    expect(
      described_class.new(
        user:,
        theme:,
        outlet: "homepage-blocks",
        data: "x" * (described_class::MAX_DATA_BYTES + 1),
      ),
    ).not_to be_valid
  end

  it "enforces uniqueness per (user, theme, outlet) at the database" do
    described_class.create!(user:, theme:, outlet: "homepage-blocks", data: "{}")

    expect {
      described_class.create!(user:, theme:, outlet: "homepage-blocks", data: "{}")
    }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  describe "upload references" do
    fab!(:upload_a, :upload)
    fab!(:upload_b, :upload)

    def image_arg(upload, **extras)
      { "source" => "upload", "upload_id" => upload.id, "url" => upload.url, **extras }
    end

    def layout_json(layout)
      { "schema_version" => 1, "layout" => layout }.to_json
    end

    def save_draft(layout)
      draft = described_class.find_or_initialize_by(user:, theme:, outlet: "homepage-blocks")
      draft.update!(data: layout_json(layout))
      draft
    end

    it "claims an UploadReference for each embedded upload so the cleanup job spares it" do
      draft = save_draft([{ "args" => { "image" => image_arg(upload_a) } }])

      expect(draft.upload_references.pluck(:upload_id)).to contain_exactly(upload_a.id)
      expect(draft.upload_references.first.target_type).to eq(
        "DiscourseWireframe::BlockLayoutDraft",
      )
    end

    it "prunes the reference when the image is removed from the draft" do
      draft = save_draft([{ "args" => { "image" => image_arg(upload_a) } }])
      expect(draft.upload_references.pluck(:upload_id)).to eq([upload_a.id])

      save_draft([{ "block" => "wf:text", "args" => { "title" => "hi" } }])

      expect(draft.reload.upload_references).to be_empty
    end

    it "swings the reference when the image is replaced" do
      save_draft([{ "args" => { "image" => image_arg(upload_a) } }])
      draft = save_draft([{ "args" => { "image" => image_arg(upload_b) } }])

      expect(draft.upload_references.pluck(:upload_id)).to contain_exactly(upload_b.id)
    end

    it "skips client-supplied upload_ids that don't exist" do
      ghost_id = (Upload.maximum(:id) || 0) + 9999
      draft =
        save_draft([{ "args" => { "image" => { "source" => "upload", "upload_id" => ghost_id } } }])

      expect(draft.upload_references).to be_empty
    end

    it "destroys its UploadReferences when the draft is destroyed" do
      draft = save_draft([{ "args" => { "image" => image_arg(upload_a) } }])
      ref_ids = draft.upload_references.pluck(:id)
      expect(ref_ids).not_to be_empty

      draft.destroy!

      expect(UploadReference.where(id: ref_ids)).to be_empty
    end
  end
end
