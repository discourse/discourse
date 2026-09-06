# frozen_string_literal: true

RSpec.describe JsonApiKit::Path do
  subject(:path) { described_class.for("user.groups") }

  describe ".for" do
    it "splits a path a client wrote at each dot" do
      expect([path.current, path.next.current]).to eq(%w[user groups])
    end

    context "when one reading gives a path to the next" do
      let(:next_path) { path.next }

      it "returns the path it holds, at the relationship it reaches" do
        expect(described_class.for(next_path)).to be(next_path)
      end
    end
  end

  describe "#current" do
    it "returns the relationship to read here" do
      expect(path.current).to eq("user")
    end

    context "when a reading is past the first relationship" do
      it "returns the relationship to read there" do
        expect(path.next.current).to eq("groups")
      end
    end
  end

  describe "#last?" do
    it { is_expected.not_to be_last }

    context "when a reading is at the end of the path" do
      subject(:path) { described_class.for("user.groups").next }

      it { is_expected.to be_last }
    end
  end

  describe "#entered?" do
    it { is_expected.not_to be_entered }

    context "when a reading is part way along the path" do
      subject(:path) { described_class.for("user.groups").next }

      it { is_expected.to be_entered }
    end
  end

  describe "#next" do
    it "returns the same path, one relationship on" do
      expect(path.next.current).to eq("groups")
    end

    context "when the path holds one relationship" do
      subject(:path) { described_class.for("user") }

      it "returns nothing" do
        expect(path.next).to be_nil
      end
    end
  end

  describe "#to_s" do
    it "returns the path as a client wrote it" do
      expect(path.to_s).to eq("user.groups")
    end

    context "when a reading is past the first relationship" do
      it "returns the whole path even so" do
        expect(path.next.to_s).to eq("user.groups")
      end
    end
  end

  describe "#==" do
    it "matches a path of the same relationships" do
      expect(path).to eq(described_class.for("user.groups"))
    end

    it "differs from a path of other relationships" do
      expect(path).not_to eq(described_class.for("user.badges"))
    end

    context "when two readings have reached different relationships of one path" do
      it "leaves them unmatched" do
        expect(path.next).not_to eq(described_class.for("user.groups"))
      end
    end
  end

  describe "#hash" do
    it "counts two paths that match as one" do
      expect([path, described_class.for("user.groups")].uniq.size).to eq(1)
    end
  end
end
