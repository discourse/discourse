# frozen_string_literal: true

RSpec.describe FlagSerializer do
  let(:flag) { Flag.find_by(name: "illegal") }

  context "when system flag" do
    it "returns translated name" do
      serialized = described_class.new(flag).as_json
      expect(serialized[:flag][:name]).to eq(I18n.t("post_action_types.illegal.title"))
    end

    it "returns translated description" do
      serialized = described_class.new(flag).as_json
      expect(serialized[:flag][:description]).to eq(I18n.t("post_action_types.illegal.description"))
    end
  end

  context "when custom flag" do
    it "returns translated name and description" do
      flag = Fabricate(:flag, name: "custom title", description: "custom description")
      serialized = described_class.new(flag).as_json
      expect(serialized[:flag][:name]).to eq("custom title")
      expect(serialized[:flag][:description]).to eq("custom description")
      flag.destroy!
    end
  end

  it "returns is_flag true for flags" do
    serialized = described_class.new(flag).as_json
    expect(serialized[:flag][:is_flag]).to be true
  end

  it "returns is_flag false for like" do
    flag = Flag.unscoped.find_by(name: "like")
    serialized = described_class.new(flag).as_json
    expect(serialized[:flag][:is_flag]).to be false
  end

  it "returns applies_to" do
    serialized = described_class.new(flag).as_json
    expect(serialized[:flag][:applies_to]).to eq(%w[Post Topic Chat::Message])
  end

  describe "#is_used" do
    fab!(:unused_flag) { Fabricate(:flag) }

    fab!(:used_flag) do
      flag = Fabricate(:flag)
      Fabricate(:post_action, post_action_type_id: flag.id)
      flag
    end

    it "returns false when flag is not used" do
      serialized = described_class.new(unused_flag).as_json
      expect(serialized[:flag][:is_used]).to be false
    end

    it "returns true when flag is used" do
      serialized = described_class.new(used_flag).as_json
      expect(serialized[:flag][:is_used]).to be true
    end

    it "returns true when flag's id is in used_flag_ids option" do
      serialized = described_class.new(unused_flag, used_flag_ids: [unused_flag.id]).as_json
      expect(serialized[:flag][:is_used]).to be true
    end
  end

  describe "#description" do
    let(:serializer) { described_class.new(flag, scope: Guardian.new, root: false) }
    let(:flag) { Flag.find_by(name_key: :inappropriate) }

    before { allow(Discourse).to receive(:base_path).and_return("discourse.org") }

    it "returns properly interpolated translation" do
      expect(serializer.description).to match(%r{discourse\.org/guidelines})
    end
  end
end
