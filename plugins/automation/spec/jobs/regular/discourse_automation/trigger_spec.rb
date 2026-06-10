# frozen_string_literal: true

describe Jobs::DiscourseAutomation::Trigger do
  fab!(:automation) { Fabricate(:automation, enabled: true, script: "recursion_depth_probe") }

  before do
    DiscourseAutomation::Scriptable.add("recursion_depth_probe") do
      script { DiscourseAutomation::CapturedContext.add(DiscourseAutomation.recursion_depth) }
    end
  end

  after { DiscourseAutomation::Scriptable.remove("recursion_depth_probe") }

  it "resumes the recursion depth inherited from the enqueuing thread" do
    list =
      capture_contexts do
        described_class.new.execute(automation_id: automation.id, context: {}, recursion_depth: 2)
      end

    expect(list).to eq([3])
    expect(DiscourseAutomation.recursion_depth).to eq(0)
  end

  it "runs at depth 1 when no recursion depth is given" do
    list =
      capture_contexts { described_class.new.execute(automation_id: automation.id, context: {}) }

    expect(list).to eq([1])
  end

  it "skips the script and logs an error when the depth limit is reached" do
    list = nil

    expect {
      list =
        capture_contexts do
          described_class.new.execute(
            automation_id: automation.id,
            context: {
            },
            recursion_depth: DiscourseAutomation::MAX_RECURSION_DEPTH,
          )
        end
    }.to change {
      DiscourseAutomation::Stat.where(automation_id: automation.id).sum(:total_errors)
    }.by(1)

    expect(list).to eq([])
  end
end
