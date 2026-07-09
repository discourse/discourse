# frozen_string_literal: true

describe "Local dates" do
  fab!(:topic)
  fab!(:attacker) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:victim) { Fabricate(:user, refresh_auto_groups: true) }
  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:xss_probe) { "<img src=x class=xss-probe>" }

  before { SiteSetting.discourse_local_dates_enabled = true }

  it "renders a crafted data-format as literal text for viewers, injecting no markup" do
    create_post(
      user: attacker,
      topic: topic,
      raw:
        %(<span class="discourse-local-date" data-date="2025-01-01" data-time="05:00:00" data-format="[#{CGI.escapeHTML(xss_probe)}]"></span>),
    )
    sign_in(victim)
    topic_page.visit_topic(topic)

    expect(page).to have_css(".discourse-local-date.cooked-date")
    expect(page).to have_no_css(".cooked img.xss-probe")
    expect(page).to have_css(".discourse-local-date .relative-time", text: xss_probe)
  end

  it "shows the hover preview without injecting markup from a crafted data-format" do
    create_post(
      user: attacker,
      topic: topic,
      raw:
        %(<span class="discourse-local-date" data-date="2025-01-01" data-time="05:00:00" data-format="[#{CGI.escapeHTML(xss_probe)}]"></span>),
    )
    sign_in(victim)
    topic_page.visit_topic(topic)

    expect(page).to have_css(".discourse-local-date.cooked-date")
    find(".discourse-local-date").click

    expect(page).to have_css("[data-content] .current .date-time")
    expect(page).to have_no_css("[data-content] img.xss-probe")
  end
end
