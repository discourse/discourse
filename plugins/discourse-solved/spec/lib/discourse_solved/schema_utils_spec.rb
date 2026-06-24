# frozen_string_literal: true

RSpec.describe DiscourseSolved::SchemaUtils do
  before do
    SiteSetting.allow_solved_on_all_topics = true
    SiteSetting.solved_add_schema_markup = "always"
  end

  describe ".qa_page_schema?" do
    # A fresh topic per example avoids the memoized @qa_page_schema bleeding between tests.

    it "returns true when an eligible text reply exists" do
      topic = Fabricate(:topic_with_op)
      Fabricate(:post, topic:, raw: "This is a written answer")

      expect(described_class.qa_page_schema?(topic)).to eq(true)
    end

    it "returns false when the only replies are textless onebox-only posts" do
      topic = Fabricate(:topic_with_op)
      Fabricate(
        :post,
        topic:,
        raw: "https://www.youtube.com/watch?v=test",
        cooked:
          '<div class="onebox video-onebox"><iframe src="https://youtube.com/embed/test"></iframe></div>',
      )

      expect(described_class.qa_page_schema?(topic)).to eq(false)
    end
  end
end
