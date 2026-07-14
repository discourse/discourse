# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::XlsToText do
  after do
    if described_class.instance_variable_defined?(:@xls2csv_installed)
      described_class.remove_instance_variable(:@xls2csv_installed)
    end
  end

  it "returns nil when xls2csv is not installed" do
    allow(Discourse::Utils).to receive(:execute_command).with("which", "xls2csv").and_raise(
      Discourse::Utils::CommandError.new("missing xls2csv"),
    )

    allow(Discourse::SafeExec).to receive(:capture)

    expect(described_class.convert("/tmp/sample.xls")).to be_nil
    expect(Discourse::SafeExec).not_to have_received(:capture).with("xls2csv", any_args)
  end

  it "converts xls files with xls2csv" do
    tempfile = Tempfile.new(%w[sample .xls])
    tempfile.close

    allow(Discourse::Utils).to receive(:execute_command).with("which", "xls2csv").and_return(
      "/usr/bin/xls2csv\n",
    )
    allow(Discourse::SafeExec).to receive(:capture).with(
      "xls2csv",
      tempfile.path,
      read: described_class.sandbox_read_paths(tempfile.path),
      execute: Discourse::SafeExec.default_execute_paths,
      timeout: described_class::XLS2CSV_TIMEOUT_SECONDS,
      env: described_class::SAFE_EXEC_ENV,
      unsetenv_others: true,
      rlimits: described_class::XLS2CSV_RLIMITS,
      seccomp_deny_network: true,
      max_output_bytes: described_class::MAX_CONVERSION_OUTPUT_BYTES,
      truncate_output: true,
      failure_message: "Failed to convert .xls upload to text",
    ).and_return("Name,Value\nAlice,1\n")

    expect(described_class.convert(tempfile.path)).to eq("Name,Value\nAlice,1\n")
  ensure
    tempfile&.close!
  end

  it "uses the real xls2csv binary when it is available" do
    skip "xls2csv is not installed" if !system("which xls2csv", out: File::NULL)

    tempfile = Tempfile.new(%w[invalid .xls])
    tempfile.binmode
    tempfile.write("not a real Excel document")
    tempfile.close

    expect(described_class.convert(tempfile.path)).to eq("")
  ensure
    tempfile&.close!
  end
end
