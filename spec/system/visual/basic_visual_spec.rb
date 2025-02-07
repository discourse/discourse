# frozen_string_literal: true
require_relative "./visual_helper"

describe "Basic Visual" do
  let!(:topic) { Fabricate(:topic_with_op) }
  let!(:post) { Fabricate(:post, topic: topic) }
  fab!(:user) { Fabricate(:admin) }

  it "saves some screenshots" do
    visit "/latest"
    expect(page).to have_css(".topic-list-item")
    sleep 3
    screenshot("Topic List")

    visit "/u/#{user.username_lower}"
    sleep 3
    screenshot("User Profile")
  end
end
