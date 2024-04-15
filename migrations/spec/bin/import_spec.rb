# frozen_string_literal: true

RSpec.describe "Migrations::Import" do
  subject(:cli) do
    # rubocop:disable Discourse/NoChdir
    Dir.chdir("migrations") { system("bin/import", exception: true) }
    # rubocop:enable Discourse/NoChdir
  end

  it "works" do
    expect { cli }.to output(
      include("Importing into Discourse #{Discourse::VERSION::STRING}"),
    ).to_stdout_from_any_process
  end
end
