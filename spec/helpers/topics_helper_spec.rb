# frozen_string_literal: true

RSpec.describe TopicsHelper do
  describe "#topic_path_with_flat_param" do
    it "adds flat=1 to paths without a query string" do
      expect(helper.topic_path_with_flat_param("/t/topic/1", force: true)).to eq("/t/topic/1?flat=1")
    end

    it "adds flat=1 to paths with an existing query string" do
      expect(helper.topic_path_with_flat_param("/t/topic/1?page=2", force: true)).to eq(
        "/t/topic/1?page=2&flat=1",
      )
    end

    it "does not duplicate an existing flat=1 parameter" do
      expect(helper.topic_path_with_flat_param("/t/topic/1?page=2&flat=1", force: true)).to eq(
        "/t/topic/1?page=2&flat=1",
      )
    end

    it "appends anchors after the query string" do
      expect(helper.topic_path_with_flat_param("/t/topic/1", force: true, anchor: "post_2")).to eq(
        "/t/topic/1?flat=1#post_2",
      )
    end
  end

  describe "#nested_posts_have_unrendered_replies?" do
    it "is true when a rendered post has fewer children than its direct reply count" do
      expect(
        helper.nested_posts_have_unrendered_replies?([
          { direct_reply_count: 2, children: [{ direct_reply_count: 0, children: [] }] },
        ]),
      ).to eq(true)
    end

    it "is true when a descendant has unrendered replies" do
      expect(
        helper.nested_posts_have_unrendered_replies?([
          {
            direct_reply_count: 1,
            children: [{ direct_reply_count: 1, children: [] }],
          },
        ]),
      ).to eq(true)
    end

    it "is false when all direct replies are rendered" do
      expect(
        helper.nested_posts_have_unrendered_replies?([
          {
            direct_reply_count: 1,
            children: [{ direct_reply_count: 0, children: [] }],
          },
        ]),
      ).to eq(false)
    end
  end

  describe "#categories_breadcrumb" do
    let(:user) { Fabricate(:user) }

    let(:category) { Fabricate(:category_with_definition) }
    let(:subcategory) { Fabricate(:category_with_definition, parent_category_id: category.id) }
    let(:subsubcategory) do
      Fabricate(:category_with_definition, parent_category_id: subcategory.id)
    end

    it "works with sub-sub-categories" do
      SiteSetting.max_category_nesting = 3
      topic = Fabricate(:topic, category: subsubcategory)

      breadcrumbs = helper.categories_breadcrumb(topic)
      expect(breadcrumbs.length).to eq(3)
      expect(breadcrumbs[0][:name]).to eq(category.name)
      expect(breadcrumbs[1][:name]).to eq(subcategory.name)
      expect(breadcrumbs[2][:name]).to eq(subsubcategory.name)
    end
  end
end
