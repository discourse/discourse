# frozen_string_literal: true

RSpec.describe DiscourseAi::Decisions::Endpoints::Base do
  before { enable_current_plugin }

  describe ".for" do
    it "dispatches each provider to its dedicated endpoint" do
      {
        "system_one" => DiscourseAi::Decisions::Endpoints::SystemOne,
        "typesafe" => DiscourseAi::Decisions::Endpoints::Typesafe,
        "open_ai" => DiscourseAi::Decisions::Endpoints::OpenAi,
      }.each do |provider, endpoint_class|
        model = Fabricate.build(:decision_model, provider:)
        expect(described_class.for(model)).to be_an_instance_of(endpoint_class)
      end
    end

    it "rejects unknown providers" do
      model = Fabricate.build(:decision_model, provider: "unknown")
      expect { described_class.for(model) }.to raise_error(DiscourseAi::Decisions::InvalidRequest)
    end
  end
end
