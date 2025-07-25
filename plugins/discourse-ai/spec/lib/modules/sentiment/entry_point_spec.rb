# frozen_string_literal: true

require_relative "../../../support/sentiment_inference_stubs"

RSpec.describe DiscourseAi::Sentiment::EntryPoint do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }

  before { enable_current_plugin }

  describe "registering event callbacks" do
    context "when editing a post" do
      fab!(:post) { Fabricate(:post, user: user) }
      let(:revisor) { PostRevisor.new(post) }

      it "queues a job on update if sentiment analysis is enabled" do
        SiteSetting.ai_sentiment_enabled = true

        expect { revisor.revise!(user, raw: "This is my new test") }.to change(
          Jobs::PostSentimentAnalysis.jobs,
          :size,
        ).by(1)
      end

      it "does nothing if sentiment analysis is disabled" do
        SiteSetting.ai_sentiment_enabled = false

        expect { revisor.revise!(user, raw: "This is my new test") }.not_to change(
          Jobs::PostSentimentAnalysis.jobs,
          :size,
        )
      end
    end
  end

  describe "custom reports" do
    before do
      SiteSetting.ai_sentiment_model_configs =
        "[{\"model_name\":\"SamLowe/roberta-base-go_emotions\",\"endpoint\":\"http://samlowe-emotion.com\",\"api_key\":\"123\"},{\"model_name\":\"j-hartmann/emotion-english-distilroberta-base\",\"endpoint\":\"http://jhartmann-emotion.com\",\"api_key\":\"123\"},{\"model_name\":\"cardiffnlp/twitter-roberta-base-sentiment-latest\",\"endpoint\":\"http://cardiffnlp-sentiment.com\",\"api_key\":\"123\"}]"
    end

    fab!(:pm) { Fabricate(:private_message_post) }

    fab!(:post_1) { Fabricate(:post) }
    fab!(:post_2) { Fabricate(:post) }

    describe "overall_sentiment report" do
      let(:positive_classification) { { negative: 0.2, neutral: 0.3, positive: 0.7 } }
      let(:negative_classification) { { negative: 0.65, neutral: 0.2, positive: 0.1 } }

      def sentiment_classification(post, classification)
        Fabricate(:sentiment_classification, target: post, classification: classification)
      end

      it "calculate averages using only public posts" do
        sentiment_classification(post_1, positive_classification)
        sentiment_classification(post_2, negative_classification)
        sentiment_classification(pm, positive_classification)

        report = Report.find("overall_sentiment")
        overall_sentiment = report.data[0][:data][0][:y].to_i
        expect(overall_sentiment).to eq(0)
      end

      it "exports the report without any errors" do
        sentiment_classification(post_1, positive_classification)
        sentiment_classification(post_2, negative_classification)
        sentiment_classification(pm, positive_classification)

        exporter = Jobs::ExportCsvFile.new
        exporter.entity = "report"
        exporter.extra = HashWithIndifferentAccess.new(name: "overall_sentiment")
        exported_csv = []
        exporter.report_export { |entry| exported_csv << entry }
        expect(exported_csv[0]).to eq(["Day", "Overall sentiment (Positive - Negative)"])
        expect(exported_csv[1]).to eq([post_1.created_at.to_date.to_s, "0"])
      end
    end

    describe "post_emotion report" do
      let(:emotion_1) do
        {
          love: 0.9444406,
          admiration: 0.013724019,
          surprise: 0.010188869,
          excitement: 0.007888741,
          curiosity: 0.006301749,
          joy: 0.004060776,
          confusion: 0.0028238264,
          approval: 0.0018160914,
          realization: 0.001174849,
          neutral: 0.0008561869,
          amusement: 0.00075853954,
          disapproval: 0.0006987994,
          disappointment: 0.0006166883,
          anger: 0.0006000542,
          annoyance: 0.0005615011,
          desire: 0.00046368592,
          fear: 0.00045117878,
          sadness: 0.00041727215,
          gratitude: 0.00041727215,
          optimism: 0.00037112957,
          disgust: 0.00035552034,
          nervousness: 0.00022954118,
          embarrassment: 0.0002049572,
          caring: 0.00017737568,
          remorse: 0.00011407586,
          grief: 0.0001006716,
          pride: 0.00009681493,
          relief: 0.00008919009,
        }
      end
      let(:emotion_2) do
        {
          love: 0.8444406,
          admiration: 0.113724019,
          surprise: 0.010188869,
          excitement: 0.007888741,
          curiosity: 0.006301749,
          joy: 0.004060776,
          confusion: 0.0028238264,
          approval: 0.0018160914,
          realization: 0.001174849,
          neutral: 0.0008561869,
          amusement: 0.00075853954,
          disapproval: 0.0006987994,
          disappointment: 0.0006166883,
          anger: 0.0006000542,
          annoyance: 0.0005615011,
          desire: 0.00046368592,
          fear: 0.00045117878,
          sadness: 0.00041727215,
          gratitude: 0.00041727215,
          optimism: 0.00037112957,
          disgust: 0.00035552034,
          nervousness: 0.00022954118,
          embarrassment: 0.0002049572,
          caring: 0.00017737568,
          remorse: 0.00011407586,
          grief: 0.0001006716,
          pride: 0.00009681493,
          relief: 0.00008919009,
        }
      end
      let(:model_used) { "SamLowe/roberta-base-go_emotions" }

      def emotion_classification(post, classification)
        Fabricate(
          :sentiment_classification,
          target: post,
          model_used: model_used,
          classification: classification,
        )
      end

      def strip_emoji_and_downcase(str)
        stripped_str = str.gsub(/[^\p{L}\p{N}]+/, "") # remove any non-alphanumeric characters
        stripped_str.downcase
      end

      it "calculate averages using only public posts" do
        threshold = 0.10

        emotion_classification(post_1, emotion_1)
        emotion_classification(post_2, emotion_2)
        emotion_classification(pm, emotion_2)

        report = Report.find("emotion_love")

        data_point = report.data

        data_point.each do |point|
          expected = (emotion_1[:love] > threshold ? 1 : 0) + (emotion_2[:love] > threshold ? 1 : 0)
          expect(point[:y]).to eq(expected)
        end
      end
    end
  end
end
