# frozen_string_literal: true

RSpec.describe Migrations::CLI::Bootstrap do
  describe ".normalize_option_args" do
    subject(:normalized) { described_class.normalize_option_args(argv) }

    context "with the `--opt=value` form" do
      let(:argv) { %w[schema generate --db=intermediate_db] }

      it "splits it into two tokens" do
        expect(normalized).to eq(%w[schema generate --db intermediate_db])
      end
    end

    context "with the `--opt value` form" do
      let(:argv) { %w[schema generate --db intermediate_db] }

      it "leaves it unchanged" do
        expect(normalized).to eq(%w[schema generate --db intermediate_db])
      end
    end

    it "splits only on the first `=`" do
      expect(described_class.normalize_option_args(["--filter=a=b"])).to eq(%w[--filter a=b])
    end

    it "preserves comma-separated values" do
      expect(described_class.normalize_option_args(["--only=users,topics"])).to eq(
        %w[--only users,topics],
      )
    end

    it "does not touch short flags, the `--` separator, or bare values" do
      argv = %w[-s=x -- key=value]
      expect(described_class.normalize_option_args(argv)).to eq(argv)
    end

    it "leaves a bare `--=value` untouched" do
      expect(described_class.normalize_option_args(["--=value"])).to eq(["--=value"])
    end
  end
end
