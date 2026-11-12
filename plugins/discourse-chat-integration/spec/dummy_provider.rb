# frozen_string_literal: true

RSpec.shared_context "with dummy provider" do
  before(:each) do
    module DiscourseChatIntegration::Provider::DummyProvider
      PROVIDER_NAME = "dummy"
      # Fake site settings come from the spec/support/dummy_plugin_site_settings.yml file
      PROVIDER_ENABLED_SETTING = :dummy_provider_enabled
      POPULARITY_SCORE = 5
      CHANNEL_PARAMETERS = []

      @@sent_messages = []
      @@raise_exception = nil

      def self.trigger_notification(post, channel, rule)
        raise @@raise_exception if @@raise_exception

        @@sent_messages.push(post: post.id, channel: channel)
      end

      def self.sent_messages
        @@sent_messages
      end

      def self.sent_to_channel_ids
        @@sent_messages.map { |x| x[:channel].id }
      end

      def self.set_raise_exception(bool)
        @@raise_exception = bool
      end
    end
  end

  after(:each) { DiscourseChatIntegration::Provider.send(:remove_const, :DummyProvider) }

  let(:provider) { DiscourseChatIntegration::Provider::DummyProvider }
end

RSpec.shared_context "with validated dummy provider" do
  before(:each) do
    module DiscourseChatIntegration::Provider::Dummy2Provider
      PROVIDER_NAME = "dummy2"
      # Fake site settings come from the spec/support/dummy_plugin_site_settings.yml file
      PROVIDER_ENABLED_SETTING = :other_dummy_provider_enabled
      CHANNEL_IDENTIFIER_KEY = "val"
      POPULARITY_SCORE = 5
      CHANNEL_PARAMETERS = [{ key: "val", regex: '^\S+$', unique: true }]

      @@sent_messages = []

      def self.trigger_notification(post, channel, rule)
        @@sent_messages.push(post: post.id, channel: channel)
      end

      def self.sent_messages
        @@sent_messages
      end

      def self.get_channel_by_name(name)
        DiscourseChatIntegration::Channel
          .with_provider(PROVIDER_NAME)
          .with_data_value(CHANNEL_IDENTIFIER_KEY, name)
          .first
      end
    end
  end

  after(:each) { DiscourseChatIntegration::Provider.send(:remove_const, :Dummy2Provider) }

  let(:validated_provider) { DiscourseChatIntegration::Provider::Dummy2Provider }
end
