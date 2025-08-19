# frozen_string_literal: true

describe "destroy:posts" do
  it "accepts a list of post IDs piped through STDIN" do
    destroy_task = instance_spy(DestroyTask)
    DestroyTask.stubs(:new).returns(destroy_task)

    STDIN.stubs(:read).returns("1,2,3\n")

    capture_stdout do
      invoke_rake_task("destroy:posts")

      expect(destroy_task).to have_received(:destroy_posts).with(%w[1 2 3])
    end
  end
end
