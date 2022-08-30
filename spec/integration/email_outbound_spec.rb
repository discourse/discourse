# frozen_string_literal: true

# We already have Email::Sender and Email::MessageBuilder specs along
# with mailer specific mailer specs like UserEmail, but sometimes we need
# to test things along the whole outbound flow including the MessageBuilder
# and the Sender.
RSpec.describe "Outbound Email" do
  def send_email(opts = {})
    message = TestMailer.send_test("test@test.com", opts)
    result = Email::Sender.new(message, :test_message).send
    [message, result]
  end

  describe "email custom headers" do
    it "discards the custom header if it is one that has already been set based on arguments" do
      SiteSetting.email_custom_headers = "Precedence: bulk"
      post = Fabricate(:post)
      message, result = send_email(post_id: post.id, topic_id: post.topic_id)
      expect(message.header["Precedence"].value).to eq("list")
    end

    it "does send unique custom headers" do
      SiteSetting.email_custom_headers = "SuperUrgent: wow-cool"
      post = Fabricate(:post)
      message, result = send_email(post_id: post.id, topic_id: post.topic_id)
      expect(message.header["SuperUrgent"].value).to eq("wow-cool")
    end
  end
end
