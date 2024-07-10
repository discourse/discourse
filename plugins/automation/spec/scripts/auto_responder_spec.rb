# frozen_string_literal: true

describe "AutoResponder" do
  fab!(:topic)

  fab!(:automation) { Fabricate(:automation, script: DiscourseAutomation::Scripts::AUTO_RESPONDER) }

  context "without word filter" do
    before do
      automation.upsert_field!(
        "word_answer_list",
        "key-value",
        { value: [{ key: "", value: "this is the reply" }].to_json },
      )
    end

    it "creates an answer" do
      post = create_post(topic: topic, raw: "this is a post")
      automation.trigger!("post" => post)

      expect(topic.reload.posts.last.raw).to eq("this is the reply")
    end
  end

  context "with present word_answer list" do
    before do
      automation.upsert_field!(
        "word_answer_list",
        "key-value",
        {
          value: [
            { key: "fooz?|bar", value: "this is {{key}}" },
            { key: "bar", value: "this is {{key}}" },
          ].to_json,
        },
      )
    end

    context "when post is first post" do
      context "when topic title contains keywords" do
        it "creates an answer" do
          topic = Fabricate(:topic, title: "What a foo day to walk")
          post = create_post(topic: topic, raw: "this is a post with no keyword")
          automation.trigger!("post" => post)

          expect(topic.reload.posts.last.raw).to eq("this is foo")
        end
      end

      context "when post and topic title contain keyword" do
        it "creates only one answer" do
          topic = Fabricate(:topic, title: "What a foo day to walk")
          post = create_post(topic: topic, raw: "this is a post with foo keyword")
          automation.trigger!("post" => post)

          expect(topic.reload.posts.last.raw).to eq("this is foo")
        end
      end

      context "when the word answer list has a wildcard (empty string) for key" do
        before do
          automation.upsert_field!(
            "word_answer_list",
            "key-value",
            { value: [{ key: "", value: "this is a response" }].to_json },
          )
        end

        it "creates an answer" do
          topic = Fabricate(:topic, title: "What a foo day to walk")
          post = create_post(topic: topic, raw: "this is a post with no keyword")
          automation.trigger!("post" => post)

          expect(topic.reload.posts.last.raw).to eq("this is a response")
        end
      end
    end

    context "when post contains a keyword" do
      it "creates an answer" do
        post = create_post(topic: topic, raw: "this is foo a post with foo")
        automation.trigger!("post" => post)

        expect(topic.reload.posts.last.raw).to eq("this is foo")
      end

      context "when post has direct replies from answering user" do
        fab!(:answering_user) { Fabricate(:user) }

        before do
          automation.upsert_field!(
            "answering_user",
            "user",
            { value: answering_user.username },
            target: "script",
          )
        end

        it "doesn’t create another answer" do
          post_1 = create_post(topic: topic, raw: "this is a post with foo")
          create_post(user: answering_user, reply_to_post_number: post_1.post_number, topic: topic)

          expect { automation.trigger!("post" => post_1) }.not_to change { Post.count }
        end
      end

      context "when user is replying to own post" do
        fab!(:answering_user) { Fabricate(:user) }

        before do
          automation.upsert_field!(
            "answering_user",
            "user",
            { value: answering_user.username },
            target: "script",
          )
        end

        it "doesn’t create an answer" do
          post_1 = create_post(topic: topic)
          post_2 =
            create_post(
              user: answering_user,
              topic: topic,
              reply_to_post_number: post_1.post_number,
              raw: "this is a post with foo",
            )

          expect { automation.trigger!("post" => post_2) }.not_to change { Post.count }
        end
      end

      context "when once is used" do
        before { automation.upsert_field!("once", "boolean", { value: true }, target: "script") }

        it "allows only one response by automation" do
          post = create_post(topic: topic, raw: "this is a post with foo and bar")
          automation.trigger!("post" => post)

          expect(post.topic.reload.posts_count).to eq(2)

          post = create_post(topic: topic, raw: "this is another post with foo and bar")
          automation.trigger!("post" => post)

          expect(post.topic.reload.posts_count).to eq(3)

          another_automation =
            Fabricate(:automation, script: DiscourseAutomation::Scripts::AUTO_RESPONDER)
          another_automation.upsert_field!("once", "boolean", { value: true }, target: "script")
          another_automation.upsert_field!(
            "word_answer_list",
            "key-value",
            { value: [{ key: "", value: "this is the reply" }].to_json },
          )
          post = create_post(topic: topic, raw: "this is the last post with foo and bar")
          another_automation.trigger!("post" => post)

          expect(post.topic.reload.posts_count).to eq(5)
        end
      end
    end

    context "when post contains two keywords" do
      it "creates an answer with both answers" do
        post = create_post(topic: topic, raw: "this is a post with FOO and bar")
        automation.trigger!("post" => post)

        expect(topic.reload.posts.last.raw).to eq("this is FOO\n\nthis is bar")
      end
    end

    context "when post doesn’t contain a keyword" do
      it "doesn’t create an answer" do
        post = create_post(topic: topic, raw: "this is a post with no keyword")

        expect { automation.trigger!("post" => post) }.not_to change { Post.count }
      end
    end

    context "when post contains two keywords" do
      it "creates an answer with both answers" do
        post = create_post(topic: topic, raw: "this is a post with foo and bar")
        automation.trigger!("post" => post)

        expect(topic.reload.posts.last.raw).to eq("this is foo\n\nthis is bar")
      end
    end

    context "when post doesn’t contain a keyword" do
      it "doesn’t create an answer" do
        post = create_post(topic: topic, raw: "this is a post bfoo with no keyword fooa")

        expect { automation.trigger!("post" => post) }.not_to change { Post.count }
      end
    end
  end

  context "when word_answer list is empty" do
    it "exits early with no error" do
      expect {
        post = create_post(topic: topic, raw: "this is a post with foo and bar")
        automation.trigger!("post" => post)
      }.to_not raise_error
    end
  end
end
