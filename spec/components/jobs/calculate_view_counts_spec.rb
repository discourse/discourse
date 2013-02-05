require 'spec_helper'
require 'jobs'

describe Jobs::CalculateViewCounts do


  it "delegates to User" do
    User.expects(:update_view_counts)
    Jobs::CalculateViewCounts.new.execute({})
  end

end