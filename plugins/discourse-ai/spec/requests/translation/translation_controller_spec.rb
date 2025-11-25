# frozen_string_literal: true

describe DiscourseAi::Translation::TranslationController do
  fab!(:user)
  fab!(:admin)
  fab!(:test_post, :post)
  fab!(:group)

  before do
    enable_current_plugin
    assign_fake_provider_to(:ai_default_llm_model)
    SiteSetting.discourse_ai_enabled = true
    SiteSetting.ai_translation_enabled = true
    SiteSetting.content_localization_supported_locales = "en"
    SiteSetting.content_localization_allowed_groups = "#{Group::AUTO_GROUPS[:staff]}|#{group.id}"
    SiteSetting.content_localization_enabled = true
  end

  describe "#translate" do
    context "when not logged in" do
      it "returns a 403 response" do
        post "/discourse-ai/translate/posts/#{test_post.id}"
        expect(response.status).to eq(403)
      end
    end

    context "when logged in but not in allowed groups" do
      it "returns a 403 response" do
        sign_in(user)
        post "/discourse-ai/translate/posts/#{test_post.id}"
        expect(response.status).to eq(403)
      end
    end

    context "when logged in and in allowed groups" do
      before do
        group.add(user)
        SiteSetting.content_localization_allowed_groups = group.id.to_s
        sign_in(user)
      end

      it "returns a 404 for non-existent post" do
        post "/discourse-ai/translate/posts/999999"
        expect(response.status).to eq(404)
      end

      it "successfully enqueues post translation job when user can edit" do
        admin_post = Fabricate(:post, user: admin)

        expect_enqueued_with(
          job: Jobs::DetectTranslatePost,
          args: {
            post_id: admin_post.id,
            force: true,
          },
        ) { post "/discourse-ai/translate/posts/#{admin_post.id}" }

        expect(response.status).to eq(200)
      end

      it "enqueues topic translation job when translating first post" do
        first_post = Fabricate(:post, topic: Fabricate(:topic), user: admin)
        expect_enqueued_with(
          job: Jobs::DetectTranslateTopic,
          args: {
            topic_id: first_post.topic.id,
            force: true,
          },
        ) { post "/discourse-ai/translate/posts/#{first_post.id}" }

        expect(response.status).to eq(200)
      end
    end

    context "when required settings are unconfigured" do
      it "returns a 400 response" do
        sign_in(admin)
        SiteSetting.ai_translation_enabled = false

        post "/discourse-ai/translate/posts/#{test_post.id}"
        expect(response.status).to eq(400)
      end
    end
  end

  describe "#schedule_topic" do
    fab!(:topic)
    fab!(:post1) { Fabricate(:post, topic: topic, user: user) }
    fab!(:post2) { Fabricate(:post, topic: topic, user: user) }

    context "when not logged in" do
      it "returns a 403 response" do
        post "/discourse-ai/translate/topics/#{topic.id}"
        expect(response.status).to eq(403)
      end
    end

    context "when logged in but not in allowed groups" do
      it "returns a 403 response" do
        sign_in(user)
        post "/discourse-ai/translate/topics/#{topic.id}"
        expect(response.status).to eq(403)
      end
    end

    context "when logged in and in allowed groups" do
      before do
        group.add(user)
        SiteSetting.content_localization_allowed_groups = group.id.to_s
        sign_in(user)
      end

      it "returns a 404 for non-existent topic" do
        post "/discourse-ai/translate/topics/999999"
        expect(response.status).to eq(404)
      end

      it "successfully enqueues translation jobs for untranslated posts" do
        post1.update!(locale: "en")
        post2.update!(locale: "en")
        SiteSetting.content_localization_supported_locales = "en|es"

        expect_enqueued_with(
          job: Jobs::DetectTranslateTopic,
          args: {
            topic_id: topic.id,
            force: true,
          },
        ) do
          expect_enqueued_with(
            job: Jobs::DetectTranslatePost,
            args: {
              post_id: post1.id,
              force: true,
            },
          ) do
            expect_enqueued_with(
              job: Jobs::DetectTranslatePost,
              args: {
                post_id: post2.id,
                force: true,
              },
            ) { post "/discourse-ai/translate/topics/#{topic.id}" }
          end
        end

        expect(response.status).to eq(200)
        expect(response.parsed_body["scheduled_posts"]).to eq(2)
      end

      it "returns error when all posts are already translated" do
        post1.update!(locale: "en")
        post2.update!(locale: "en")
        SiteSetting.content_localization_supported_locales = "en"

        post "/discourse-ai/translate/topics/#{topic.id}"
        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to include(
          I18n.t("discourse_ai.translation.errors.all_posts_translated"),
        )
      end

      it "ignores posts without detected locale" do
        post1.update!(locale: "en")
        post2.update!(locale: nil)
        SiteSetting.content_localization_supported_locales = "en|es"

        expect_enqueued_with(
          job: Jobs::DetectTranslatePost,
          args: {
            post_id: post1.id,
            force: true,
          },
        ) { post "/discourse-ai/translate/topics/#{topic.id}" }

        expect(response.status).to eq(200)
        expect(response.parsed_body["scheduled_posts"]).to eq(1)
      end

      it "ignores deleted posts" do
        post1.update!(locale: "en", deleted_at: Time.now)
        post2.update!(locale: "en")
        SiteSetting.content_localization_supported_locales = "en|es"

        expect_enqueued_with(
          job: Jobs::DetectTranslatePost,
          args: {
            post_id: post2.id,
            force: true,
          },
        ) { post "/discourse-ai/translate/topics/#{topic.id}" }

        expect(response.status).to eq(200)
        expect(response.parsed_body["scheduled_posts"]).to eq(1)
      end

      it "ignores posts that already have translations" do
        post1.update!(locale: "en")
        post2.update!(locale: "en")
        SiteSetting.content_localization_supported_locales = "en|es"

        Fabricate(:post_localization, post: post1, locale: "es")

        expect_enqueued_with(
          job: Jobs::DetectTranslatePost,
          args: {
            post_id: post2.id,
            force: true,
          },
        ) { post "/discourse-ai/translate/topics/#{topic.id}" }

        expect(response.status).to eq(200)
        expect(response.parsed_body["scheduled_posts"]).to eq(1)
      end
    end

    context "when required settings are unconfigured" do
      it "returns a 400 response" do
        sign_in(admin)
        SiteSetting.ai_translation_enabled = false

        post "/discourse-ai/translate/topics/#{topic.id}"
        expect(response.status).to eq(400)
      end
    end
  end
end
