# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::AdminAssistantAccess do
  fab!(:admin)

  it "is permissive by default and threads user and phase through restrictive modifiers" do
    expect(described_class.check(feature: :reports, user: admin, phase: :generation).allowed).to eq(
      true,
    )

    plugin = Plugin::Instance.new
    modifier =
      lambda do |decision, request|
        expect([request.feature, request.user, request.phase]).to eq([:reports, admin, :approval])
        decision.deny!("Unavailable")
      end
    DiscoursePluginRegistry.register_modifier(plugin, :admin_assistant_feature_access, &modifier)

    result = described_class.check(feature: :reports, user: admin, phase: :approval)
    expect(result).to have_attributes(allowed: false, message: "Unavailable")
  ensure
    if plugin && modifier
      DiscoursePluginRegistry.unregister_modifier(
        plugin,
        :admin_assistant_feature_access,
        &modifier
      )
    end
  end
end
