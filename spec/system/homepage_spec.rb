# frozen_string_literal: true

describe "Homepage query parameters" do
  it "Retains single query parameters" do
    path = "/?test_one=true"
    visit(path)
    expect(page).to have_current_path(path)
  end

  it "Retains multiple query parameters" do
    path = "/?test_one=true&test_two=2"
    visit(path)
    expect(page).to have_current_path(path)
  end

  it "Strips out the _discourse_homepage_rewrite param" do
    visit("/?_discourse_homepage_rewrite=1&test_one=true&test_two=2")
    expect(page).to have_current_path("/?test_one=true&test_two=2")
  end
end
