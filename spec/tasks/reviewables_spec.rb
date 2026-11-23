# frozen_string_literal: true

describe "reviewables:mass-handle" do
  fab!(:admin)
  fab!(:spammer, :user)
  fab!(:spam_reviewables) do
    Array.new(2) do
      Fabricate(
        :reviewable_flagged_post,
        target_created_by: spammer,
        target: Fabricate(:post, user: spammer),
        potential_spam: true,
      )
    end
  end

  def run_task(action_id)
    STDIN.stubs(:readline).returns("#{ReviewableFlaggedPost.pending.count}\n")
    capture_stdout do
      invoke_rake_task(
        "reviewables:mass-handle",
        "ReviewableFlaggedPost",
        admin.username,
        action_id,
      )
    end
  end

  it "performs aliased actions and skips reviewables resolved earlier in the run" do
    spammer_id = spammer.id

    output = run_task("delete_user_block")

    expect(User.exists?(spammer_id)).to eq(false)
    expect(spam_reviewables.map { |reviewable| reviewable.reload.status }).to all(eq("approved"))
    expect(output).to include(
      "1 records have been processed successfully, 1 were already resolved and 0 failed.",
    )
  end

  it "rejects unknown actions" do
    expect { run_task("not_a_real_action") }.to raise_error(
      RuntimeError,
      'ReviewableFlaggedPost doesn\'t support an action with the name :not_a_real_action.',
    )
  end
end
