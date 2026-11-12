# frozen_string_literal: true

describe "admin_dashboard:rebuild_rollups" do
  it "rebuilds every rollup when no name is given" do
    DashboardRollupRebuilder.expects(:rebuild!).with(nil)

    capture_stdout { invoke_rake_task("admin_dashboard:rebuild_rollups") }
  end

  it "rebuilds only the named rollup" do
    DashboardRollupRebuilder.expects(:rebuild!).with("category_activity")

    capture_stdout { invoke_rake_task("admin_dashboard:rebuild_rollups", "category_activity") }
  end

  it "aborts on an unknown rollup name" do
    DashboardRollupRebuilder.expects(:rebuild!).never

    expect { capture_stdout { invoke_rake_task("admin_dashboard:rebuild_rollups", "nope") } }.to(
      raise_error(SystemExit),
    )
  end
end
