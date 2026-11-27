# frozen_string_literal: true

require_relative "../../../../script/bulk_import/discourse_merger/support"

RSpec.describe BulkImport::DiscourseMerge::ReviewedRevisionUploads do
  let(:path) { "/uploads/default/original/1X/1234.gif" }
  let(:short) { "upload://REPLACE_ME.jpeg" }
  let(:avatar) { "/user_avatar/source.example/member/40/53_2.png" }
  let(:text) { "![image](#{path}) #{short} #{avatar} @before" }
  let(:entry) do
    {
      "source_revision_id" => 12,
      "urls" => [short, path, avatar],
      "modifications_sha256" => Digest::SHA256.hexdigest(text),
    }
  end

  it "pins the original serialized revision and associates its post and topic" do
    db = instance_double("PG::Connection")
    source = { "post_id" => "6", "topic_id" => "4", "modifications" => text }
    allow(db).to receive(:exec_params).with(a_kind_of(String), [12]).and_return([source])
    expect(described_class.capture(db, [entry])).to eq(
      [entry.merge("source_post_id" => 6, "source_topic_id" => 4, "urls" => entry["urls"].sort)],
    )
    expect { described_class.capture(db, [entry, entry]) }.to raise_error(/unique/)
    expect { described_class.capture(db, [entry.merge("urls" => ["@before"])]) }.to raise_error(
      /exact media URLs/,
    )
    source["modifications"] += " changed"
    expect { described_class.capture(db, [entry]) }.to raise_error(/contents changed/)
  end

  it "preserves exact URLs inside reviewed revisions and remaps the rest of the edit" do
    refs =
      BulkImport::DiscourseMerge::References.new(
        source_host: "source.example",
        destination_host: "destination.example",
        topics: {
        },
        categories: {
        },
        usernames: {
          "before" => "after",
        },
        upload_mode: "preuploaded",
        verify_media: true,
        preserved_broken_revision_uploads: [entry],
      )
    mods = { "raw" => ["untouched", text], "user_id" => [5, nil] }
    result =
      refs.revision(
        mods,
        { users: { 5 => 9 } },
        source_revision_id: 12,
        excluded_groups: {
        },
        namespace: "test",
      )
    expect(result).to eq(
      { "raw" => ["untouched", text.sub("@before", "@after")], "user_id" => [9, nil] },
    )
    expect { refs.rewrite(path, source_revision_id: 13) }.to raise_error(/local upload path/)
    expect { refs.rewrite(path, source_post_id: 12) }.to raise_error(/local upload path/)
    expect { refs.rewrite("#{path}-other", source_revision_id: 12) }.to raise_error(
      /local upload path/,
    )
    expect { refs.rewrite("#{short} #{path}x", source_revision_id: 12) }.to raise_error(
      /local upload path/,
    )
    expect(refs.rewrite("`#{path} @before` @before", source_revision_id: 12)).to eq(
      "`#{path} @before` @after",
    )
  end
end
