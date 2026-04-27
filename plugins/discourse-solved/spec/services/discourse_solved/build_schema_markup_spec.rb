# frozen_string_literal: true

RSpec.describe DiscourseSolved::BuildSchemaMarkup do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:topic_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:user)
    fab!(:topic) { Fabricate(:topic, user:) }
    fab!(:post) { Fabricate(:post, topic:, user:, like_count: 1) }
    let(:guardian) { Guardian.new(user) }
    let(:params) { { topic_id: topic.id } }
    let(:dependencies) { { guardian: } }

    before { SiteSetting.allow_solved_on_all_topics = true }

    context "when topic_id is nil" do
      let(:params) { { topic_id: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when accepted answers are not allowed on the topic" do
      before { SiteSetting.allow_solved_on_all_topics = false }

      it { is_expected.to fail_a_policy(:accepted_answers_allowed) }
    end

    context "when schema markup is disabled" do
      before { SiteSetting.solved_add_schema_markup = "never" }

      it { is_expected.to fail_a_policy(:schema_markup_enabled) }
    end

    context "when setting is 'answered only' and there is no accepted answer" do
      before { SiteSetting.solved_add_schema_markup = "answered only" }

      it { is_expected.to fail_a_policy(:schema_markup_enabled) }
    end

    context "when setting is 'always' and topic has no answers" do
      before { SiteSetting.solved_add_schema_markup = "always" }

      it { is_expected.to fail_a_policy(:has_answers) }

      context "when the only reply is a small action post" do
        fab!(:small_action) { Fabricate(:post, topic:, post_type: Post.types[:small_action]) }

        it { is_expected.to fail_a_policy(:has_answers) }
      end

      context "when the only reply is hidden" do
        fab!(:hidden_reply) { Fabricate(:post, topic:, hidden: true) }

        it { is_expected.to fail_a_policy(:has_answers) }
      end
    end

    context "when setting is 'always' and there is no accepted answer" do
      before { SiteSetting.solved_add_schema_markup = "always" }

      context "when the topic has replies" do
        fab!(:reply) { Fabricate(:post, topic:) }

        it "includes replies as suggested answers" do
          html = result[:html]
          expect(html).to include('"suggestedAnswer"')
          expect(html).to include('"answerCount":1')
          expect(html).not_to include('"acceptedAnswer"')
        end
      end

      context "when the topic has hidden replies" do
        fab!(:hidden_reply) { Fabricate(:post, topic:, hidden: true) }
        fab!(:visible_reply) { Fabricate(:post, topic:) }

        it "excludes hidden posts from suggested answers" do
          html = result[:html]
          expect(html).to include('"answerCount":1')
          expect(html).to include(visible_reply.user.username)
          expect(html).not_to include(hidden_reply.user.username)
        end
      end
    end

    context "when there is an accepted answer but no other answers" do
      fab!(:answer_user, :user)
      fab!(:answer_post) { Fabricate(:post, topic:, user: answer_user, like_count: 3) }

      before do
        SiteSetting.solved_add_schema_markup = "always"
        Fabricate(:solved_topic, topic:, answer_post:)
      end

      it { is_expected.to run_successfully }

      it "builds QAPage markup with just the accepted answer" do
        html = result[:html]
        expect(html).to include('"@type":"QAPage"')
        expect(html).to include('"answerCount":1')
        expect(html).to include('"acceptedAnswer"')
        expect(html).to include('"@type":"Answer"')
        expect(html).to include(answer_user.username)
        expect(html).not_to include('"suggestedAnswer"')
      end
    end

    context "with a non-text post" do
      before { SiteSetting.solved_add_schema_markup = "always" }

      context "when video-only" do
        fab!(:non_text_post) do
          Fabricate(
            :post,
            topic:,
            raw: "https://www.youtube.com/watch?v=test",
            cooked:
              '<div class="onebox video-onebox"><iframe src="https://youtube.com/embed/test"></iframe></div>',
          )
        end

        context "when it is the only reply" do
          it { is_expected.to fail_a_policy(:has_answers) }
        end

        context "with other replies" do
          fab!(:visible_reply) { Fabricate(:post, topic:) }

          before { Fabricate(:solved_topic, topic:, answer_post: non_text_post) }

          it "excludes the accepted answer and falls back to suggested answers" do
            html = result[:html]
            expect(html).not_to include('"acceptedAnswer"')
            expect(html).to include('"suggestedAnswer"')
            expect(html).to include('"answerCount":1')
          end
        end
      end

      context "when image-only" do
        fab!(:non_text_post) do
          Fabricate(:post, topic:, cooked: '<p><img src="/uploads/foo.png"></p>')
        end

        context "when it is the only reply" do
          it { is_expected.to fail_a_policy(:has_answers) }
        end

        context "with other replies" do
          fab!(:visible_reply) { Fabricate(:post, topic:) }

          before { Fabricate(:solved_topic, topic:, answer_post: non_text_post) }

          it "excludes the accepted answer and falls back to suggested answers" do
            html = result[:html]
            expect(html).not_to include('"acceptedAnswer"')
            expect(html).to include('"suggestedAnswer"')
            expect(html).to include('"answerCount":1')
          end
        end
      end

      context "when emoji-only" do
        fab!(:non_text_post) do
          Fabricate(
            :post,
            topic:,
            cooked:
              '<p><img src="/images/emoji/twitter/smile.png" class="emoji" alt=":smile:"></p>',
          )
        end

        context "when it is the only reply" do
          it { is_expected.to fail_a_policy(:has_answers) }
        end

        context "with other replies" do
          fab!(:visible_reply) { Fabricate(:post, topic:) }

          before { Fabricate(:solved_topic, topic:, answer_post: non_text_post) }

          it "excludes the accepted answer and falls back to suggested answers" do
            html = result[:html]
            expect(html).not_to include('"acceptedAnswer"')
            expect(html).to include('"suggestedAnswer"')
            expect(html).to include('"answerCount":1')
          end
        end
      end
    end

    context "when the accepted answer is hidden but there are other visible replies" do
      fab!(:answer_user, :user)
      fab!(:answer_post) { Fabricate(:post, topic:, user: answer_user, like_count: 3) }
      fab!(:visible_reply) { Fabricate(:post, topic:) }

      before do
        SiteSetting.solved_add_schema_markup = "always"
        Fabricate(:solved_topic, topic:, answer_post:)
        answer_post.update!(hidden: true)
      end

      it "excludes the hidden accepted answer but includes suggested answers" do
        html = result[:html]
        expect(html).not_to include('"acceptedAnswer"')
        expect(html).to include('"suggestedAnswer"')
      end
    end

    context "when the accepted answer is hidden and there are no other replies" do
      fab!(:answer_post) { Fabricate(:post, topic:) }

      before do
        SiteSetting.solved_add_schema_markup = "always"
        Fabricate(:solved_topic, topic:, answer_post:)
        answer_post.update!(hidden: true)
      end

      it { is_expected.to fail_a_policy(:has_answers) }
    end

    context "when there is an accepted answer and suggested answers" do
      fab!(:answer_user, :user)
      fab!(:answer_post) { Fabricate(:post, topic:, user: answer_user, like_count: 3) }
      fab!(:suggested_user, :user)
      fab!(:suggested_post) { Fabricate(:post, topic:, user: suggested_user, like_count: 1) }

      before do
        SiteSetting.solved_add_schema_markup = "always"
        Fabricate(:solved_topic, topic:, answer_post:)
      end

      it { is_expected.to run_successfully }

      it "builds QAPage markup with both accepted and suggested answers" do
        html = result[:html]
        expect(html).to include('"answerCount":2')
        expect(html).to include('"acceptedAnswer"')
        expect(html).to include('"suggestedAnswer"')
        expect(html).to include(answer_user.username)
        expect(html).to include(suggested_user.username)
      end
    end
  end
end
