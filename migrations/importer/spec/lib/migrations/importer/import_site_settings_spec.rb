# frozen_string_literal: true

RSpec.describe Migrations::Importer::ImportSiteSettings do
  subject(:site_settings) { described_class.new }

  context "with stubbed site settings" do
    let(:site_setting_class) do
      Class.new do
        class << self
          attr_accessor :purge_unactivated_users_grace_period_days,
                        :purge_deleted_uploads_grace_period_days

          def values
            @values ||= {}
          end

          def get(name)
            values[name]
          end

          def set(name, value)
            values[name] = value
          end
        end
      end
    end

    let(:rate_limiter_class) do
      Class.new do
        class << self
          def disable
          end

          def enable
          end
        end
      end
    end

    before do
      stub_const("SiteSetting", site_setting_class)
      stub_const("RateLimiter", rate_limiter_class)
      allow(RateLimiter).to receive(:disable)
      allow(RateLimiter).to receive(:enable)

      SiteSetting.set(:min_post_length, 20)
      SiteSetting.set(:clean_up_uploads, true)
      SiteSetting.set(:authorized_extensions, "jpg|png")
      SiteSetting.purge_unactivated_users_grace_period_days = 14
      SiteSetting.purge_deleted_uploads_grace_period_days = 30
    end

    describe "#apply!" do
      it "sets every import setting and disables rate limits" do
        site_settings.apply!

        described_class::SETTINGS.each { |name, value| expect(SiteSetting.get(name)).to eq(value) }
        expect(RateLimiter).to have_received(:disable)
      end

      it "extends the purge grace periods" do
        site_settings.apply!

        expect(SiteSetting.purge_unactivated_users_grace_period_days).to eq(60)
        expect(SiteSetting.purge_deleted_uploads_grace_period_days).to eq(90)
      end

      it "keeps purging of unactivated users disabled when it is off" do
        SiteSetting.purge_unactivated_users_grace_period_days = 0

        site_settings.apply!

        expect(SiteSetting.purge_unactivated_users_grace_period_days).to eq(0)
      end
    end

    describe "#restore!" do
      it "puts the previous values back and enables rate limits" do
        site_settings.apply!
        site_settings.restore!

        expect(SiteSetting.get(:min_post_length)).to eq(20)
        expect(SiteSetting.get(:clean_up_uploads)).to be(true)
        expect(SiteSetting.get(:authorized_extensions)).to eq("jpg|png")
        expect(RateLimiter).to have_received(:enable)
      end

      it "keeps a value that was changed during the import" do
        site_settings.apply!
        SiteSetting.set(:min_post_length, 5)

        restored = site_settings.restore!

        expect(SiteSetting.get(:min_post_length)).to eq(5)
        expect(restored).to eq(described_class::SETTINGS.size - 1)
      end

      it "does not roll back the purge grace periods" do
        site_settings.apply!
        site_settings.restore!

        expect(SiteSetting.purge_unactivated_users_grace_period_days).to eq(60)
        expect(SiteSetting.purge_deleted_uploads_grace_period_days).to eq(90)
      end

      it "does nothing when the settings were never applied" do
        expect(site_settings.restore!).to be_nil
        expect(SiteSetting.get(:min_post_length)).to eq(20)
        expect(RateLimiter).not_to have_received(:enable)
      end

      it "restores only once" do
        site_settings.apply!
        site_settings.restore!
        SiteSetting.set(:min_post_length, 1)

        expect(site_settings.restore!).to be_nil
        expect(SiteSetting.get(:min_post_length)).to eq(1)
      end
    end
  end

  context "with the real site settings", :rails do
    before do
      SiteSetting.min_post_length = 20
      SiteSetting.clean_up_uploads = true
    end

    it "loosens the settings for the run and puts them back afterwards" do
      site_settings.apply!
      expect(SiteSetting.min_post_length).to eq(1)
      expect(SiteSetting.clean_up_uploads).to be(false)
      expect(RateLimiter).to be_disabled

      site_settings.restore!
      expect(SiteSetting.min_post_length).to eq(20)
      expect(SiteSetting.clean_up_uploads).to be(true)
      expect(RateLimiter).not_to be_disabled
    end
  end
end
