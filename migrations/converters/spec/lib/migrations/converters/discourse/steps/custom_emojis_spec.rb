# frozen_string_literal: true

RSpec.describe Migrations::Converters::Discourse::CustomEmojis do
  subject(:processor) { described_class.processor_class.new({}) }

  include_context "with intermediate database"

  before { processor.setup }

  it "registers the emoji's upload and stores the returned reference" do
    path = "/uploads/default/original/1X/parrot.png"
    processor.process(
      {
        id: 5,
        name: "parrot",
        group: "animals",
        user_id: 42,
        upload_url: path,
        upload_filename: "parrot.png",
        upload_origin: nil,
        created_at: Time.utc(2020, 1, 2, 3, 4, 5),
      },
    )

    upload_id = Migrations::ID.hash(path)
    expect(rows("uploads")).to contain_exactly(
      hash_including(id: upload_id, path:, filename: "parrot.png", type: "custom_emoji"),
    )
    expect(rows("custom_emojis")).to contain_exactly(
      hash_including(original_id: 5, name: "parrot", group: "animals", user_id: 42, upload_id:),
    )
  end

  it "warns and skips an emoji whose upload is missing, but converts the rest" do
    processor.process(
      {
        id: 7,
        name: "orphan",
        group: nil,
        upload_url: nil,
        upload_filename: nil,
        upload_origin: nil,
        created_at: Time.utc(2020, 1, 2, 3, 4, 5),
      },
    )
    processor.process(
      {
        id: 8,
        name: "smile",
        group: nil,
        upload_url: "/uploads/s.png",
        upload_filename: "s.png",
        upload_origin: nil,
        created_at: Time.utc(2020, 1, 2, 3, 4, 5),
      },
    )

    expect(processor.tracker.stats.warning_count).to eq(1)
    expect(rows("custom_emojis")).to contain_exactly(hash_including(original_id: 8, name: "smile"))
  end

  it "keeps a nil group for an ungrouped emoji" do
    processor.process(
      {
        id: 6,
        name: "smile",
        group: nil,
        upload_url: "/uploads/s.png",
        upload_filename: "s.png",
        upload_origin: nil,
      },
    )

    expect(rows("custom_emojis")).to contain_exactly(
      hash_including(original_id: 6, group: nil, user_id: nil),
    )
  end
end
