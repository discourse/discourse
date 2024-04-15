# frozen_string_literal: true

RSpec.describe AdminPluginSerializer do
  subject(:serializer) { described_class.new(instance) }

  let(:instance) { Plugin::Instance.new }

  describe "enabled_setting" do
    it "should return the right value" do
      instance.enabled_site_setting("test")
      expect(serializer.enabled_setting).to eq("test")
    end
  end

  describe "commit_hash" do
    it "should return commit_hash and commit_url" do
      instance = Plugin::Instance.find_all("#{Rails.root}/spec/fixtures/plugins")[0]
      subject = described_class.new(instance)

      git_repo = instance.git_repo
      git_repo.stubs(:latest_local_commit).returns("123456")
      git_repo.stubs(:url).returns("http://github.com/discourse/discourse-plugin")

      expect(subject.commit_hash).to eq("123456")
      expect(subject.commit_url).to eq("http://github.com/discourse/discourse-plugin/commit/123456")
    end
  end
end
