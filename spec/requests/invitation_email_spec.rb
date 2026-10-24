# frozen_string_literal: true

RSpec.describe "Invitation email rendering", type: :request do
  fab!(:inviter) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:invitee, :user)

  it "preserves literal title formatting in a customized invitation email" do
    title = 'Planning *notes* `draft` [agenda] (updated) \\ & <details>'
    pm = Fabricate(:private_message_topic, user: inviter, title: title)
    Fabricate(:post, topic: pm, user: inviter)
    invitee.user_option.update!(email_level: UserOption.email_level_types[:always])
    TranslationOverride.upsert!(
      SiteSetting.default_locale,
      "user_notifications.user_invited_to_private_message_pm.text_body_template",
      "Custom invitation\n\n%{message}",
    )
    ActionMailer::Base.deliveries.clear
    sign_in(inviter)

    post "/t/#{pm.id}/invite.json", params: { user: invitee.username }

    expect(response.status).to eq(200)
    notification =
      invitee.notifications.find_by!(
        topic: pm,
        notification_type: Notification.types[:invited_to_private_message],
      )
    Jobs::UserEmail.new.execute(
      NotificationEmailer::EmailUser.notification_params(
        notification,
        :user_invited_to_private_message,
      ),
    )

    email = ActionMailer::Base.deliveries.find { |mail| mail.to == [invitee.email] }
    expect(email).to be_present
    fragment = Nokogiri::HTML5.fragment(email.html_part.decoded)
    expect(fragment.text).to include("Custom invitation")
    expect(fragment.css("a[href='#{pm.url}']").map(&:text)).to include(title)
  end
end
