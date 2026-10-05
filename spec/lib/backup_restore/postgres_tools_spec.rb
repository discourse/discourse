# frozen_string_literal: true

RSpec.describe BackupRestore::PostgresTools do
  def stub_clients(command, versions)
    paths = versions.map { |version| "/clients/#{version}/#{command}" }
    described_class.stubs(:binary_paths).with(command).returns(paths)
    versions
      .zip(paths)
      .each do |version, path|
        Open3
          .stubs(:capture3)
          .with(path, "--version")
          .returns(["#{command} (PostgreSQL) #{version}.1", "", stub(success?: true)])
      end
  end

  describe ".find" do
    it "chooses the oldest dump client that supports the source server" do
      stub_clients("pg_dump", [18, 15])

      expect(described_class.find("pg_dump", server_version: 14)).to eq("/clients/15/pg_dump")
      expect(described_class.find("pg_dump", server_version: 15)).to eq("/clients/15/pg_dump")
      expect(described_class.find("pg_dump", server_version: 16)).to eq("/clients/18/pg_dump")
    end

    it "chooses the newest restore client no newer than the destination server" do
      stub_clients("pg_restore", [15, 18])

      expect(described_class.find("pg_restore", server_version: 15)).to eq("/clients/15/pg_restore")
      expect(described_class.find("pg_restore", server_version: 17)).to eq("/clients/15/pg_restore")
      expect(described_class.find("pg_restore", server_version: 18)).to eq("/clients/18/pg_restore")
      expect(described_class.find("pg_restore", server_version: 19)).to eq("/clients/18/pg_restore")
    end

    it "rejects dump clients older than the source server" do
      stub_clients("pg_dump", [15, 18])

      expect { described_class.find("pg_dump", server_version: 19) }.to raise_error(
        /Install PostgreSQL client tools version 19 or newer/,
      )
    end

    it "rejects restore clients newer than the destination server" do
      stub_clients("pg_restore", [15, 18])

      expect { described_class.find("pg_restore", server_version: 14) }.to raise_error(
        /Install PostgreSQL client tools version 14 or older/,
      )
    end

    it "ignores clients whose version cannot be determined" do
      stub_clients("pg_restore", [15, 18])
      Open3
        .stubs(:capture3)
        .with("/clients/18/pg_restore", "--version")
        .returns(["", "broken installation", stub(success?: false)])

      expect(described_class.find("pg_restore", server_version: 18)).to eq("/clients/15/pg_restore")
    end
  end

  describe ".binary_paths" do
    it "discovers versioned installs and tools on PATH without requiring a PostgreSQL server" do
      Dir.mktmpdir do |directory|
        versioned_bin = File.join(directory, "versioned", "bin")
        path_bin = File.join(directory, "path", "bin")
        FileUtils.mkdir_p([versioned_bin, path_bin])
        paths = [versioned_bin, path_bin].map { |bin| File.join(bin, "pg_restore") }
        paths.each do |path|
          File.write(path, "")
          File.chmod(0o755, path)
        end
        Dir.stubs(:glob).with(described_class::BIN_DIRECTORIES).returns([versioned_bin])
        ENV.stubs(:fetch).with("PATH", "").returns([path_bin, path_bin].join(File::PATH_SEPARATOR))

        expect(described_class.binary_paths("pg_restore")).to eq(paths)
      end
    end
  end
end
