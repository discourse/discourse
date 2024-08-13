# frozen_string_literal: true

RSpec.describe FlagSerializer do
  let(:flag) { Flag.find_by(name: "illegal") }

  context "when system flag" do
    it "returns translated name" do
      serialized = described_class.new(flag, used_flag_ids: []).as_json
      expect(serialized[:flag][:name]).to eq(I18n.t("post_action_types.illegal.title"))
    end

    it "returns translated description" do
      serialized = described_class.new(flag, used_flag_ids: []).as_json
      expect(serialized[:flag][:description]).to eq(I18n.t("post_action_types.illegal.description"))
    end
  end

  context "when custom flag" do
    fab!(:flag) { Fabricate(:flag, name: "custom title", description: "custom description") }

    it "returns translated name" do
      serialized = described_class.new(flag, used_flag_ids: []).as_json
      expect(serialized[:flag][:name]).to eq("custom title")
    end

    it "returns translated description" do
      serialized = described_class.new(flag, used_flag_ids: []).as_json
      expect(serialized[:flag][:description]).to eq("custom description")
    end
  end

  it "returns is_flag true for flags" do
    serialized = described_class.new(flag, used_flag_ids: []).as_json
    expect(serialized[:flag][:is_flag]).to be true
  end

  it "returns is_flag false for like" do
    flag = Flag.unscoped.find_by(name: "like")
    serialized = described_class.new(flag, used_flag_ids: []).as_json
    expect(serialized[:flag][:is_flag]).to be false
  end

  it "returns is_used false when not used" do
    serialized = described_class.new(flag, used_flag_ids: []).as_json
    expect(serialized[:flag][:is_used]).to be false
  end

  it "returns is_used true when used" do
    serialized = described_class.new(flag, used_flag_ids: [flag.id]).as_json
    expect(serialized[:flag][:is_used]).to be true
  end

  it "returns applies_to" do
    serialized = described_class.new(flag, used_flag_ids: []).as_json
    expect(serialized[:flag][:applies_to]).to eq(%w[Post Topic Chat::Message])
  end
end
