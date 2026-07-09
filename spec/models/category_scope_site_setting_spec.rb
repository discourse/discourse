# frozen_string_literal: true

describe CategoryScopeSiteSetting do
  it "returns translated category scope values" do
    expect(described_class.values).to contain_exactly(
      { name: "category_scope.all", value: "all" },
      { name: "category_scope.public", value: "public" },
      { name: "category_scope.include", value: "include" },
      { name: "category_scope.include_strict", value: "include_strict" },
      { name: "category_scope.exclude", value: "exclude" },
      { name: "category_scope.exclude_strict", value: "exclude_strict" },
    )
    expect(described_class.translate_names?).to eq(true)
  end

  it "validates category scope values" do
    expect(described_class.valid_value?("all")).to eq(true)
    expect(described_class.valid_value?("include_strict")).to eq(true)
    expect(described_class.valid_value?("invalid")).to eq(false)
  end
end
