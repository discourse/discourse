# frozen_string_literal: true

RSpec.describe MigrationsSpecSetup do
  describe ".boot_rails" do
    it "resolves the migration spec paths before changing directories" do
      calls = []
      allow(RSpec.configuration).to receive(:files_to_run) { calls << :files_to_run }
      allow(Dir).to receive(:chdir) { calls << :chdir }

      described_class.boot_rails(__dir__)

      expect(calls).to eq(%i[files_to_run chdir])
    end
  end
end
