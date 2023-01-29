# frozen_string_literal: true

RSpec.describe Auth::DiscordAuthenticator do
  let(:hash) do
    OmniAuth::AuthHash.new(
      provider: "facebook",
      extra: {
        raw_info: {
          id: "100",
          username: "bobbob",
          guilds: [
            {
              id: "80351110224678912",
              name: "1337 Krew",
              icon: "8342729096ea3675442027381ff50dfe",
              owner: true,
              permissions: 36_953_089,
            },
          ],
        },
      },
      info: {
        email: "bob@bob.com",
        name: "bobbob",
      },
      uid: "100",
    )
  end

  let(:authenticator) { described_class.new }

  describe "after_authenticate" do
    it "works normally" do
      result = authenticator.after_authenticate(hash)
      expect(result.user).to eq(nil)
      expect(result.failed).to eq(false)
      expect(result.name).to eq("bobbob")
      expect(result.email).to eq("bob@bob.com")
    end

    it "denies access when guilds are restricted" do
      SiteSetting.discord_trusted_guilds = %w[someguildid someotherguildid].join("|")
      result = authenticator.after_authenticate(hash)
      expect(result.user).to eq(nil)
      expect(result.failed).to eq(true)
      expect(result.failed_reason).to eq(I18n.t("discord.not_in_allowed_guild"))
    end

    it "allows access when in an allowed guild" do
      SiteSetting.discord_trusted_guilds = %w[80351110224678912 anothertrustedguild].join("|")
      result = authenticator.after_authenticate(hash)
      expect(result.user).to eq(nil)
      expect(result.failed).to eq(false)
      expect(result.name).to eq("bobbob")
      expect(result.email).to eq("bob@bob.com")
    end
  end
end
