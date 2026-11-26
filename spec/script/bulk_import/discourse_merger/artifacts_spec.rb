# frozen_string_literal: true

require "tmpdir"
require "pg"
require_relative "../../../../script/bulk_import/discourse_merger/configuration"
require_relative "../../../../script/bulk_import/discourse_merger/runner"
require_relative "../../../../script/bulk_import/discourse_merger/verifier"

RSpec.describe BulkImport::DiscourseMerge::Artifacts do
  it "atomically replaces an existing artifact with private permissions" do
    Dir.mktmpdir do |directory|
      path = File.join(directory, "plan.json")
      File.write(path, "old")
      File.chmod(0o644, path)
      described_class.write(path, "reviewed")
      expect(File.read(path)).to eq("reviewed")
      expect(File.stat(path).mode & 0o777).to eq(0o600)
      expect(Dir.children(directory)).to eq(["plan.json"])
    end
  end

  it "protects spreadsheet-sensitive CSV values without changing their meaning" do
    (
      %w[=HYPERLINK(1) +category -name @name 'literal plain] +
        ["\t=formula", "\r=formula", "\n=formula"]
    ).each do |value|
      encoded = described_class.csv_encode(value)
      expect(encoded.start_with?("'", "plain")).to eq(true)
      expect(described_class.csv_decode(encoded)).to eq(value)
    end
  end

  it "rejects traversal and destination symlinks before creating files" do
    Dir.mktmpdir do |directory|
      root = Pathname.new(directory)
      File.symlink("/tmp", root.join("link"))
      %w[../outside /absolute link/escape].each do |path|
        expect { described_class.upload_path(root, path, existing: false) }.to raise_error(
          BulkImport::DiscourseMerge::Error,
        )
      end
      expect(described_class.upload_path(root, "original/file", existing: false)).to eq(
        root.join("original/file"),
      )
    end
  end
end

RSpec.describe BulkImport::DiscourseMerge::Connections do
  it "rejects a destination whose advisory lock is held" do
    connection = instance_double(PG::Connection)
    result = instance_double(PG::Result, getvalue: "f")
    allow(connection).to receive(:exec).and_return(result)
    expect { described_class.lock!(connection) }.to raise_error(
      BulkImport::DiscourseMerge::Error,
      /Another importer/,
    )
  end

  it "rejects different physical destination connections" do
    connection =
      instance_double(PG::Connection, exec: instance_double(PG::Result, values: [["one"]]))
    rails = instance_double(PG::Connection, exec: instance_double(PG::Result, values: [["two"]]))
    expect { described_class.verify_destination!(connection, rails) }.to raise_error(
      BulkImport::DiscourseMerge::Error,
      /different databases.*check DISCOURSE_DB_NAME/,
    )
  end
end

RSpec.describe BulkImport::DiscourseMerge::VerificationContext do
  it "restores only explicit numeric mappings from the ledger" do
    names = %w[
      users
      groups
      categories
      topics
      posts
      uploads
      optimized_images
      topic_timers
      solved_topics
      topic_answers
      shared_issues
      post_actions
    ]
    ledger = names.to_h { |name| [name, { "1" => 2 }] }
    ledger["stage"] = "complete"
    ledger["categories"]["9"] = nil
    ledger["category_keys"] = { "source:1" => 2 }
    ledger["raw_connection"] = "untrusted extra field"
    context = described_class.new(nil, ledger)
    expect(context.maps.fetch(:users)).to eq(1 => 2)
    expect(context.maps.fetch(:categories)).to eq(1 => 2, 9 => nil)
    expect(context.category_keys).to eq("source:1" => 2)
    expect(context.maps.keys).to contain_exactly(*names.map(&:to_sym))
  end
end
