# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::NodeErrorHandling do
  subject(:handler) { Class.new { include DiscourseWorkflows::NodeErrorHandling }.new }

  it "keeps the location out of the error's summary", :aggregate_failures do
    expect {
      handler.send(
        :raise_node_error!,
        "Boom",
        description: "details",
        item_index: 2,
        line_number: 4,
      )
    }.to raise_error(DiscourseWorkflows::NodeError) { |error|
      expect(error.message).to eq("Boom [line 4, for item 2]: details")
      expect(error.summary).to eq("Boom: details")
    }
  end
end
