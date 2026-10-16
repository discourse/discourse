# frozen_string_literal: true

RSpec.describe UserNotifications do
  describe "#user_private_message" do
    fab!(:admin)

    it "excludes internal notice metadata from staff notification emails" do
      SiteSetting.dsa_reporting_enabled = true
      params = {
        submission_id: SecureRandom.uuid,
        content_url: "https://example.com/t/reported/123",
        explanation:
          "The listing offers counterfeit goods with a claimed origin contradicted by its photographs",
        name: "Alex Morgan",
        email: "alex@example.com",
        anonymous: false,
        declaration: true,
      }
      notice = Dsa::SubmitNotice.call(params: { notice: params }).notice
      post = notice.post

      mail =
        described_class.user_private_message(
          admin,
          post:,
          notification_type: Notification.types[:private_message],
          notification_data_hash: {
            original_username: Discourse.system_user.username,
            original_post_id: post.id,
            original_post_type: post.post_type,
            topic_title: post.topic.title,
          },
        )

      expect(mail.text_part.decoded).to include(notice.reference, params[:explanation])
      expect(mail.text_part.decoded).not_to include(params[:submission_id])
      expect(mail.html_part.decoded).not_to include(params[:submission_id])
      expect(post.reload.raw).to include(params[:submission_id])
    end
  end
end
