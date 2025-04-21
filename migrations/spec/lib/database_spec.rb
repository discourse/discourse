# frozen_string_literal: true

RSpec.describe ::Migrations::Database do
  context "with `Migrator`" do
    let(:db_path) { "path/to/db" }
    let(:migrations_path) { "path/to/migrations" }
    let(:migrator_instance) { instance_double(::Migrations::Database::Migrator) }

    before do
      allow(::Migrations::Database::Migrator).to receive(:new).with(db_path).and_return(
        migrator_instance,
      )

      allow(::Migrations::Database::Migrator).to receive(:new).with(db_path).and_return(
        migrator_instance,
      )
    end

    describe ".migrate" do
      it "migrates the database" do
        allow(migrator_instance).to receive(:migrate)

        described_class.migrate(db_path, migrations_path:)

        expect(::Migrations::Database::Migrator).to have_received(:new).with(db_path)
        expect(migrator_instance).to have_received(:migrate).with(migrations_path)
      end
    end

    describe ".reset!" do
      it "resets the database" do
        allow(migrator_instance).to receive(:reset!)

        described_class.reset!(db_path)

        expect(::Migrations::Database::Migrator).to have_received(:new).with(db_path)
        expect(migrator_instance).to have_received(:reset!)
      end
    end
  end

  describe ".connect" do
    it "yields a new connection and closes it after the block" do
      Dir.mktmpdir do |storage_path|
        db_path = File.join(storage_path, "test.db")
        db = nil

        described_class.connect(db_path) do |connection|
          expect(connection).to be_a(::Migrations::Database::Connection)
          expect(connection.path).to eq(db_path)

          db = connection.db
          expect(db).not_to be_closed
        end

        expect(db).to be_closed
      end
    end

    it "closes the connection even if an exception is raised within block" do
      Dir.mktmpdir do |storage_path|
        db_path = File.join(storage_path, "test.db")
        db = nil

        expect {
          described_class.connect(db_path) do |connection|
            db = connection.db
            expect(db).not_to be_closed
            raise "boom"
          end
        }.to raise_error(StandardError)

        expect(db).to be_closed
      end
    end
  end

  describe ".format_datetime" do
    it "formats a DateTime object to ISO 8601 string" do
      datetime = DateTime.new(2023, 10, 5, 17, 30, 0)
      expect(described_class.format_datetime(datetime)).to eq("2023-10-05T17:30:00Z")
    end

    it "returns nil for nil input" do
      expect(described_class.format_datetime(nil)).to be_nil
    end
  end

  describe ".format_date" do
    it "formats a Date object to ISO 8601 string" do
      date = Date.new(2023, 10, 5)
      expect(described_class.format_date(date)).to eq("2023-10-05")
    end

    it "returns nil for nil input" do
      expect(described_class.format_date(nil)).to be_nil
    end
  end

  describe ".format_boolean" do
    it "returns 1 for true" do
      expect(described_class.format_boolean(true)).to eq(1)
    end

    it "returns 0 for false" do
      expect(described_class.format_boolean(false)).to eq(0)
    end

    it "returns nil for nil input" do
      expect(described_class.format_boolean(nil)).to be_nil
    end
  end

  describe ".format_ip_address" do
    it "formats a valid IPv4 address" do
      expect(described_class.format_ip_address("192.168.1.1")).to eq("192.168.1.1")
    end

    it "formats a valid IPv6 address" do
      expect(described_class.format_ip_address("2001:0db8:85a3:0000:0000:8a2e:0370:7334")).to eq(
        "2001:db8:85a3::8a2e:370:7334",
      )
    end

    it "returns nil for an invalid IP address" do
      expect(described_class.format_ip_address("invalid_ip")).to be_nil
    end

    it "returns nil for nil input" do
      expect(described_class.format_ip_address(nil)).to be_nil
    end
  end

  describe ".to_blob" do
    it "converts a string to a `Extralite::Blob`" do
      expect(described_class.to_blob("Hello, 世界!")).to be_a(Extralite::Blob)
    end

    it "returns nil for nil input" do
      expect(described_class.to_blob(nil)).to be_nil
    end
  end

  describe ".to_json" do
    it "returns a JSON string for objects" do
      expect(described_class.to_json(123)).to eq("123")
      expect(described_class.to_json("hello world")).to eq(%q|"hello world"|)
      expect(
        described_class.to_json(
          text: "foo",
          number: 123,
          date: DateTime.new(2023, 10, 5, 17, 30, 0),
        ),
      ).to eq(%q|{"text":"foo","number":123,"date":"2023-10-05T17:30:00.000+00:00"}|)
    end

    it "returns nil for nil input" do
      expect(described_class.to_json(nil)).to be_nil
    end
  end
end
