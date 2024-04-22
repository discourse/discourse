# frozen_string_literal: true

describe "nested jobs" do
  before { Jobs.run_immediately! }

  it "works" do
    puts "Starting spec"
    Jobs.enqueue(:outer_job)
    puts "Done spec"
  end
end
