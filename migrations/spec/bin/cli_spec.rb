# frozen_string_literal: true

RSpec.describe "Migrations::Import" do
  def run_command(command = "")
    # rubocop:disable Discourse/NoChdir
    Dir.chdir("migrations") { system("bin/cli #{command}", exception: true) }
    # rubocop:enable Discourse/NoChdir
  end

  it "works" do
    expect { run_command("import") }.to output(
      include("Importing into Discourse #{Discourse::VERSION::STRING}"),
    ).to_stdout_from_any_process
  end
end
