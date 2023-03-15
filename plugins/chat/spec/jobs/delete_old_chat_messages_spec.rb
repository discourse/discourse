# frozen_string_literal: true

require "rails_helper"

describe Jobs::ChatDeleteOldMessages do
  base_date = DateTime.parse("2020-12-01 00:00 UTC")

  fab!(:public_channel) { Fabricate(:category_channel) }
  fab!(:public_days_old_0) do
    Fabricate(:chat_message, chat_channel: public_channel, message: "hi", created_at: base_date)
  end
  fab!(:public_days_old_10) do
    Fabricate(
      :chat_message,
      chat_channel: public_channel,
      message: "hi",
      created_at: base_date - 10.days - 1.second,
    )
  end
  fab!(:public_days_old_20) do
    Fabricate(
      :chat_message,
      chat_channel: public_channel,
      message: "hi",
      created_at: base_date - 20.days - 1.second,
    )
  end
  fab!(:public_days_old_30) do
    Fabricate(
      :chat_message,
      chat_channel: public_channel,
      message: "hi",
      created_at: base_date - 30.days - 1.second,
    )
  end
  fab!(:public_trashed_days_old_30) do
    Fabricate(
      :chat_message,
      chat_channel: public_channel,
      message: "hi",
      created_at: base_date - 30.days - 1.second,
    )
  end

  fab!(:dm_channel) { Fabricate(:direct_message_channel, users: [Fabricate(:user)]) }
  fab!(:dm_days_old_0) do
    Fabricate(:chat_message, chat_channel: dm_channel, message: "hi", created_at: base_date)
  end
  fab!(:dm_days_old_10) do
    Fabricate(
      :chat_message,
      chat_channel: dm_channel,
      message: "hi",
      created_at: base_date - 10.days - 1.second,
    )
  end
  fab!(:dm_days_old_20) do
    Fabricate(
      :chat_message,
      chat_channel: dm_channel,
      message: "hi",
      created_at: base_date - 20.days - 1.second,
    )
  end
  fab!(:dm_days_old_30) do
    Fabricate(
      :chat_message,
      chat_channel: dm_channel,
      message: "hi",
      created_at: base_date - 30.days - 1.second,
    )
  end
  fab!(:dm_trashed_days_old_30) do
    Fabricate(
      :chat_message,
      chat_channel: dm_channel,
      message: "hi",
      created_at: base_date - 30.days - 1.second,
    )
  end

  before { freeze_time(base_date) }

  it "doesn't delete messages when settings are 0" do
    SiteSetting.chat_channel_retention_days = 0
    SiteSetting.chat_dm_retention_days = 0

    expect { described_class.new.execute }.not_to change { Chat::Message.count }
  end

  describe "public channels" do
    it "deletes public messages correctly" do
      SiteSetting.chat_channel_retention_days = 20
      described_class.new.execute
      expect(public_days_old_0.deleted_at).to be_nil
      expect(public_days_old_10.deleted_at).to be_nil
      expect { public_days_old_20 }.to raise_exception(ActiveRecord::RecordNotFound)
      expect { public_days_old_30 }.to raise_exception(ActiveRecord::RecordNotFound)
    end

    it "deletes trashed messages correctly" do
      SiteSetting.chat_channel_retention_days = 20
      public_trashed_days_old_30.trash!
      described_class.new.execute
      expect { public_trashed_days_old_30.reload }.to raise_exception(ActiveRecord::RecordNotFound)
    end

    it "does nothing when no messages fall in the time range" do
      SiteSetting.chat_channel_retention_days = 800
      expect { described_class.new.execute }.not_to change { Chat::Message.in_public_channel.count }
    end
  end

  describe "dm channels" do
    it "deletes public messages correctly" do
      SiteSetting.chat_dm_retention_days = 20
      described_class.new.execute
      expect(dm_days_old_0.deleted_at).to be_nil
      expect(dm_days_old_10.deleted_at).to be_nil
      expect { dm_days_old_20 }.to raise_exception(ActiveRecord::RecordNotFound)
      expect { dm_days_old_30 }.to raise_exception(ActiveRecord::RecordNotFound)
    end

    it "deletes trashed messages correctly" do
      SiteSetting.chat_dm_retention_days = 20
      dm_trashed_days_old_30.trash!
      described_class.new.execute
      expect { dm_trashed_days_old_30.reload }.to raise_exception(ActiveRecord::RecordNotFound)
    end

    it "does nothing when no messages fall in the time range" do
      SiteSetting.chat_dm_retention_days = 800
      expect { described_class.new.execute }.not_to change { Chat::Message.in_dm_channel.count }
    end
  end
end
