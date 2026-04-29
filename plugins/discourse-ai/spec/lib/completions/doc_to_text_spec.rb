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

    expect(described_class.convert("/tmp/sample.doc")).to be_nil
    expect(Discourse::Utils).not_to have_received(:execute_command).with("antiword", any_args)
  end

  it "converts doc files with antiword" do
    allow(Discourse::Utils).to receive(:execute_command).with("which", "antiword").and_return(
      "/usr/bin/antiword\n",
    )
    allow(Discourse::Utils).to receive(:execute_command).with(
      "antiword",
      "-w",
      "0",
      "/tmp/sample.doc",
      timeout: described_class::ANTIWORD_TIMEOUT_SECONDS,
      failure_message: "Failed to convert .doc upload to text",
    ).and_return("Converted document text\n")

    expect(described_class.convert("/tmp/sample.doc")).to eq("Converted document text\n")
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
