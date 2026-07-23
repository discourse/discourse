# frozen_string_literal: true

RSpec.describe TestSetup do
  describe ".test_setup" do
    it "does not update Discourse ID metadata while resetting site settings" do
      SiteSetting.title = "Test Forum"
      SiteSetting.discourse_id_client_id = "client-id"
      SiteSetting.discourse_id_client_secret = "client-secret"
      settings = SiteSetting.provider.all
      settings.sort_by! { |setting| setting.name.to_s == "title" ? 0 : 1 }
      SiteSetting.provider.stubs(:all).returns(settings)
      DiscourseId::Register.expects(:call).never

      described_class.test_setup
    end
  end
end
