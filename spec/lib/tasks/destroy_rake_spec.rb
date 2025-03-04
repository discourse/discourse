# frozen_string_literal: true

describe "destroy:posts" do # rubocop:disable RSpec/DescribeClass
  subject(:task) { subject }

  include_context "in a rake task"

  # No console output in test suite, thanks.
  before { STDOUT.stubs(:puts) }

  it "accepts a list of post IDs piped through STDIN" do
    destroy_task = instance_spy(DestroyTask)
    DestroyTask.stubs(:new).returns(destroy_task)

    STDIN.stubs(:read).returns("1,2,3\n")

    task.invoke

    expect(destroy_task).to have_received(:destroy_posts).with(%w[1 2 3])
  end
end
