# frozen_string_literal: true

describe "Tag view", type: :system do
  fab!(:tag_1) { Fabricate(:tag, name: "design") }
  fab!(:tag_2) { Fabricate(:tag, name: "art") }
  fab!(:topic) { Fabricate(:topic, tags: [tag_2]) }
  fab!(:current_user) { Fabricate(:admin) }

  let(:tags_page) { PageObjects::Pages::Tag.new }
  let(:topic_list) { PageObjects::Components::TopicList.new }

  before { sign_in(current_user) }

  describe "the tag info section" do
    context "when navigating to another tag" do
      it "shows the details of the new tag" do
        tags_page.visit_tag(tag_1)

        tags_page.tag_info_btn.click
        expect(tags_page.tag_name_within_tag_info).to eq(tag_1.name)

        tags_page.tags_dropdown.expand
        tags_page.tags_dropdown.search(tag_2.name)
        tags_page.tags_dropdown.select_row_by_value(tag_2.name)

        expect(topic_list).to have_topic(topic)
        expect(tags_page.tag_name_within_tag_info).to eq(tag_2.name)
      end
    end
  end
end
