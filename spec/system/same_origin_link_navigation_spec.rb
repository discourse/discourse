# frozen_string_literal: true

describe "Same-origin link navigation" do
  fab!(:post_with_server_link) do
    Fabricate(:post, raw: "Visit [the static resource](/favicon.ico?from=post#icon).")
  end

  it "lets the browser load a same-origin link with no Ember route" do
    visit post_with_server_link.topic.relative_url
    click_link "the static resource"

    expect(page).to have_current_path("/favicon.ico?from=post")
    expect(URI.parse(page.current_url).fragment).to eq("icon")
    expect(page).to have_no_css("#main-outlet")
  end
end
