# frozen_string_literal: true

RSpec.describe Jobs::CheckTranslationOverrides do
  fab!(:up_to_date_translation) { Fabricate(:translation_override, translation_key: "title") }
  fab!(:deprecated_translation) { Fabricate(:translation_override, translation_key: "foo.bar") }
  fab!(:outdated_translation) do
    Fabricate(:translation_override, translation_key: "posts", original_translation: "outdated")
  end
  fab!(:invalid_translation) { Fabricate(:translation_override, translation_key: "topics") }

  it "marks translations with keys which no longer exist in the locale file" do
    expect { described_class.new.execute({}) }.to change {
      deprecated_translation.reload.status
    }.from("up_to_date").to("deprecated")
  end

  it "marks translations with invalid interpolation keys" do
    invalid_translation.update_attribute("value", "Invalid %{foo}")

    expect { described_class.new.execute({}) }.to change { invalid_translation.reload.status }.from(
      "up_to_date",
    ).to("invalid_interpolation_keys")
  end

  it "marks translations that are outdated" do
    expect { described_class.new.execute({}) }.to change {
      outdated_translation.reload.status
    }.from("up_to_date").to("outdated")
  end

  it "does not mark up to date translations" do
    expect { described_class.new.execute({}) }.not_to change {
      up_to_date_translation.reload.status
    }
  end
end
