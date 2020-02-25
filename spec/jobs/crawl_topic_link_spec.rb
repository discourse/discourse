# frozen_string_literal: true

require 'rails_helper'

describe Jobs::CrawlTopicLink do

  let(:job) { Jobs::CrawlTopicLink.new }

  it "needs a topic_link_id" do
    expect { job.execute({}) }.to raise_error(Discourse::InvalidParameters)
  end
end
