# frozen_string_literal: true

RSpec.describe "::Migrations::Import" do
  def run_command(command = "")
    workdir = Rails.root.join("migrations")
    system("bin/cli #{command}", exception: true, chdir: workdir)
  end

  it "works" do
    expect { run_command("import") }.to output(
      include("Importing into Discourse #{Discourse::VERSION::STRING}"),
    ).to_stdout_from_any_process.and output(be_empty).to_stderr_from_any_process
  end
end
