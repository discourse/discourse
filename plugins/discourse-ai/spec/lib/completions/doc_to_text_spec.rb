# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::DocToText do
  after do
    if described_class.instance_variable_defined?(:@antiword_installed)
      described_class.remove_instance_variable(:@antiword_installed)
    end
  end

  it "returns nil when antiword is not installed" do
    allow(Discourse::Utils).to receive(:execute_command).with("which", "antiword").and_raise(
      Discourse::Utils::CommandError.new("missing antiword"),
    )

    allow(Discourse::SafeExec).to receive(:capture)

    expect(described_class.convert("/tmp/sample.doc")).to be_nil
    expect(Discourse::SafeExec).not_to have_received(:capture).with("antiword", any_args)
  end

  it "converts doc files with antiword" do
    tempfile = Tempfile.new(%w[sample .doc])
    tempfile.close

    allow(Discourse::Utils).to receive(:execute_command).with("which", "antiword").and_return(
      "/usr/bin/antiword\n",
    )
    allow(Discourse::SafeExec).to receive(:capture).with(
      "antiword",
      "-w",
      "0",
      tempfile.path,
      read: described_class.sandbox_read_paths(tempfile.path),
      execute: Discourse::SafeExec.default_execute_paths,
      timeout: described_class::ANTIWORD_TIMEOUT_SECONDS,
      env: described_class::SAFE_EXEC_ENV,
      unsetenv_others: true,
      rlimits: described_class::ANTIWORD_RLIMITS,
      seccomp_deny_network: true,
      max_output_bytes: described_class::MAX_CONVERSION_OUTPUT_BYTES,
      truncate_output: true,
      failure_message: "Failed to convert .doc upload to text",
    ).and_return("Converted document text\n")

    expect(described_class.convert(tempfile.path)).to eq("Converted document text\n")
  ensure
    tempfile&.close!
  end

  it "uses the real antiword binary when it is available" do
    skip "antiword is not installed" if !system("which antiword", out: File::NULL)

    tempfile = Tempfile.new(%w[invalid .doc])
    tempfile.write("not a real Word document")
    tempfile.close

    expect { described_class.convert(tempfile.path) }.to raise_error(Discourse::Utils::CommandError)
  ensure
    tempfile&.close!
  end
end
