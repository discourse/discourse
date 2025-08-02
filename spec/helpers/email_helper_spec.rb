# frozen_string_literal: true

RSpec.describe EmailHelper do
  describe "#email_topic_link" do
    it "respects subfolder" do
      set_subfolder "/forum"
      topic = Fabricate(:topic)
      expect(helper.email_topic_link(topic)).to include("#{Discourse.base_url_no_prefix}/forum/t")
    end
  end
end
