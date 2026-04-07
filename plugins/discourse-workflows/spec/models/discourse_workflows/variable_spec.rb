# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Variable do
  subject(:variable) { Fabricate.build(:discourse_workflows_variable) }

  it "validates key format allows only alphanumeric and underscores" do
    variable.key = "valid_key_123"
    expect(variable).to be_valid

    variable.key = "invalid key!"
    expect(variable).not_to be_valid
  end
end
