# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Schema do
  fab!(:user)

  let(:guardian) { Discourse.system_user.guardian }

  def serialized_keys(serializer_class, object)
    MultiJson.load(serializer_class.new(object, scope: guardian, root: false).to_json).keys
  end

  def expect_emitted(declared, emitted)
    expect(declared.keys - emitted).to be_empty
  end

  it "emits every property USER_PROPERTIES declares" do
    expect_emitted(
      described_class::USER_PROPERTIES,
      serialized_keys(DiscourseWorkflows::UserSerializer, user),
    )
  end

  it "emits every property BASIC_USER_PROPERTIES declares" do
    expect_emitted(
      described_class::BASIC_USER_PROPERTIES,
      serialized_keys(BasicUserSerializer, user),
    )
  end
end
