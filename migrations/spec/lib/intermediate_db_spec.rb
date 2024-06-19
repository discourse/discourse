# frozen_string_literal: true

RSpec.describe Migrations::IntermediateDB do
  context "with `Migrator`" do
    let(:db_path) { "path/to/db" }
    let(:migrations_path) { "path/to/migrations" }
    let(:migrator_instance) { instance_double(Migrations::IntermediateDB::Migrator) }

    before do
      allow(Migrations::IntermediateDB::Migrator).to receive(:new).with(
        db_path,
        migrations_path,
      ).and_return(migrator_instance)

      allow(Migrations::IntermediateDB::Migrator).to receive(:new).with(db_path).and_return(
        migrator_instance,
      )
    end

    describe ".migrate" do
      it "migrates the database" do
        allow(migrator_instance).to receive(:migrate)

        described_class.migrate(db_path, migrations_path:)

        expect(Migrations::IntermediateDB::Migrator).to have_received(:new).with(
          db_path,
          migrations_path,
        )
        expect(migrator_instance).to have_received(:migrate)
      end
    end

    describe ".reset!" do
      it "resets the database" do
        allow(migrator_instance).to receive(:reset!)

        described_class.reset!(db_path)

        expect(Migrations::IntermediateDB::Migrator).to have_received(:new).with(db_path)
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
          expect(connection).to be_a(Migrations::IntermediateDB::Connection)
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
end
