# frozen_string_literal: true

RSpec.describe AllowUncategorizedTopicsValidator do
  subject(:validator) { described_class.new }

  it "only allows enabling while the uncategorized category exists" do
    expect(validator.valid_value?("t")).to eq(true)

    SiteSetting.uncategorized_category_id = -1

    expect(validator.valid_value?("t")).to eq(false)
    expect(validator.valid_value?("f")).to eq(true)
  end
end
