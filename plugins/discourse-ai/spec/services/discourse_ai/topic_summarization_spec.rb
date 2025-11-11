# frozen_string_literal: true

describe DiscourseAi::TopicSummarization do
  fab!(:user, :admin)
  fab!(:topic) { Fabricate(:topic, highest_post_number: 2) }
  fab!(:post_1) { Fabricate(:post, topic: topic, post_number: 1) }
  fab!(:post_2) { Fabricate(:post, topic: topic, post_number: 2) }

  before do
    enable_current_plugin
    assign_fake_provider_to(:ai_default_llm_model)
    SiteSetting.ai_summarization_enabled = true
  end

  let(:strategy) { DiscourseAi::Summarization.topic_summary(topic) }

  let(:summary) { "This is the final summary" }

  describe "#summarize" do
    subject(:summarization) { described_class.new(strategy, user) }

    def assert_summary_is_cached(topic, summary_response)
      cached_summary =
        AiSummary.find_by(target: topic, summary_type: AiSummary.summary_types[:complete])

      expect(cached_summary.highest_target_number).to eq(topic.highest_post_number)
      expect(cached_summary.summarized_text).to eq(summary)
      expect(cached_summary.original_content_sha).to be_present
      expect(cached_summary.algorithm).to eq("fake")
    end

    context "when the content was summarized in a single chunk" do
      it "caches the summary" do
        DiscourseAi::Completions::Llm.with_prepared_responses([summary]) do
          section = summarization.summarize
          expect(section.summarized_text).to eq(summary)
          assert_summary_is_cached(topic, summary)
        end
      end

      it "returns the cached version in subsequent calls" do
        summarization.summarize

        cached_summary_text = "This is a cached summary"
        AiSummary.find_by(target: topic, summary_type: AiSummary.summary_types[:complete]).update!(
          summarized_text: cached_summary_text,
          updated_at: 24.hours.ago,
        )

        summarization = described_class.new(strategy, user)
        section = summarization.summarize
        expect(section.summarized_text).to eq(cached_summary_text)
      end
    end

    describe "invalidating cached summaries" do
      let(:cached_text) { "This is a cached summary" }

      def cached_summary
        AiSummary.find_by(target: topic, summary_type: AiSummary.summary_types[:complete])
      end

      before do
        # a bit tricky, but fold_content now caches an instance of LLM
        # once it is cached with_prepared_responses will not work as expected
        # since it is glued to the old llm instance
        # so we create the cached summary totally independantly
        DiscourseAi::Completions::Llm.with_prepared_responses([cached_text]) do
          strategy = DiscourseAi::Summarization.topic_summary(topic)
          described_class.new(strategy, user).summarize
        end

        cached_summary.update!(summarized_text: cached_text, created_at: 24.hours.ago)
      end

      context "when the user can requests new summaries" do
        context "when there are no new posts" do
          it "returns the cached summary" do
            section = summarization.summarize

            expect(section.summarized_text).to eq(cached_text)
          end
        end

        context "when there are new posts" do
          before { cached_summary.update!(original_content_sha: "outdated_sha") }

          it "returns a new summary" do
            DiscourseAi::Completions::Llm.with_prepared_responses([summary]) do
              section = summarization.summarize

              expect(section.summarized_text).to eq(summary)
            end
          end

          context "when the cached summary is less than one hour old" do
            before { cached_summary.update!(created_at: 30.minutes.ago) }

            it "returns the cached summary" do
              cached_summary.update!(created_at: 30.minutes.ago)

              section = summarization.summarize

              expect(section.summarized_text).to eq(cached_text)
              expect(section.outdated).to eq(true)
            end

            it "returns a new summary if the skip_age_check flag is passed" do
              DiscourseAi::Completions::Llm.with_prepared_responses([summary]) do
                section = summarization.summarize(skip_age_check: true)

                expect(section.summarized_text).to eq(summary)
              end
            end
          end
        end
      end
    end

    describe "stream partial updates" do
      it "receives a blk that is passed to the underlying strategy and called with partial summaries" do
        partial_result = +""

        DiscourseAi::Completions::Llm.with_prepared_responses([summary]) do
          summarization.summarize { |partial_summary| partial_result << partial_summary }
        end

        # In a real world example, this is removed in the returned AiSummary obj.
        expect(partial_result.chomp("\"}")).to eq(summary)
      end
    end
  end
end
