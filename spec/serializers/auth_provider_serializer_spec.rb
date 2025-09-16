# frozen_string_literal: true

RSpec.describe AuthProviderSerializer do
  fab!(:user)

  before do
    allow(SiteSetting).to receive(:get).and_call_original
    allow(SiteSetting).to receive(:get).with(:test_icon).and_return("bullseye")
    allow(SiteSetting).to receive(:get).with(:test_pretty_name).and_return("new pretty name")
    allow(SiteSetting).to receive(:get).with(:test_title).and_return("new_title")
  end

  let(:authenticator) do
    Class
      .new(Auth::ManagedAuthenticator) do
        def name
          "test_auth"
        end

        def enabled?
          true
        end
      end
      .new
  end

  let(:serializer) do
    AuthProviderSerializer.new(auth_provider, scope: Guardian.new(user), root: false)
  end

  context "without overridden attributes" do
    let(:auth_provider) do
      Auth::AuthProvider.new(
        authenticator:,
        icon: "flash",
        pretty_name: "old pretty name",
        title: "old_title",
      )
    end

    it "returns the original values" do
      json = serializer.as_json
      expect(json[:pretty_name_override]).to eq("old pretty name")
      expect(json[:title_override]).to eq("old_title")
      expect(json[:icon_override]).to eq("flash")
    end
  end

  context "with overridden attributes" do
    let(:auth_provider) do
      Auth::AuthProvider.new(
        authenticator:,
        icon: "flash",
        icon_setting: :test_icon,
        pretty_name: "old pretty name",
        pretty_name_setting: :test_pretty_name,
        title: "old_title",
        title_setting: :test_title,
      )
    end

    it "returns the overridden values" do
      json = serializer.as_json
      expect(json[:pretty_name_override]).to eq("new pretty name")
      expect(json[:title_override]).to eq("new_title")
      expect(json[:icon_override]).to eq("bullseye")
    end
  end
end
