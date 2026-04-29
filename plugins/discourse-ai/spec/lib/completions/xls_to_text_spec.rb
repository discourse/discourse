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

    expect(described_class.convert("/tmp/sample.xls")).to be_nil
    expect(Discourse::Utils).not_to have_received(:execute_command).with("xls2csv", any_args)
  end

  it "converts xls files with xls2csv" do
    allow(Discourse::Utils).to receive(:execute_command).with("which", "xls2csv").and_return(
      "/usr/bin/xls2csv\n",
    )
    allow(Discourse::Utils).to receive(:execute_command).with(
      "xls2csv",
      "/tmp/sample.xls",
      timeout: described_class::XLS2CSV_TIMEOUT_SECONDS,
      failure_message: "Failed to convert .xls upload to text",
    ).and_return("Name,Value\nAlice,1\n")

    expect(described_class.convert("/tmp/sample.xls")).to eq("Name,Value\nAlice,1\n")
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
