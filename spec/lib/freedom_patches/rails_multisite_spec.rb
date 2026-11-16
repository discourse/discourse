# frozen_string_literal: true

require "rails_helper"

RSpec.describe(RailsMultisite::ConnectionManagement, type: :multisite) do
  let(:cm) { RailsMultisite::ConnectionManagement.instance }
  let(:path) { Rails.root.join("tmp/multisite_spec_config.yml").to_s }

  before do
    # The multisite hook points us at the shared fixture; work on a private
    # copy so examples can rewrite the config safely.
    FileUtils.cp("spec/fixtures/multisite/two_dbs.yml", path)
    RailsMultisite::ConnectionManagement.config_filename = path
    cm.instance_variable_set(:@config_mtime, nil)
  end

  after { File.unlink(path) if File.exist?(path) }

  def write_config(yaml)
    File.write(path, yaml)
    # Guarantee an mtime change even on filesystems with coarse timestamps.
    File.utime(Time.now + 1, Time.now + 1, path)
  end

  it "is a no-op in single site mode" do
    null = RailsMultisite::ConnectionManagement::NullInstance.instance
    allow(RailsMultisite::ConnectionManagement).to receive(:instance).and_return(null)

    expect(described_class.reload_if_changed).to eq(false)
  end

  it "reloads once per config file change" do
    expect(cm.reload_if_changed).to eq(true)
    expect(cm.reload_if_changed).to eq(false)

    write_config(<<~YAML)
      default:
        adapter: postgresql
        database: discourse_test
        host_names:
          - test.localhost
    YAML

    expect(cm.reload_if_changed).to eq(true)
    expect(cm.all_dbs).to contain_exactly("default")
  end

  it "picks up a site decommission without a restart" do
    expect(cm.all_dbs).to include("second")

    write_config(<<~YAML)
      default:
        adapter: postgresql
        database: discourse_test
        host_names:
          - test.localhost
    YAML

    expect(cm.reload_if_changed).to eq(true)
    expect(cm.all_dbs).not_to include("second")
    expect(cm.db_spec_cache.key?("second")).to eq(false)
  end

  it "keeps the previous config when the file is unparseable" do
    expect(cm.reload_if_changed).to eq(true)

    write_config("\tnot: [valid, yaml")

    expect(cm.reload_if_changed).to eq(false)
    expect(cm.all_dbs).to include("second")
  end

  it "retries after a failed reload" do
    expect(cm.reload_if_changed).to eq(true)

    write_config("\tnot: [valid, yaml")
    expect(cm.reload_if_changed).to eq(false)

    write_config(<<~YAML)
      default:
        adapter: postgresql
        database: discourse_test
        host_names:
          - test.localhost
    YAML

    expect(cm.reload_if_changed).to eq(true)
    expect(cm.all_dbs).to contain_exactly("default")
  end
end
