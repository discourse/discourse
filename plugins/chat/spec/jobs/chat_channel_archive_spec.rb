# frozen_string_literal: true

require "rails_helper"

describe Jobs::ChatChannelArchive do
  fab!(:chat_channel) { Fabricate(:category_channel) }
  fab!(:user) { Fabricate(:user, admin: true) }
  fab!(:category) { Fabricate(:category) }
  fab!(:chat_archive) do
    Chat::ChannelArchive.create!(
      chat_channel: chat_channel,
      archived_by: user,
      destination_topic_title: "This will be the archive topic",
      destination_category_id: category.id,
      total_messages: 10,
    )
  end

  before { 10.times { Fabricate(:chat_message, chat_channel: chat_channel) } }

  def run_job
    described_class.new.execute(chat_channel_archive_id: chat_archive.id)
  end

  it "does nothing if the archive is already complete" do
    chat_channel.chat_messages.destroy_all
    chat_archive.update!(archived_messages: 10)
    expect { run_job }.not_to change { Topic.count }
  end

  it "does nothing if the archive does not exist" do
    chat_archive.destroy
    expect { run_job }.not_to change { Topic.count }
  end

  it "processes the archive" do
    Chat::ChannelArchiveService.any_instance.expects(:execute)
    run_job
  end
end
