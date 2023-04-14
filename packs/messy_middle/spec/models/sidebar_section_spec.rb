# frozen_string_literal: true

RSpec.describe SidebarSection do
  fab!(:user) { Fabricate(:user) }
  fab!(:sidebar_section) { Fabricate(:sidebar_section, user: user) }

  it "uses system user for public sections" do
    expect(sidebar_section.user_id).to eq(user.id)
    sidebar_section.update!(public: true)
    expect(sidebar_section.user_id).to eq(Discourse.system_user.id)
  end
end
