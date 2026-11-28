# frozen_string_literal: true

RSpec.describe Migrations::Importer::Uploads::InlineWorkList do
  include_context "with mapped intermediate db"

  let(:mapping_type) { Migrations::Importer::MappingType }
  let(:system_user_id) { -1 }

  def add_source(id:, user_id: nil, url: nil, data: nil)
    db.execute(
      "INSERT INTO upload_sources (id, filename, user_id, type, url, data) VALUES (?, ?, ?, ?, ?, ?)",
      id,
      "#{id}.png",
      user_id,
      mapping_type::UPLOADS,
      url,
      data && Migrations::Database.to_blob(data),
    )
  end

  def map_id(original_id:, type:, discourse_id:)
    db.execute(
      "INSERT INTO mapped.ids (original_id, type, discourse_id) VALUES (?, ?, ?)",
      original_id,
      type,
      discourse_id,
    )
  end

  it "resolves the owning user from the users map and falls back to the system user" do
    add_source(id: "a", user_id: "orig-7")
    add_source(id: "b", user_id: "unmapped")
    map_id(original_id: "orig-7", type: mapping_type::USERS, discourse_id: 42)

    rows = described_class.rows(db, system_user_id:)

    expect(rows.map { |r| r.values_at(:id, :resolved_user_id) }).to eq(
      [["a", 42], ["b", system_user_id]],
    )
  end

  it "excludes sources already mapped as uploads on a re-run" do
    add_source(id: "a")
    add_source(id: "b")
    map_id(original_id: "a", type: mapping_type::UPLOADS, discourse_id: 100)

    rows = described_class.rows(db, system_user_id:)

    expect(rows.map { |r| r[:id] }).to eq(["b"])
  end

  describe ".needs_root_paths?" do
    def needs_root_paths?
      described_class.needs_root_paths?(described_class.rows(db, system_user_id:))
    end

    it "is false when every pending row has a url or a data blob" do
      add_source(id: "a", url: "https://example.com/a.png")
      add_source(id: "b", data: "bytes")

      expect(needs_root_paths?).to be(false)
    end

    it "is true when a pending row has to be read from disk" do
      add_source(id: "a", url: "https://example.com/a.png")
      add_source(id: "b")

      expect(needs_root_paths?).to be(true)
    end
  end
end
