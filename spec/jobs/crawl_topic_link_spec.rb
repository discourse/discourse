require 'spec_helper'
require_dependency 'jobs/base'
require_dependency 'jobs/regular/crawl_topic_link'

describe Jobs::CrawlTopicLink do

  let(:job) { Jobs::CrawlTopicLink.new }

  it "needs a topic_link_id" do
    -> { job.execute({}) }.should raise_error(Discourse::InvalidParameters)
  end
end
