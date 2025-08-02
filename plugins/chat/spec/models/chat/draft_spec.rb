# frozen_string_literal: true

RSpec.describe Chat::Draft do
  before { SiteSetting.max_chat_draft_length = 100 }

  it "errors when data.value is greater than `max_chat_draft_length`" do
    draft =
      described_class.create(
        user_id: Fabricate(:user).id,
        chat_channel_id: Fabricate(:chat_channel).id,
        data: { value: "A" * (SiteSetting.max_chat_draft_length + 1) }.to_json,
      )

    expect(draft.errors.full_messages).to eq(
      [I18n.t("chat.errors.draft_too_long", { maximum: SiteSetting.max_chat_draft_length })],
    )
  end
end
