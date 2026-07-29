# frozen_string_literal: true

module PersonalMessageSearchFixture
  def create_pm(users:, group: nil)
    private_message = Fabricate(:private_message_post_one_user, user: users.first).topic
    users[1..].each do |user|
      private_message.invite(users.first, user.username)
      Fabricate(:post, user:, topic: private_message)
    end
    if group
      private_message.invite_group(users.first, group)
      group.users.each { |user| Fabricate(:post, user:, topic: private_message) }
    end
    private_message.reload
  end
end
