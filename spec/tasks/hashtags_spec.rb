# frozen_string_literal: true

RSpec.describe "tasks/hashtags" do
  describe "hashtag:mark_old_format_for_rebake" do
    fab!(:category) { Fabricate(:category, slug: "support") }

    it "sets the baked_version to 0 for matching posts" do
      hashtag_html = PrettyText.cook("#support").gsub("<p>", "").gsub("</p>", "")
      post_1 = Fabricate(:post, raw: "This is a cool #support hashtag")
      post_2 =
        Fabricate(
          :post,
          raw:
            "Some other thing which will not match <a class=\"hashtag-wow\">some weird custom thing</a>",
        )
      post_3 = Fabricate(:post, raw: "This is a cool #support hashtag")

      # Update to use the old hashtag format.
      post_1.update!(
        cooked: post_1.cooked.gsub(hashtag_html, "<span class=\"hashtag\"'>#support</span>"),
      )

      capture_stdout { invoke_rake_task("hashtags:mark_old_format_for_rebake") }

      [post_1, post_2, post_3].each(&:reload)

      expect(post_1.baked_version).to eq(0)
      expect(post_2.baked_version).to eq(Post::BAKED_VERSION)
      expect(post_3.baked_version).to eq(Post::BAKED_VERSION)
    end
  end
end
