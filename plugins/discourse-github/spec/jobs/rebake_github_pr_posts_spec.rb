# frozen_string_literal: true

RSpec.describe Jobs::RebakeGithubPrPosts do
  fab!(:user)
  fab!(:topic)
  let(:pr_url) { "https://github.com/discourse/discourse/pull/123" }

  before { enable_current_plugin }

  describe "#execute" do
    it "does nothing with blank pr_url" do
      expect { described_class.new.execute(pr_url: nil) }.not_to raise_error
      expect { described_class.new.execute(pr_url: "") }.not_to raise_error
    end

    context "with oneboxed PR link" do
      fab!(:post) { Fabricate(:post, topic: topic, user: user) }

      before do
        post.update!(cooked: <<~HTML)
          <p>Check out this PR:</p>
          <aside class="onebox githubpullrequest" data-onebox-src="#{pr_url}">
            <header class="source"><a href="#{pr_url}">github.com</a></header>
            <article class="onebox-body">
              <div class="github-row">
                <span class="github-pr-title">Test PR</span>
              </div>
            </article>
          </aside>
        HTML

        TopicLink.create!(
          topic_id: topic.id,
          post_id: post.id,
          user_id: user.id,
          url: pr_url,
          domain: "github.com",
        )
      end

      it "rebakes posts with oneboxed PR links" do
        expect_any_instance_of(Post).to receive(:rebake!).with(
          invalidate_oneboxes: true,
          priority: :low,
        )
        described_class.new.execute(pr_url: pr_url)
      end

      it "matches URLs with path suffixes" do
        TopicLink.create!(
          topic_id: topic.id,
          post_id: post.id,
          user_id: user.id,
          url: "#{pr_url}/files",
          domain: "github.com",
        )

        post_ids =
          TopicLink
            .where(url: pr_url)
            .or(TopicLink.where("url LIKE ?", "#{pr_url}%"))
            .pluck(:post_id)

        expect(post_ids).to include(post.id)
      end
    end

    context "with inline PR link (not oneboxed)" do
      fab!(:post) { Fabricate(:post, topic: topic, user: user) }

      before do
        post.update!(cooked: <<~HTML)
          <p>Check out <a href="#{pr_url}">this PR</a> for details.</p>
        HTML

        TopicLink.create!(
          topic_id: topic.id,
          post_id: post.id,
          user_id: user.id,
          url: pr_url,
          domain: "github.com",
        )
      end

      it "does not rebake posts with only inline links" do
        expect_any_instance_of(Post).not_to receive(:rebake!)
        described_class.new.execute(pr_url: pr_url)
      end
    end

    context "with no matching posts" do
      it "completes without error" do
        expect { described_class.new.execute(pr_url: pr_url) }.not_to raise_error
      end
    end
  end
end
