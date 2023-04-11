# frozen_string_literal: true

RSpec.describe "tasks/hashtags" do
  before do
    Rake::Task.clear
    Discourse::Application.load_tasks
  end

  describe "hashtag:mark_old_format_for_rebake" do
    fab!(:category) { Fabricate(:category, slug: "support") }

    before { SiteSetting.enable_experimental_hashtag_autocomplete = false }

    it "sets the baked_version to 0 for matching posts" do
      post_1 = Fabricate(:post, raw: "This is a cool #support hashtag")
      post_2 =
        Fabricate(
          :post,
          raw:
            "Some other thing which will not match <a class=\"hashtag-wow\">some weird custom thing</a>",
        )

      SiteSetting.enable_experimental_hashtag_autocomplete = true
      post_3 = Fabricate(:post, raw: "This is a cool #support hashtag")
      SiteSetting.enable_experimental_hashtag_autocomplete = false

      capture_stdout { Rake::Task["hashtags:mark_old_format_for_rebake"].invoke }

      [post_1, post_2, post_3].each(&:reload)

      expect(post_1.baked_version).to eq(0)
      expect(post_2.baked_version).to eq(Post::BAKED_VERSION)
      expect(post_3.baked_version).to eq(Post::BAKED_VERSION)
    end
  end
end
