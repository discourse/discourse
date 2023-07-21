# frozen_string_literal: true

describe TopicSummarization do
  fab!(:topic) { Fabricate(:topic) }
  fab!(:user) { Fabricate(:admin) }
  fab!(:post_1) { Fabricate(:post, topic: topic) }
  fab!(:post_2) { Fabricate(:post, topic: topic) }

  shared_examples "includes only public-visible topics" do
    subject { described_class.new(DummyCustomSummarization.new({})) }

    it "only includes visible posts" do
      topic.first_post.update!(hidden: true)

      posts = subject.summary_targets(topic)

      expect(posts.none?(&:hidden?)).to eq(true)
    end

    it "doesn't include posts without users" do
      topic.first_post.user.destroy!

      posts = subject.summary_targets(topic)

      expect(posts.detect { |p| p.id == topic.first_post.id }).to be_nil
    end

    it "doesn't include deleted posts" do
      topic.first_post.update!(user_id: nil)

      posts = subject.summary_targets(topic)

      expect(posts.detect { |p| p.id == topic.first_post.id }).to be_nil
    end
  end

  describe "#summary_targets" do
    context "when the topic has a best replies summary" do
      before { topic.has_summary = true }

      it_behaves_like "includes only public-visible topics"
    end

    context "when the topic doesn't have a best replies summary" do
      before { topic.has_summary = false }

      it_behaves_like "includes only public-visible topics"
    end
  end

  describe "#summarize" do
    subject(:summarization) { described_class.new(strategy) }

    let(:strategy) { DummyCustomSummarization.new(summary) }

    def assert_summary_is_cached(topic, summary_response)
      cached_summary = SummarySection.find_by(target: topic, meta_section_id: nil)

      expect(cached_summary.content_range).to cover(*topic.posts.map(&:post_number))
      expect(cached_summary.summarized_text).to eq(summary_response[:summary])
      expect(cached_summary.original_content_sha).to be_present
      expect(cached_summary.algorithm).to eq(strategy.model)
    end

    def assert_chunk_is_cached(topic, chunk_response)
      cached_chunk =
        SummarySection
          .where.not(meta_section_id: nil)
          .find_by(
            target: topic,
            content_range: (chunk_response[:ids].min..chunk_response[:ids].max),
          )

      expect(cached_chunk.summarized_text).to eq(chunk_response[:summary])
      expect(cached_chunk.original_content_sha).to be_present
      expect(cached_chunk.algorithm).to eq(strategy.model)
    end

    context "when the content was summarized in a single chunk" do
      let(:summary) { { summary: "This is the final summary", chunks: [] } }

      it "caches the summary" do
        section = summarization.summarize(topic, user)

        expect(section.summarized_text).to eq(summary[:summary])

        assert_summary_is_cached(topic, summary)
      end

      it "returns the cached version in subsequent calls" do
        summarization.summarize(topic, user)

        cached_summary_text = "This is a cached summary"
        cached_summary =
          SummarySection.find_by(target: topic, meta_section_id: nil).update!(
            summarized_text: cached_summary_text,
            updated_at: 24.hours.ago,
          )

        section = summarization.summarize(topic, user)
        expect(section.summarized_text).to eq(cached_summary_text)
      end
    end

    context "when the content was summarized in multiple chunks" do
      let(:summary) do
        {
          summary: "This is the final summary",
          chunks: [
            { ids: [topic.first_post.post_number], summary: "this is the first chunk" },
            { ids: [post_1.post_number, post_2.post_number], summary: "this is the second chunk" },
          ],
        }
      end

      it "caches the summary and each chunk" do
        section = summarization.summarize(topic, user)

        expect(section.summarized_text).to eq(summary[:summary])

        assert_summary_is_cached(topic, summary)

        summary[:chunks].each { |c| assert_chunk_is_cached(topic, c) }
      end
    end

    describe "invalidating cached summaries" do
      let(:cached_text) { "This is a cached summary" }
      let(:summarized_text) { "This is the final summary" }
      let(:summary) do
        {
          summary: summarized_text,
          chunks: [
            { ids: [topic.first_post.post_number], summary: "this is the first chunk" },
            { ids: [post_1.post_number, post_2.post_number], summary: "this is the second chunk" },
          ],
        }
      end

      def cached_summary
        SummarySection.find_by(target: topic, meta_section_id: nil)
      end

      before do
        summarization.summarize(topic, user)

        cached_summary.update!(summarized_text: cached_text, created_at: 24.hours.ago)
      end

      context "when the user can requests new summaries" do
        context "when there are no new posts" do
          it "returns the cached summary" do
            section = summarization.summarize(topic, user)

            expect(section.summarized_text).to eq(cached_text)
          end
        end

        context "when there are new posts" do
          before { cached_summary.update!(original_content_sha: "outdated_sha") }

          it "returns a new summary" do
            section = summarization.summarize(topic, user)

            expect(section.summarized_text).to eq(summarized_text)
          end

          context "when the cached summary is less than one hour old" do
            before { cached_summary.update!(created_at: 30.minutes.ago) }

            it "returns the cached summary" do
              cached_summary.update!(created_at: 30.minutes.ago)

              section = summarization.summarize(topic, user)

              expect(section.summarized_text).to eq(cached_text)
              expect(section.outdated).to eq(true)
            end

            it "returns a new summary if the skip_age_check flag is passed" do
              section = summarization.summarize(topic, user, skip_age_check: true)

              expect(section.summarized_text).to eq(summarized_text)
            end
          end
        end
      end
    end
  end
end
