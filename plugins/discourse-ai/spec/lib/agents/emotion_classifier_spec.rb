# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::EmotionClassifier do
  subject(:agent) { described_class.new }

  before { enable_current_plugin }

  describe "#system_prompt" do
    it "describes probability score constraints" do
      prompt = agent.system_prompt

      expect(prompt).to include("float from 0 to 1")
      expect(prompt).to include("sum to 1.0")
    end
  end

  describe "#examples" do
    it "uses valid emotion probability distributions" do
      labels = DiscourseAi::Sentiment::Emotions::LIST

      agent.examples.each do |_input, output|
        parsed_output = JSON.parse(output)

        expect(parsed_output.keys).to contain_exactly(*labels)
        expect(parsed_output.values.sum).to be_within(0.001).of(1.0)
      end
    end
  end
end
