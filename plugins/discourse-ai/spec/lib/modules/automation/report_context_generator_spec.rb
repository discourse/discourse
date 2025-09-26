# frozen_string_literal: true

module DiscourseAi
  module Automation
    describe ReportContextGenerator do
      describe ".generate" do
        fab!(:private_message_post)
        fab!(:post_in_other_category) { Fabricate(:post) }

        fab!(:category)
        fab!(:topic) { Fabricate(:topic, category: category) }
        fab!(:post_in_category) { Fabricate(:post, topic: topic) }
        fab!(:reply_in_category) { Fabricate(:post, topic: topic, reply_to_post_number: 1) }

        fab!(:group)
        fab!(:private_category) { Fabricate(:private_category, group: group) }
        fab!(:secure_topic) do
          Fabricate(:topic, title: "category in secure category", category: private_category)
        end
        fab!(:user_in_group) { Fabricate(:user, groups: [group]) }
        fab!(:post_in_private_category) do
          Fabricate(:post, user: user_in_group, topic: secure_topic)
        end

        fab!(:tag)
        fab!(:tag2) { Fabricate(:tag) }
        fab!(:topic_with_tag) { Fabricate(:topic, tags: [tag, tag2]) }
        fab!(:post_with_tag) { Fabricate(:post, topic: topic_with_tag) }

        fab!(:long_post) do
          Fabricate(
            :post,
            raw: (1..100).map { |i| "testing#{i}" }.join(" "),
            topic: Fabricate(:topic, category: category),
          )
        end

        fab!(:topic_with_likes) { Fabricate(:topic, like_count: 10) }

        fab!(:post_with_likes) { Fabricate(:post, topic: topic_with_likes, like_count: 10) }

        fab!(:post_with_likes2) { Fabricate(:post, topic: topic_with_likes, like_count: 5) }

        fab!(:post_with_likes3) { Fabricate(:post, topic: topic_with_likes, like_count: 3) }

        before { enable_current_plugin }

        if defined?(DiscourseSolved)
          it "will correctly denote solved topics" do
            Fabricate(:solved_topic, topic: topic_with_likes, answer_post: post_with_likes2)

            context = ReportContextGenerator.generate(start_date: 1.day.ago, duration: 2.day)

            expect(context).to include("solved: true")
            expect(context).to include("solution: true")
          end
        end

        it "will exclude non visible topics" do
          post_with_likes3.topic.update(visible: false)

          context = ReportContextGenerator.generate(start_date: 1.day.ago, duration: 2.day)

          expect(context).not_to include("topic_id: #{topic_with_likes.id}")
        end

        it "always includes info from last posts on topic" do
          context =
            ReportContextGenerator.generate(start_date: 1.day.ago, duration: 2.day, max_posts: 1)

          expect(context).to include("...")
          expect(context).to include("post_number: 3")
        end

        it "includes a summary" do
          context = ReportContextGenerator.generate(start_date: 1.day.ago, duration: 2.day)

          expect(context).to include("New posts: 8")
          expect(context).to include("New topics: 5")
        end

        it "orders so most liked are first" do
          context = ReportContextGenerator.generate(start_date: 1.day.ago, duration: 2.day)

          regex = "topic_id: #{topic_with_likes.id}.*topic_id: #{long_post.topic.id}"
          expect(context).to match(Regexp.new(regex, Regexp::MULTILINE))
        end

        it "allows you to prioritize groups" do
          context =
            ReportContextGenerator.generate(
              start_date: 1.day.ago,
              duration: 2.day,
              prioritized_group_ids: [group.id],
              allow_secure_categories: true,
              max_posts: 1,
            )

          expect(context).to include(post_in_private_category.topic.title)
          expect(context).not_to include(post_in_other_category.topic.title)
          expect(context).to include(group.name)
        end

        it "can generate context (excluding PMs)" do
          context = ReportContextGenerator.generate(start_date: 1.day.ago, duration: 2.day)

          expect(context).to include(post_in_other_category.topic.title)
          expect(context).to include(topic.title)
          expect(context).not_to include(private_message_post.topic.title)
          expect(context).not_to include(secure_topic.title)
        end

        it "can filter on tag" do
          context =
            ReportContextGenerator.generate(
              start_date: 1.day.ago,
              duration: 2.day,
              tags: [tag.name],
            )

          expect(context).not_to include(post_in_other_category.topic.title)
          expect(context).not_to include(topic.title)
          expect(context).not_to include(private_message_post.topic.title)
          expect(context).not_to include(secure_topic.title)
          expect(context).to include(post_with_tag.topic.title)
        end

        it "can optionally include secure categories" do
          context =
            ReportContextGenerator.generate(
              start_date: 1.day.ago,
              duration: 2.day,
              allow_secure_categories: true,
            )
          expect(context).to include(post_in_other_category.topic.title)
          expect(context).to include(topic.title)
          expect(context).not_to include(private_message_post.topic.title)
          expect(context).to include(secure_topic.title)
        end

        it "can filter to a categories" do
          context =
            ReportContextGenerator.generate(
              start_date: 1.day.ago,
              duration: 2.day,
              category_ids: [category.id],
            )

          expect(context).not_to include(post_in_other_category.topic.title)
          expect(context).to include(topic.title)
          expect(context).not_to include(private_message_post.topic.title)
          expect(context).not_to include(secure_topic.title)
        end
      end
    end
  end
end
