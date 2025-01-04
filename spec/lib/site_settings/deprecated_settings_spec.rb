# frozen_string_literal: true

RSpec.describe SiteSettings::DeprecatedSettings do
  describe "when not overriding deprecated settings" do
    it "does not act as a proxy to the new methods" do
      stub_deprecated_settings!(override: false) do
        SiteSetting.old_one = true

        expect(SiteSetting.new_one).to eq(false)
        expect(SiteSetting.new_one?).to eq(false)
      end
    end

    it "logs warnings when deprecated settings are called" do
      stub_deprecated_settings!(override: false) do
        logger =
          track_log_messages do
            expect(SiteSetting.old_one).to eq(false)
            expect(SiteSetting.old_one?).to eq(false)
          end
        expect(logger.warnings.count).to eq(3)

        logger = track_log_messages { SiteSetting.old_one(warn: false) }
        expect(logger.warnings.count).to eq(0)
      end
    end
  end

  describe "when overriding deprecated settings" do
    it "acts as a proxy to the new methods" do
      stub_deprecated_settings!(override: true) do
        SiteSetting.old_one = true

        expect(SiteSetting.new_one).to eq(true)
        expect(SiteSetting.new_one?).to eq(true)
      end
    end

    it "logs warnings when deprecated settings are called" do
      stub_deprecated_settings!(override: true) do
        logger =
          track_log_messages do
            expect(SiteSetting.old_one).to eq(false)
            expect(SiteSetting.old_one?).to eq(false)
          end
        expect(logger.warnings.count).to eq(2)

        logger = track_log_messages { SiteSetting.old_one(warn: false) }
        expect(logger.warnings.count).to eq(0)
      end
    end
  end
end
