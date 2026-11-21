# frozen_string_literal: true

describe DiscourseMcp::Tools::ListNotifications do
  fab!(:user)
  fab!(:topic_notification) { Fabricate(:notification, user:) }
  fab!(:chat_notification) do
    Fabricate(
      :notification,
      user:,
      topic: nil,
      notification_type: Notification.types[:chat_watched_thread],
    )
  end

  def listed_ids(scopes)
    request_context =
      instance_double(
        DiscourseMcp::RequestContext,
        user:,
        user_id: user.id,
        guardian: user.guardian,
      )
    allow(request_context).to receive(:has_scopes?) { |required| (Array(required) - scopes).empty? }

    described_class
      .call(arguments: {}, request_context:)
      .dig(:structuredContent, :notifications)
      .pluck(:id)
  end

  it "lists chat notifications only for tokens with the chat read scope" do
    expect(listed_ids(%w[chat:read])).to contain_exactly(
      topic_notification.id,
      chat_notification.id,
    )
    expect(listed_ids([])).to contain_exactly(topic_notification.id)
  end
end
