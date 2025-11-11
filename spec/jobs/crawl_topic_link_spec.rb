# frozen_string_literal: true

RSpec.describe Jobs::CrawlTopicLink do
  subject(:job) { described_class.new }

  it "needs a topic_link_id" do
    expect { job.execute({}) }.to raise_error(Discourse::InvalidParameters)
  end
end
