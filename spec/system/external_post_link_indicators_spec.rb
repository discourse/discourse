# frozen_string_literal: true

describe "External post link indicators" do
  fab!(:post) { Fabricate(:post, raw: <<~MARKDOWN) }
      Links to [a local page](/latest), [our documentation](https://docs.example.test/guide),
      [a different host](https://sub.docs.example.test/guide), and [email](mailto:info@example.test).
    MARKDOWN

  it "leaves links unchanged by default" do
    visit post.topic.relative_url
    expect(page).to have_link("a different host")
    expect(page).to have_no_css(".post-external-link")
  end

  it "marks an outbound link and honors exact internal hostnames" do
    SiteSetting.show_external_post_link_indicators = true
    SiteSetting.external_post_link_internal_hosts = "docs.example.test"
    visit post.topic.relative_url

    expect(page).to have_css(".cooked a.post-external-link", count: 1)
    within(".cooked a.post-external-link") do
      expect(page).to have_text("a different host")
      expect(page).to have_css(".post-external-link__icon")
    end
    expect(find(".cooked a.post-external-link")["aria-description"]).to eq(
      I18n.t("js.post.external_link_indicator"),
    )
  end
end
