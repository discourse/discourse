# frozen_string_literal: true

RSpec.describe Vips do
  describe ".run" do
    it "preserves default resource limits when overriding a limit" do
      Discourse::SafeExec
        .expects(:capture)
        .with do |*command, **options|
          command == %w[vips --version] &&
            options[:rlimits] ==
              {
                cpu_seconds: 5,
                memory_bytes: 4 * 1024 * 1024 * 1024,
                file_size_bytes: 10 * 1024 * 1024 * 1024,
                open_files: 1024,
              }
        end
        .returns("vips-8.18.4\n")

      expect(described_class.run("vips", "--version", rlimits: { cpu_seconds: 5 })).to eq(
        "vips-8.18.4\n",
      )
    end
  end
end
