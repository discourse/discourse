# frozen_string_literal: true

describe "Reviewable queued post tags" do
  with_select_controls(true)

  fab!(:admin)
  fab!(:cool_tag) { Fabricate(:tag, name: "cool") }
  fab!(:neat_tag) { Fabricate(:tag, name: "neat") }
  fab!(:fresh_tag) { Fabricate(:tag, name: "fresh") }
  fab!(:reviewable, :reviewable_queued_post_topic)

  let(:review_page) { PageObjects::Pages::Review.new }
  let(:tag_chooser) do
    PageObjects::Components::UiKit::DSelect.at(
      ".review-item[data-reviewable-id='#{reviewable.id}'] .editable-field .mini-tag-chooser",
    )
  end

  before do
    SiteSetting.tagging_enabled = true
    sign_in(admin)
  end

  it "edits the tags before approving with the new select controls" do
    review_page.visit_reviewable(reviewable)
    review_page.click_edit_post_button

    expect(tag_chooser).to have_selected_names("cool", "neat")

    tag_chooser.remove_name("neat")
    tag_chooser.search("fresh")
    tag_chooser.select_name("fresh")
    tag_chooser.close

    expect(tag_chooser).to have_selected_names("cool", "fresh")

    review_page.save_post_edit

    expect(page).to have_no_css(".reviewable-action.save-edit")
    # Edited tags are stored as tag objects; approval reduces them to names.
    saved_tags = reviewable.reload.payload["tags"].map { |t| t.is_a?(Hash) ? t["name"] : t }
    expect(saved_tags).to contain_exactly("cool", "fresh")

    review_page.select_action(reviewable, "approve_post")

    expect(review_page).to have_reviewable_with_approved_status(reviewable)

    topic = Topic.find_by(title: reviewable.payload["title"])
    expect(topic.tags.map(&:name)).to contain_exactly("cool", "fresh")
  end
end
