# frozen_string_literal: true

RSpec.describe DiscourseAi::AiHelper::AssistantController do
  fab!(:newuser)
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }

  before do
    enable_current_plugin
    assign_fake_provider_to(:ai_default_llm_model)
    SiteSetting.ai_helper_enabled = true
  end

  describe "#stream_suggestion" do
    before do
      Jobs.run_immediately!
      SiteSetting.composer_ai_helper_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
    end

    it "is able to stream suggestions to helper" do
      sign_in(user)

      my_post = Fabricate(:post)

      channel = nil
      messages =
        MessageBus.track_publish do
          results = [["hello ", "world"]]
          DiscourseAi::Completions::Llm.with_prepared_responses(results) do
            post "/discourse-ai/ai-helper/stream_suggestion.json",
                 params: {
                   text: "hello wrld",
                   location: "helper",
                   client_id: "1234",
                   post_id: my_post.id,
                   custom_prompt: "Translate to Spanish",
                   mode: DiscourseAi::AiHelper::Assistant::CUSTOM_PROMPT,
                 }

            expect(response.status).to eq(200)
            channel = response.parsed_body["progress_channel"]
          end
        end

      # we only have the channel after we make the request
      # so we can not filter till now
      messages = messages.select { |m| m.channel == channel }
      expect(messages).not_to be_empty

      last_message = messages.last
      expect(messages.all? { |m| m.client_ids == ["1234"] }).to eq(true)
      expect(messages.all? { |m| m == last_message || !m.data[:done] }).to eq(true)

      expect(last_message.channel).to eq(channel)
      expect(last_message.data[:result]).to eq("hello world")
      expect(last_message.data[:done]).to eq(true)
    end

    it "is able to stream suggestions to composer" do
      sign_in(user)
      channel = nil
      messages =
        MessageBus.track_publish do
          results = [["hello ", "world"]]
          DiscourseAi::Completions::Llm.with_prepared_responses(results) do
            post "/discourse-ai/ai-helper/stream_suggestion.json",
                 params: {
                   text: "hello wrld",
                   location: "composer",
                   client_id: "1234",
                   mode: DiscourseAi::AiHelper::Assistant::PROOFREAD,
                 }

            expect(response.status).to eq(200)
            channel = response.parsed_body["progress_channel"]
          end
        end

      # we only have the channel after we make the request
      # so we can not filter till now
      messages = messages.select { |m| m.channel == channel }

      last_message = messages.last
      expect(messages.all? { |m| m.client_ids == ["1234"] }).to eq(true)
      expect(messages.all? { |m| m == last_message || !m.data[:done] }).to eq(true)

      expect(last_message.channel).to eq(channel)
      expect(last_message.data[:result]).to eq("hello world")
      expect(last_message.data[:done]).to eq(true)
    end
  end

  describe "#suggest" do
    let(:text_to_proofread) { "The rain in spain stays mainly in the plane." }
    let(:proofread_text) { "The rain in Spain, stays mainly in the Plane." }
    let(:mode) { DiscourseAi::AiHelper::Assistant::PROOFREAD }

    context "when not logged in" do
      it "returns a 403 response" do
        post "/discourse-ai/ai-helper/suggest", params: { text: text_to_proofread, mode: mode }

        expect(response.status).to eq(403)
      end
    end

    context "when logged in as an user without enough privileges" do
      before do
        sign_in(newuser)
        SiteSetting.composer_ai_helper_allowed_groups = Group::AUTO_GROUPS[:staff]
      end

      it "returns a 403 response" do
        post "/discourse-ai/ai-helper/suggest", params: { text: text_to_proofread, mode: mode }

        expect(response.status).to eq(403)
      end
    end

    context "when logged in as an allowed user" do
      before do
        sign_in(user)
        user.group_ids = [Group::AUTO_GROUPS[:trust_level_1]]
        SiteSetting.composer_ai_helper_allowed_groups = Group::AUTO_GROUPS[:trust_level_1]
      end

      it "returns a 400 if the helper mode is invalid" do
        invalid_mode = "asd"

        post "/discourse-ai/ai-helper/suggest",
             params: {
               text: text_to_proofread,
               mode: invalid_mode,
             }

        expect(response.status).to eq(400)
      end

      it "returns a 400 if the text is blank" do
        post "/discourse-ai/ai-helper/suggest", params: { mode: mode }

        expect(response.status).to eq(400)
      end

      it "returns a generic error when the completion call fails" do
        DiscourseAi::Completions::Llm
          .any_instance
          .expects(:generate)
          .raises(DiscourseAi::Completions::Endpoints::Base::CompletionFailed)

        post "/discourse-ai/ai-helper/suggest", params: { mode: mode, text: text_to_proofread }

        expect(response.status).to eq(502)
      end

      it "returns a suggestion" do
        expected_diff =
          "<div class=\"inline-diff\"><p>The rain in <ins>Spain</ins><ins>,</ins><ins> </ins><del>spain </del>stays mainly in the <ins>Plane</ins><del>plane</del>.</p></div>"

        DiscourseAi::Completions::Llm.with_prepared_responses([proofread_text]) do
          post "/discourse-ai/ai-helper/suggest", params: { mode: mode, text: text_to_proofread }

          expect(response.status).to eq(200)
          expect(response.parsed_body["suggestions"].first).to eq(proofread_text)
          expect(response.parsed_body["diff"]).to eq(expected_diff)
        end
      end

      it "uses custom instruction when using custom_prompt mode" do
        translated_text = "Un usuario escribio esto"
        expected_diff =
          "<div class=\"inline-diff\"><p><ins>Un </ins><ins>usuario </ins><ins>escribio </ins><ins>esto</ins><del>A </del><del>user </del><del>wrote </del><del>this</del></p></div>"

        DiscourseAi::Completions::Llm.with_prepared_responses([translated_text]) do
          post "/discourse-ai/ai-helper/suggest",
               params: {
                 mode: DiscourseAi::AiHelper::Assistant::CUSTOM_PROMPT,
                 text: "A user wrote this",
                 custom_prompt: "Translate to Spanish",
               }

          expect(response.status).to eq(200)
          expect(response.parsed_body["suggestions"].first).to eq(translated_text)
          expect(response.parsed_body["diff"]).to eq(expected_diff)
        end
      end

      it "prevents double render when mode is ILLUSTRATE_POST" do
        DiscourseAi::Completions::Llm.with_prepared_responses([proofread_text]) do
          expect {
            post "/discourse-ai/ai-helper/suggest",
                 params: {
                   mode: DiscourseAi::AiHelper::Assistant::ILLUSTRATE_POST,
                   text: text_to_proofread,
                   force_default_locale: true,
                 }
          }.not_to raise_error
          expect(response.status).to eq(200)
        end
      end

      context "when performing numerous requests" do
        it "rate limits" do
          RateLimiter.enable
          rate_limit = described_class::RATE_LIMITS["default"]
          amount = rate_limit[:amount]

          amount.times do
            DiscourseAi::Completions::Llm.with_prepared_responses([proofread_text]) do
              post "/discourse-ai/ai-helper/suggest",
                   params: {
                     mode: mode,
                     text: text_to_proofread,
                   }
              expect(response.status).to eq(200)
            end
          end
          DiscourseAi::Completions::Llm.with_prepared_responses([proofread_text]) do
            post "/discourse-ai/ai-helper/suggest", params: { mode: mode, text: text_to_proofread }
            expect(response.status).to eq(429)
          end
        end
      end
    end
  end

  describe "#suggest_title" do
    fab!(:category)
    fab!(:topic) { Fabricate(:topic, category: category) }
    fab!(:post_1) { Fabricate(:post, topic: topic, raw: "I love apples") }
    fab!(:post_3) { Fabricate(:post, topic: topic, raw: "I love mangos") }
    fab!(:post_2) { Fabricate(:post, topic: topic, raw: "I love bananas") }

    context "when logged in as an allowed user" do
      before do
        sign_in(user)
        user.group_ids = [Group::AUTO_GROUPS[:trust_level_1]]
        SiteSetting.composer_ai_helper_allowed_groups = Group::AUTO_GROUPS[:trust_level_1]
      end

      context "when suggesting titles with a topic_id" do
        let(:title_suggestions) do
          {
            output: [
              "What are your favourite fruits?",
              "Love for fruits",
              "Fruits are amazing",
              "Favourite fruit list",
              "Fruit share topic",
            ],
          }
        end
        let(:title_suggestions_array) do
          [
            "What are your favourite fruits?",
            "Love for fruits",
            "Fruits are amazing",
            "Favourite fruit list",
            "Fruit share topic",
          ]
        end

        it "returns title suggestions based on all topic post context" do
          DiscourseAi::Completions::Llm.with_prepared_responses([title_suggestions]) do
            post "/discourse-ai/ai-helper/suggest_title", params: { topic_id: topic.id }

            expect(response.status).to eq(200)
            expect(response.parsed_body["suggestions"]).to eq(title_suggestions_array)
          end
        end

        it "returns a 403 when the user cannot see the topic" do
          private_topic = Fabricate(:private_message_topic)

          post "/discourse-ai/ai-helper/suggest_title", params: { topic_id: private_topic.id }

          expect(response.status).to eq(403)
        end
      end

      context "when suggesting titles with input text" do
        let(:title_suggestions) do
          {
            output: [
              "Apples - the best fruit",
              "Why apples are great",
              "Apples are the best fruit",
              "My love for apples",
              "I love apples",
            ],
          }
        end
        let(:title_suggestions_array) do
          [
            "Apples - the best fruit",
            "Why apples are great",
            "Apples are the best fruit",
            "My love for apples",
            "I love apples",
          ]
        end
        it "returns title suggestions based on the input text" do
          DiscourseAi::Completions::Llm.with_prepared_responses([title_suggestions]) do
            post "/discourse-ai/ai-helper/suggest_title", params: { text: post_1.raw }

            expect(response.status).to eq(200)
            expect(response.parsed_body["suggestions"]).to eq(title_suggestions_array)
          end
        end
      end
    end
  end

  describe "#caption_image" do
    let(:image) { plugin_file_from_fixtures("100x100.jpg") }
    let(:upload) { UploadCreator.new(image, "image.jpg").create_for(Discourse.system_user.id) }
    let(:image_url) { "#{Discourse.base_url}#{upload.url}" }
    let(:caption) { "A picture of a cat sitting on a table" }
    let(:caption_with_attrs) do
      "A picture of a cat sitting on a table (#{I18n.t("discourse_ai.ai_helper.image_caption.attribution")})"
    end
    let(:bad_caption) { "A picture of a cat \nsitting on a |table|" }

    def request_caption(params, caption = "A picture of a cat sitting on a table")
      DiscourseAi::Completions::Llm.with_prepared_responses([caption]) do
        post "/discourse-ai/ai-helper/caption_image", params: params

        yield(response)
      end
    end

    context "when logged in as an allowed user" do
      before do
        sign_in(user)

        SiteSetting.composer_ai_helper_allowed_groups = Group::AUTO_GROUPS[:trust_level_1]
      end

      it "returns the suggested caption for the image" do
        request_caption({ image_url: image_url, image_url_type: "long_url" }) do |r|
          expect(r.status).to eq(200)
          expect(r.parsed_body["caption"]).to eq(caption_with_attrs)
        end
      end

      it "returns a cleaned up caption from the LLM" do
        request_caption({ image_url: image_url, image_url_type: "long_url" }, bad_caption) do |r|
          expect(r.status).to eq(200)
          expect(r.parsed_body["caption"]).to eq(caption_with_attrs)
        end
      end

      it "truncates the caption from the LLM" do
        request_caption({ image_url: image_url, image_url_type: "long_url" }, caption * 10) do |r|
          expect(r.status).to eq(200)
          expect(r.parsed_body["caption"].size).to be < caption.size * 10
        end
      end

      context "when the image_url is a short_url" do
        let(:image_url) { upload.short_url }

        it "returns the suggested caption for the image" do
          request_caption({ image_url: image_url, image_url_type: "short_url" }) do |r|
            expect(r.status).to eq(200)
            expect(r.parsed_body["caption"]).to eq(caption_with_attrs)
          end
        end
      end

      context "when the image_url is a short_path" do
        let(:image_url) { "#{Discourse.base_url}#{upload.short_path}" }

        it "returns the suggested caption for the image" do
          request_caption({ image_url: image_url, image_url_type: "short_path" }) do |r|
            expect(r.status).to eq(200)
            expect(r.parsed_body["caption"]).to eq(caption_with_attrs)
          end
        end
      end

      it "returns a 502 error when the completion call fails" do
        DiscourseAi::Completions::Llm.with_prepared_responses(
          [DiscourseAi::Completions::Endpoints::Base::CompletionFailed.new],
        ) do
          post "/discourse-ai/ai-helper/caption_image",
               params: {
                 image_url: image_url,
                 image_url_type: "long_url",
               }

          expect(response.status).to eq(502)
        end
      end

      it "returns a 400 error when the image_url is blank" do
        post "/discourse-ai/ai-helper/caption_image"

        expect(response.status).to eq(400)
      end

      it "returns a 404 error if no upload is found" do
        post "/discourse-ai/ai-helper/caption_image",
             params: {
               image_url: "http://blah.com/img.jpeg",
               image_url_type: "long_url",
             }

        expect(response.status).to eq(404)
      end

      context "for secure uploads" do
        fab!(:group)
        fab!(:private_category) { Fabricate(:private_category, group: group) }
        let(:image) { plugin_file_from_fixtures("100x100.jpg") }
        let(:upload) { UploadCreator.new(image, "image.jpg").create_for(Discourse.system_user.id) }
        let(:image_url) { "#{Discourse.base_url}/secure-uploads/#{upload.url}" }

        before do
          Jobs.run_immediately!

          # this is done so the after_save callbacks for site settings to make
          # UploadReference records works
          @original_provider = SiteSetting.provider
          SiteSetting.provider = SiteSettings::DbProvider.new(SiteSetting)
          enable_current_plugin
          setup_s3
          stub_s3_store
          SiteSetting.secure_uploads = true
          SiteSetting.composer_ai_helper_allowed_groups = Group::AUTO_GROUPS[:trust_level_1]

          Group.find(SiteSetting.composer_ai_helper_allowed_groups_map.first).add(user)
          user.reload

          stub_request(
            :get,
            "http://s3-upload-bucket.s3.dualstack.us-west-1.amazonaws.com/original/1X/#{upload.sha1}.#{upload.extension}",
          ).to_return(status: 200, body: "", headers: {})
        end
        after { SiteSetting.provider = @original_provider }

        it "returns a 403 error if the user cannot access the secure upload" do
          # hosted-site plugin edge case, it enables embeddings
          SiteSetting.ai_embeddings_enabled = false

          create_post(
            title: "Secure upload post",
            raw: "This is a new post <img src=\"#{upload.url}\" />",
            category: private_category,
            user: Discourse.system_user,
          )

          post "/discourse-ai/ai-helper/caption_image",
               params: {
                 image_url: image_url,
                 image_url_type: "long_url",
               }
          expect(response.status).to eq(403)
        end

        it "returns a 200 message and caption if user can access the secure upload" do
          group.add(user)

          request_caption({ image_url: image_url, image_url_type: "long_url" }) do |r|
            expect(r.status).to eq(200)
            expect(r.parsed_body["caption"]).to eq(caption_with_attrs)
          end
        end

        context "if the input URL is for a secure upload but not on the secure-uploads path" do
          let(:image_url) { "#{Discourse.base_url}#{upload.url}" }

          it "creates a signed URL properly and makes the caption" do
            group.add(user)

            request_caption({ image_url: image_url, image_url_type: "long_url" }) do |r|
              expect(r.status).to eq(200)
              expect(r.parsed_body["caption"]).to eq(caption_with_attrs)
            end
          end
        end
      end

      context "when performing numerous requests" do
        it "rate limits" do
          RateLimiter.enable

          rate_limit = described_class::RATE_LIMITS["caption_image"]
          amount = rate_limit[:amount]

          amount.times do
            request_caption({ image_url: image_url, image_url_type: "long_url" }) do |r|
              expect(r.status).to eq(200)
            end
          end

          request_caption({ image_url: image_url, image_url_type: "long_url" }) do |r|
            expect(r.status).to eq(429)
          end
        end
      end
    end
  end

  describe "semantic suggestions" do
    fab!(:embedding_definition)
    fab!(:private_message_topic)

    before do
      sign_in(user)
      user.group_ids = [Group::AUTO_GROUPS[:trust_level_1]]
      SiteSetting.composer_ai_helper_allowed_groups = Group::AUTO_GROUPS[:trust_level_1]
      SiteSetting.ai_embeddings_selected_model = embedding_definition.id
      SiteSetting.ai_embeddings_enabled = true
    end

    describe "#semantic_tags" do
      context "when passing a topic the user doesn't have access to" do
        it "returns a 403" do
          post "/discourse-ai/ai-helper/suggest_tags",
               params: {
                 topic_id: private_message_topic.id,
               }

          expect(response.status).to eq(403)
        end
      end
    end

    describe "#semantic_categories" do
      context "when passing a topic the user doesn't have access to" do
        it "returns a 403" do
          post "/discourse-ai/ai-helper/suggest_category",
               params: {
                 topic_id: private_message_topic.id,
               }

          expect(response.status).to eq(403)
        end
      end
    end
  end
end
