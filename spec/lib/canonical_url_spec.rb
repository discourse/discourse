# frozen_string_literal: true

describe CanonicalURL::ControllerExtensions do
  let(:host_class) do
    Class.new do
      def self.helper_method(*)
      end

      include CanonicalURL::ControllerExtensions

      attr_accessor :params, :use_crawler_layout

      def initialize(params = {})
        @params = params
        @use_crawler_layout = true
      end

      def use_crawler_layout?
        @use_crawler_layout
      end
    end
  end

  describe "#append_content_localization_param" do
    let(:instance) { host_class.new(Discourse::LOCALE_PARAM => "ja") }

    before do
      SiteSetting.content_localization_enabled = true
      SiteSetting.content_localization_crawler_param = true
      SiteSetting.content_localization_supported_locales = "en|ja|es"
    end

    it "returns the url unchanged when content_localization_enabled is false" do
      SiteSetting.content_localization_enabled = false
      expect(instance.send(:append_content_localization_param, "/latest")).to eq("/latest")
    end

    it "returns the url unchanged when content_localization_crawler_param is false" do
      SiteSetting.content_localization_crawler_param = false
      expect(instance.send(:append_content_localization_param, "/latest")).to eq("/latest")
    end

    it "returns the url unchanged for non-crawler requests" do
      instance.use_crawler_layout = false
      expect(instance.send(:append_content_localization_param, "/latest")).to eq("/latest")
    end

    it "returns the url unchanged when the locale param is absent" do
      instance.params = {}
      expect(instance.send(:append_content_localization_param, "/latest")).to eq("/latest")
    end

    it "returns the url unchanged when the locale is not in the supported list" do
      instance.params = { Discourse::LOCALE_PARAM => "xyz" }
      expect(instance.send(:append_content_localization_param, "/latest")).to eq("/latest")
    end

    it "appends the locale param to a url without query string" do
      expect(instance.send(:append_content_localization_param, "/latest")).to eq(
        "/latest?#{Discourse::LOCALE_PARAM}=ja",
      )
    end

    it "appends the locale param to a url with an existing query string" do
      expect(instance.send(:append_content_localization_param, "/latest?page=2")).to eq(
        "/latest?page=2&#{Discourse::LOCALE_PARAM}=ja",
      )
    end

    it "replaces an existing locale param instead of duplicating it" do
      result =
        instance.send(:append_content_localization_param, "/latest?#{Discourse::LOCALE_PARAM}=en")
      expect(result).to eq("/latest?#{Discourse::LOCALE_PARAM}=ja")
    end

    it "preserves url fragments" do
      expect(instance.send(:append_content_localization_param, "/t/slug/1#post_5")).to eq(
        "/t/slug/1?#{Discourse::LOCALE_PARAM}=ja#post_5",
      )
    end
  end
end
