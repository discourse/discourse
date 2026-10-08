# frozen_string_literal: true

RSpec.describe "Assignment crawler rendering" do
  fab!(:topic) { Fabricate(:post).topic }
  fab!(:attacker, :user)
  fab!(:assignable_group, :group)

  before do
    SiteSetting.assign_enabled = true
    SiteSetting.assigns_public = true
    SiteSetting.assign_allowed_on_groups = assignable_group.id.to_s
    SiteSetting.max_prints_per_hour_per_user = 10
    SiteSetting.prioritize_full_name_in_ux = true
    assignable_group.add(attacker)
  end

  it "escapes a self-assigned user's display name in the unauthenticated print view" do
    xss_payload = "<img src=x onerror=alert(1)>"

    sign_in(attacker)
    put "/u/#{attacker.username}.json", params: { name: xss_payload }

    expect(response.status).to eq(200)

    put "/assign/assign.json",
        params: {
          target_id: topic.id,
          target_type: "Topic",
          username: attacker.username,
          note: "Taking this",
        }

    expect(response.status).to eq(200)

    sign_out
    get "/t/#{topic.slug}/#{topic.id}/print", headers: { HTTP_USER_AGENT: "Rails Testing" }

    expect(response.status).to eq(200)
    expect(response.body).to include(ERB::Util.html_escape(xss_payload))
    expect(response.body).not_to include(xss_payload)
  end
end
