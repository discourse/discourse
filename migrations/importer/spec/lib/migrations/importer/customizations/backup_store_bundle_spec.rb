# frozen_string_literal: true

RSpec.describe Migrations::Importer::Customizations::BackupStoreBundle, :rails do
  let(:error) { Migrations::Importer::Customizations::Error }

  around do |example|
    Dir.mktmpdir do |dir|
      @root = dir
      example.run
    end
  end

  let(:store) { BackupRestore::LocalBackupStore.new(root_directory: @root) }

  def store_file(name, content)
    File.write(
      File.join(BackupRestore::LocalBackupStore.base_directory(root_directory: @root), name),
      content,
    )
  end

  it "yields a local copy of the bundle" do
    store_file("customizations.zip", "zip data")

    content = described_class.open("customizations.zip", store:) { |path| File.read(path) }

    expect(content).to eq("zip data")
  end

  it "fails when the file isn't in the store" do
    expect { described_class.open("missing.zip", store:) { nil } }.to raise_error(
      error,
      /missing\.zip not found in the local backup store/,
    )
  end

  it "only accepts file names" do
    expect { described_class.open("../customizations.zip", store:) { nil } }.to raise_error(
      error,
      /must be a file name/,
    )
  end
end
