# frozen_string_literal: true

RSpec.describe Jobs::ProcessPost do
  it "returns when the post cannot be found" do
    expect { Jobs::ProcessPost.new.execute(post_id: 1) }.not_to raise_error
  end

  context "with a post" do
    fab!(:post)

    it "does not erase posts when CookedPostProcessor malfunctions" do
      # Look kids, an actual reason why you want to use mocks
      CookedPostProcessor.any_instance.expects(:html).returns(" ")
      cooked = post.cooked

      post.reload
      expect(post.cooked).to eq(cooked)

      Jobs::ProcessPost.new.execute(post_id: post.id, cook: true)
    end

    it "recooks if needed" do
      cooked = post.cooked

      post.update_columns(cooked: "frogs")
      Jobs::ProcessPost.new.execute(post_id: post.id, cook: true)

      post.reload
      expect(post.cooked).to eq(cooked)
    end

    it "processes posts" do
      post =
        Fabricate(:post, raw: "<img src='#{Discourse.base_url_no_prefix}/awesome/picture.png'>")
      expect(post.cooked).to match(/http/)
      stub_image_size

      Jobs::ProcessPost.new.execute(post_id: post.id)
      post.reload

      # subtle but cooked post processor strip this stuff, this ensures all the code gets a workout
      expect(post.cooked).not_to match(/http/)
    end

    it "always re-extracts links on post process" do
      post.update_columns(raw: "sam has a blog at https://samsaffron.com")
      expect { Jobs::ProcessPost.new.execute(post_id: post.id) }.to change { TopicLink.count }.by(1)
    end

    it "extracts links to quoted posts" do
      quoted_post =
        Fabricate(
          :post,
          raw: "This is a post with a link to https://www.discourse.org",
          post_number: 42,
        )
      post.update_columns(
        raw:
          "This quote is the best\n\n[quote=\"#{quoted_post.user.username}, topic:#{quoted_post.topic_id}, post:#{quoted_post.post_number}\"]\n#{quoted_post.excerpt}\n[/quote]",
      )
      stub_image_size
      # when creating a quote, we also create the reflexion link
      expect { Jobs::ProcessPost.new.execute(post_id: post.id) }.to change { TopicLink.count }.by(2)
    end

    it "extracts links to oneboxed topics" do
      oneboxed_post = Fabricate(:post)
      post.update_columns(raw: "This post is the best\n\n#{oneboxed_post.full_url}")
      stub_image_size
      # when creating a quote, we also create the reflexion link
      expect { Jobs::ProcessPost.new.execute(post_id: post.id) }.to change { TopicLink.count }.by(2)
    end

    it "works for posts that belong to no existing user" do
      cooked = post.cooked

      post.update_columns(cooked: "frogs", user_id: nil)
      Jobs::ProcessPost.new.execute(post_id: post.id, cook: true)
      post.reload
      expect(post.cooked).to eq(cooked)

      post.update_columns(cooked: "frogs", user_id: User.maximum("id") + 1)
      Jobs::ProcessPost.new.execute(post_id: post.id, cook: true)
      post.reload
      expect(post.cooked).to eq(cooked)
    end

    it "updates the topic excerpt when first post" do
      post = Fabricate(:post, raw: "Some OP content", cooked: "")
      post.topic.update_excerpt("Incorrect")

      Jobs::ProcessPost.new.execute(post_id: post.id)
      expect(post.topic.reload.excerpt).to eq("Some OP content")

      post2 = Fabricate(:post, raw: "Some reply content", cooked: "", topic: post.topic)
      Jobs::ProcessPost.new.execute(post_id: post2.id)
      expect(post.topic.reload.excerpt).to eq("Some OP content")
    end
  end

  describe "#enqueue_pull_hotlinked_images" do
    fab!(:post) { Fabricate(:post, created_at: 20.days.ago) }
    let(:job) { Jobs::ProcessPost.new }

    it "runs even when download_remote_images_to_local is disabled" do
      # We want to run it to pull hotlinked optimized images
      SiteSetting.download_remote_images_to_local = false
      expect_enqueued_with(job: :pull_hotlinked_images, args: { post_id: post.id }) do
        job.execute({ post_id: post.id })
      end
    end

    context "when download_remote_images_to_local? is enabled" do
      before { SiteSetting.download_remote_images_to_local = true }

      it "enqueues" do
        expect_enqueued_with(job: :pull_hotlinked_images, args: { post_id: post.id }) do
          job.execute({ post_id: post.id })
        end
      end

      it "does not run when requested to skip" do
        job.execute({ post_id: post.id, skip_pull_hotlinked_images: true })
        expect(Jobs::PullHotlinkedImages.jobs.size).to eq(0)
      end
    end
  end
end
