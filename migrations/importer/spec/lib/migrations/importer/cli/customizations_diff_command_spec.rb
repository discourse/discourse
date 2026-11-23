# frozen_string_literal: true

RSpec.describe Migrations::Importer::CLI::CustomizationsCommands::DiffCommand do
  it "doesn't need Rails" do
    expect(described_class.requires_rails?).to be(false)
  end

  it "accepts repeated --where options" do
    command =
      described_class.new(
        [
          "--where",
          "user_avatars=user_id < 0",
          "--before",
          "dbname=a",
          "--where",
          "groups=id = 1",
          "--only",
          "groups,user_avatars",
          "--after",
          "dbname=b",
        ],
      )

    expect(command.row_filters).to eq("user_avatars" => "user_id < 0", "groups" => "id = 1")
    expect(command.options).to include(
      before: "dbname=a",
      after: "dbname=b",
      only: %w[groups user_avatars],
    )
  end

  it "rejects --where without a condition" do
    command = described_class.new(%w[--where groups])
    expect { command.row_filters }.to raise_error(Migrations::Importer::Customizations::Error)
  end
end
