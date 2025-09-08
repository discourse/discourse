# frozen_string_literal: true

class SentimentInferenceStubs
  class << self
    def model_response(model)
      case model
      when "SamLowe/roberta-base-go_emotions"
        [
          { score: 0.90261286, label: "anger" },
          { score: 0.04127813, label: "annoyance" },
          { score: 0.03183503, label: "neutral" },
          { score: 0.005037033, label: "disgust" },
          { score: 0.0031153716, label: "disapproval" },
          { score: 0.0019118421, label: "disappointment" },
          { score: 0.0015849728, label: "sadness" },
          { score: 0.0012343781, label: "curiosity" },
          { score: 0.0010682651, label: "amusement" },
          { score: 0.00100747, label: "confusion" },
          { score: 0.0010035422, label: "admiration" },
          { score: 0.0009957326, label: "approval" },
          { score: 0.0009726665, label: "surprise" },
          { score: 0.0007754773, label: "realization" },
          { score: 0.0006978541, label: "love" },
          { score: 0.00064793555, label: "fear" },
          { score: 0.0006454095, label: "optimism" },
          { score: 0.0005969062, label: "joy" },
          { score: 0.0005498958, label: "embarrassment" },
          { score: 0.00050068577, label: "excitement" },
          { score: 0.00047403979, label: "caring" },
          { score: 0.00038841428, label: "gratitude" },
          { score: 0.00034546282, label: "desire" },
          { score: 0.00023012784, label: "grief" },
          { score: 0.00018133638, label: "remorse" },
          { score: 0.00012511834, label: "nervousness" },
          { score: 0.00012079607, label: "pride" },
          { score: 0.000063159685, label: "relief" },
        ]
      when "cardiffnlp/twitter-roberta-base-sentiment-latest"
        [
          { score: 0.627579, label: "negative" },
          { score: 0.29482335, label: "neutral" },
          { score: 0.07759768, label: "positive" },
        ]
      when "j-hartmann/emotion-english-distilroberta-base"
        [
          { score: 0.7033674, label: "anger" },
          { score: 0.2701151, label: "disgust" },
          { score: 0.009492096, label: "sadness" },
          { score: 0.0080775, label: "neutral" },
          { score: 0.0049473303, label: "fear" },
          { score: 0.0023369535, label: "surprise" },
          { score: 0.001663634, label: "joy" },
        ]
      else
        [
          { score: 0.1, label: "label 1" },
          { score: 0.2, label: "label 2" },
          { score: 0.3, label: "label 3" },
        ]
      end
    end

    def stub_classification(post)
      content = post.post_number == 1 ? "#{post.topic.title}\n#{post.raw}" : post.raw

      DiscourseAi::Sentiment::SentimentSiteSettingJsonSchema.values.each do |model_config|
        WebMock
          .stub_request(:post, model_config.endpoint)
          .with(body: JSON.dump(inputs: content, truncate: true))
          .to_return(status: 200, body: JSON.dump(model_response(model_config.model_name)))
      end
    end
  end
end
