# frozen_string_literal: true

describe DiscourseMcp::Tools::GetUser do
  fab!(:viewer, :admin)
  fab!(:user) { Fabricate(:user, name: "Hidden Name") }

  it "hides full names when names are disabled" do
    SiteSetting.enable_names = false
    request_context = instance_double(DiscourseMcp::RequestContext, guardian: viewer.guardian)

    result = described_class.call(arguments: { "username" => user.username }, request_context:)

    expect(result.dig(:structuredContent, :user)).not_to have_key(:name)
  end
end
