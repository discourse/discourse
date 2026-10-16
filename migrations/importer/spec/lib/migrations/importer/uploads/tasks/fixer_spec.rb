# frozen_string_literal: true

RSpec.describe Migrations::Importer::Uploads::Tasks::Fixer do
  subject(:fixer) do
    described_class.allocate.tap do |task|
      task.instance_variable_set(:@files_db, files_db)
      task.instance_variable_set(:@discourse_store, discourse_store)
      task.reporter = reporter
    end
  end

  let(:files_db) do
    instance_double(Migrations::Database::Connection, execute: nil, commit_transaction: nil)
  end
  let(:discourse_store) do
    Class
      .new do
        def external?
          false
        end
      end
      .new
  end
  let(:notices) { [] }
  let(:reporter) do
    instance_double(Migrations::Reporting::Reporter::StepHandle).tap do |step|
      allow(step).to receive(:notice) { |message| notices << message }
    end
  end

  before do
    stub_const(
      "Upload",
      Class.new do
        def self.delete_by(*)
          nil
        end
      end,
    )
    allow(Upload).to receive(:delete_by)
    fixer.before_run
  end

  describe "#after_run" do
    it "reports one summary per category with a bounded sample of errors" do
      12.times { |id| expect(fixer.write(upload_id: id, status: :missing)).to eq(:warning) }
      7.times do |id|
        expect(fixer.write(upload_id: id, status: :error, error: "failure #{id}")).to eq(:error)
      end

      expect(notices).to be_empty

      fixer.after_run

      expect(notices).to eq(
        [
          "removed 12 missing uploads",
          "could not check 7 uploads (sample errors: upload 0: failure 0; upload 1: failure 1; " \
            "upload 2: failure 2; upload 3: failure 3; upload 4: failure 4)",
        ],
      )
    end
  end
end
