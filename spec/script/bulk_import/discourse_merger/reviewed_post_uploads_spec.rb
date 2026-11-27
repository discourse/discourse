# frozen_string_literal: true

require_relative "../../../../script/bulk_import/discourse_merger/support"

RSpec.describe BulkImport::DiscourseMerge::ReviewedPostUploads do
  let(:url) { "upload://missing-example.jpg" }
  let(:post) do
    { "topic_id" => "7", "raw" => "![Banner](#{url})", "cooked" => %(<img data-orig-src="#{url}">) }
  end
  let(:entry) do
    {
      "source_post_id" => 12,
      "url" => url,
      "raw_sha256" => Digest::SHA256.hexdigest(post.fetch("raw")),
      "cooked_sha256" => Digest::SHA256.hexdigest(post.fetch("cooked")),
    }
  end

  it "binds the exception to the reviewed source text and topic" do
    settings = {
      "source" => {
        "dbname" => "incoming",
      },
      "destination" => {
        "dbname" => "review",
      },
      "source_url" => "https://source.example",
      "destination_url" => "https://destination.example",
      "upload_mode" => "preuploaded",
      "preserved_broken_post_uploads" => [entry],
    }
    config = BulkImport::DiscourseMerge::Configuration.new(".", contents: settings.to_yaml)
    approved = config.data.fetch("preserved_broken_post_uploads")
    db = instance_double("PG::Connection")
    allow(db).to receive(:exec_params).with(a_kind_of(String), [12]).and_return([post])
    expect(described_class.capture(db, approved)).to eq([entry.merge("source_topic_id" => 7)])
    post["raw"] = "Changed"
    expect { described_class.capture(db, approved) }.to raise_error(/contents changed/)
  end

  it "preserves only the exact URL in the specified post and checks adjacent references" do
    uploads = class_double("Upload").as_stubbed_const
    relation = instance_double("ActiveRecord::Relation", pluck: [])
    filters = instance_double("ActiveRecord::QueryMethods::WhereChain", not: relation)
    allow(uploads).to receive(:unscoped).and_return(uploads)
    allow(uploads).to receive(:where).and_return(filters)
    allow(uploads).to receive(:sha1_from_base62_encoded).and_return("0" * 40)
    refs =
      BulkImport::DiscourseMerge::References.new(
        source_host: "source.example",
        destination_host: "destination.example",
        topics: {
        },
        categories: {
        },
        verify_media: true,
        preserved_broken_post_uploads: [entry],
      )
    expect(refs.rewrite(post["raw"], source_post_id: 12)).to eq(post["raw"])
    expect(refs.rewrite(post["cooked"], cooked: true, source_post_id: 12)).to eq(post["cooked"])
    expect { refs.rewrite(post["raw"], source_post_id: 13) }.to raise_error(
      /Unresolved native upload/,
    )
    expect {
      refs.rewrite(post["raw"].sub(".jpg", ".jpg-other"), source_post_id: 12)
    }.to raise_error(/Unresolved native upload/)
    expect {
      refs.rewrite(post["raw"] + " ![Other](upload://other.jpg)", source_post_id: 12)
    }.to raise_error(/Unresolved native upload/)
  end
end
