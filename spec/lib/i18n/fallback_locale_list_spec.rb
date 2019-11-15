# frozen_string_literal: true

require 'rails_helper'
require 'i18n/backend/fallback_locale_list'

describe I18n::Backend::FallbackLocaleList do
  let(:list) { I18n::Backend::FallbackLocaleList.new }

  it "works when default_locale is English" do
    SiteSetting.default_locale = :en

    expect(list[:ru]).to eq([:ru, :en])
    expect(list[:en]).to eq([:en])
  end

  it "works when default_locale is English (United States)" do
    SiteSetting.default_locale = :en_US

    expect(list[:ru]).to eq([:ru, :en_US, :en])
    expect(list[:en_US]).to eq([:en_US, :en])
    expect(list[:en]).to eq([:en])
  end

  it "works when default_locale is not English" do
    SiteSetting.default_locale = :de

    expect(list[:ru]).to eq([:ru, :de, :en])
    expect(list[:de]).to eq([:de, :en])
    expect(list[:en]).to eq([:en])
    expect(list[:en_US]).to eq([:en_US, :en])
  end

  context "when plugin registered fallback locale" do
    before do
      DiscoursePluginRegistry.register_locale("es_MX", fallbackLocale: "es")
      DiscoursePluginRegistry.register_locale("de_AT", fallbackLocale: "de")
    end

    after do
      DiscoursePluginRegistry.reset!
    end

    it "works when default_locale is English" do
      SiteSetting.default_locale = :en

      expect(list[:de_AT]).to eq([:de_AT, :de, :en])
      expect(list[:de]).to eq([:de, :en])
      expect(list[:en]).to eq([:en])
    end

    it "works when default_locale is not English" do
      SiteSetting.default_locale = :de

      expect(list[:es_MX]).to eq([:es_MX, :es, :de, :en])
      expect(list[:es]).to eq([:es, :de, :en])
      expect(list[:en]).to eq([:en])
    end
  end
end
