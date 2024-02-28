# frozen_string_literal: true

RSpec.describe "Migrations::Import" do
  subject(:cli) { system("migrations/import", exception: true) }

  it "works" do
    expect { cli }.to output(
      include("Importing into Discourse #{Discourse::VERSION::STRING}"),
    ).to_stdout_from_any_process
  end
end
