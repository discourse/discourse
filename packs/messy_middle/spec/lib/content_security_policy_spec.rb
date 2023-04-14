# frozen_string_literal: true
RSpec.describe ContentSecurityPolicy do
  after { DiscoursePluginRegistry.reset! }

  describe "report-uri" do
    it "is enabled by SiteSetting" do
      SiteSetting.content_security_policy_collect_reports = true
      report_uri = parse(policy)["report-uri"].first
      expect(report_uri).to eq("http://test.localhost/csp_reports")

      SiteSetting.content_security_policy_collect_reports = false
      report_uri = parse(policy)["report-uri"]
      expect(report_uri).to eq(nil)
    end
  end

  describe "base-uri" do
    it "is set to self" do
      base_uri = parse(policy)["base-uri"]
      expect(base_uri).to eq(["'self'"])
    end
  end

  describe "object-src" do
    it "is set to none" do
      object_srcs = parse(policy)["object-src"]
      expect(object_srcs).to eq(["'none'"])
    end
  end

  describe "upgrade-insecure-requests" do
    it "is not included when force_https is off" do
      SiteSetting.force_https = false
      expect(parse(policy)["upgrade-insecure-requests"]).to eq(nil)
    end

    it "is included when force_https is on" do
      SiteSetting.force_https = true
      expect(parse(policy)["upgrade-insecure-requests"]).to eq([])
    end
  end

  describe "worker-src" do
    it "has expected values" do
      worker_srcs = parse(policy)["worker-src"]
      expect(worker_srcs).to eq(
        %w[
          'self'
          http://test.localhost/assets/
          http://test.localhost/brotli_asset/
          http://test.localhost/javascripts/
          http://test.localhost/plugins/
        ],
      )
    end
  end

  describe "script-src" do
    it "always has self, logster, sidekiq, and assets" do
      script_srcs = parse(policy)["script-src"]
      expect(script_srcs).to include(
        *%w[
          http://test.localhost/logs/
          http://test.localhost/sidekiq/
          http://test.localhost/mini-profiler-resources/
          http://test.localhost/assets/
          http://test.localhost/brotli_asset/
          http://test.localhost/extra-locales/
          http://test.localhost/highlight-js/
          http://test.localhost/javascripts/
          http://test.localhost/plugins/
          http://test.localhost/theme-javascripts/
          http://test.localhost/svg-sprite/
        ],
      )
    end

    it 'includes "report-sample" when report collection is enabled' do
      SiteSetting.content_security_policy_collect_reports = true
      script_srcs = parse(policy)["script-src"]
      expect(script_srcs).to include("'report-sample'")
    end

    context "for Google Analytics" do
      before { SiteSetting.ga_universal_tracking_code = "UA-12345678-9" }

      it "allowlists Google Analytics v3 when integrated" do
        SiteSetting.ga_version = "v3_analytics"

        script_srcs = parse(policy)["script-src"]
        expect(script_srcs).to include("https://www.google-analytics.com/analytics.js")
        expect(script_srcs).not_to include("https://www.googletagmanager.com/gtag/js")
      end

      it "allowlists Google Analytics v4 when integrated" do
        SiteSetting.ga_version = "v4_gtag"

        script_srcs = parse(policy)["script-src"]
        expect(script_srcs).to include("https://www.google-analytics.com/analytics.js")
        expect(script_srcs).to include("https://www.googletagmanager.com/gtag/js")
      end
    end

    it "allowlists Google Tag Manager when integrated" do
      SiteSetting.gtm_container_id = "GTM-ABCDEF"

      script_srcs = parse(policy)["script-src"]
      expect(script_srcs).to include("https://www.googletagmanager.com/gtm.js")
      expect(script_srcs.to_s).to include("nonce-")
    end

    it "allowlists CDN assets when integrated" do
      set_cdn_url("https://cdn.com")

      script_srcs = parse(policy)["script-src"]
      expect(script_srcs).to include(
        *%w[
          https://cdn.com/assets/
          https://cdn.com/brotli_asset/
          https://cdn.com/highlight-js/
          https://cdn.com/javascripts/
          https://cdn.com/plugins/
          https://cdn.com/theme-javascripts/
          http://test.localhost/extra-locales/
        ],
      )

      global_setting(:s3_cdn_url, "https://s3-cdn.com")

      script_srcs = parse(policy)["script-src"]
      expect(script_srcs).to include(
        *%w[
          https://s3-cdn.com/assets/
          https://s3-cdn.com/brotli_asset/
          https://cdn.com/highlight-js/
          https://cdn.com/javascripts/
          https://cdn.com/plugins/
          https://cdn.com/theme-javascripts/
          http://test.localhost/extra-locales/
        ],
      )

      global_setting(:s3_asset_cdn_url, "https://s3-asset-cdn.com")

      script_srcs = parse(policy)["script-src"]
      expect(script_srcs).to include(
        *%w[
          https://s3-asset-cdn.com/assets/
          https://s3-asset-cdn.com/brotli_asset/
          https://cdn.com/highlight-js/
          https://cdn.com/javascripts/
          https://cdn.com/plugins/
          https://cdn.com/theme-javascripts/
          http://test.localhost/extra-locales/
        ],
      )
    end

    it "adds subfolder to CDN assets" do
      set_cdn_url("https://cdn.com")
      set_subfolder("/forum")

      script_srcs = parse(policy)["script-src"]
      expect(script_srcs).to include(
        *%w[
          https://cdn.com/forum/assets/
          https://cdn.com/forum/brotli_asset/
          https://cdn.com/forum/highlight-js/
          https://cdn.com/forum/javascripts/
          https://cdn.com/forum/plugins/
          https://cdn.com/forum/theme-javascripts/
          http://test.localhost/forum/extra-locales/
        ],
      )

      global_setting(:s3_cdn_url, "https://s3-cdn.com")

      script_srcs = parse(policy)["script-src"]
      expect(script_srcs).to include(
        *%w[
          https://s3-cdn.com/assets/
          https://s3-cdn.com/brotli_asset/
          https://cdn.com/forum/highlight-js/
          https://cdn.com/forum/javascripts/
          https://cdn.com/forum/plugins/
          https://cdn.com/forum/theme-javascripts/
          http://test.localhost/forum/extra-locales/
        ],
      )
    end
  end

  describe "manifest-src" do
    it "is set to self" do
      expect(parse(policy)["manifest-src"]).to eq(["'self'"])
    end
  end

  describe "frame-ancestors" do
    context "with content_security_policy_frame_ancestors enabled" do
      before do
        SiteSetting.content_security_policy_frame_ancestors = true
        Fabricate(:embeddable_host, host: "https://a.org")
        Fabricate(:embeddable_host, host: "https://b.org")
      end

      it "always has self" do
        frame_ancestors = parse(policy)["frame-ancestors"]
        expect(frame_ancestors).to include("'self'")
      end

      it "includes all EmbeddableHost" do
        EmbeddableHost
        frame_ancestors = parse(policy)["frame-ancestors"]
        expect(frame_ancestors).to include("https://a.org")
        expect(frame_ancestors).to include("https://b.org")
      end
    end

    context "with content_security_policy_frame_ancestors disabled" do
      before { SiteSetting.content_security_policy_frame_ancestors = false }

      it "does not set frame-ancestors" do
        frame_ancestors = parse(policy)["frame-ancestors"]
        expect(frame_ancestors).to be_nil
      end
    end
  end

  context "with a plugin" do
    let(:plugin_class) do
      Class.new(Plugin::Instance) do
        attr_accessor :enabled
        def enabled?
          @enabled
        end
      end
    end

    it "can extend script-src, object-src, manifest-src" do
      plugin = plugin_class.new(nil, "#{Rails.root}/spec/fixtures/plugins/csp_extension/plugin.rb")

      plugin.activate!
      Discourse.plugins << plugin

      plugin.enabled = true
      expect(parse(policy)["script-src"]).to include("https://from-plugin.com")
      expect(parse(policy)["script-src"]).to include("http://test.localhost/local/path")
      expect(parse(policy)["object-src"]).to include("https://test-stripping.com")
      expect(parse(policy)["object-src"]).to_not include("'none'")
      expect(parse(policy)["manifest-src"]).to include("'self'")
      expect(parse(policy)["manifest-src"]).to include("https://manifest-src.com")

      plugin.enabled = false
      expect(parse(policy)["script-src"]).to_not include("https://from-plugin.com")
      expect(parse(policy)["manifest-src"]).to_not include("https://manifest-src.com")

      Discourse.plugins.delete plugin
      DiscoursePluginRegistry.reset!
    end

    it "can extend frame_ancestors" do
      SiteSetting.content_security_policy_frame_ancestors = true
      plugin = plugin_class.new(nil, "#{Rails.root}/spec/fixtures/plugins/csp_extension/plugin.rb")

      plugin.activate!
      Discourse.plugins << plugin

      plugin.enabled = true
      expect(parse(policy)["frame-ancestors"]).to include("'self'")
      expect(parse(policy)["frame-ancestors"]).to include("https://frame-ancestors-plugin.ext")

      plugin.enabled = false
      expect(parse(policy)["frame-ancestors"]).to_not include("https://frame-ancestors-plugin.ext")

      Discourse.plugins.delete plugin
      DiscoursePluginRegistry.reset!
    end
  end

  it "only includes unsafe-inline for qunit paths" do
    expect(parse(policy(path_info: "/qunit"))["script-src"]).to include("'unsafe-eval'")
    expect(parse(policy(path_info: "/wizard/qunit"))["script-src"]).to include("'unsafe-eval'")
    expect(parse(policy(path_info: "/"))["script-src"]).to_not include("'unsafe-eval'")
  end

  context "with a theme" do
    let!(:theme) do
      Fabricate(:theme).tap do |t|
        settings = <<~YML
          extend_content_security_policy:
            type: list
            default: 'script-src: from-theme.com'
        YML
        t.set_field(target: :settings, name: :yaml, value: settings)
        t.save!
      end
    end

    def theme_policy
      policy(theme.id)
    end

    it "can be extended by themes" do
      policy # call this first to make sure further actions clear the cache

      expect(parse(policy)["script-src"]).not_to include("from-theme.com")

      expect(parse(theme_policy)["script-src"]).to include("from-theme.com")

      theme.update_setting(
        :extend_content_security_policy,
        "script-src: https://from-theme.net|worker-src: from-theme.com",
      )
      theme.save!

      expect(parse(theme_policy)["script-src"]).to_not include("from-theme.com")
      expect(parse(theme_policy)["script-src"]).to include("https://from-theme.net")
      expect(parse(theme_policy)["worker-src"]).to include("from-theme.com")

      theme.destroy!

      expect(parse(theme_policy)["script-src"]).to_not include("https://from-theme.net")
      expect(parse(theme_policy)["worker-src"]).to_not include("from-theme.com")
    end

    it "can be extended by theme modifiers" do
      policy # call this first to make sure further actions clear the cache

      theme.theme_modifier_set.csp_extensions = [
        "script-src: https://from-theme-flag.script",
        "worker-src: from-theme-flag.worker",
      ]
      theme.save!

      child_theme = Fabricate(:theme, component: true)
      theme.add_relative_theme!(:child, child_theme)
      child_theme.theme_modifier_set.csp_extensions = [
        "script-src: https://child-theme-flag.script",
        "worker-src: child-theme-flag.worker",
      ]
      child_theme.save!

      expect(parse(theme_policy)["script-src"]).to include("https://from-theme-flag.script")
      expect(parse(theme_policy)["script-src"]).to include("https://child-theme-flag.script")
      expect(parse(theme_policy)["worker-src"]).to include("from-theme-flag.worker")
      expect(parse(theme_policy)["worker-src"]).to include("child-theme-flag.worker")

      theme.destroy!
      child_theme.destroy!

      expect(parse(theme_policy)["script-src"]).to_not include("https://from-theme-flag.script")
      expect(parse(theme_policy)["worker-src"]).to_not include("from-theme-flag.worker")
      expect(parse(theme_policy)["worker-src"]).to_not include("from-theme-flag.worker")
      expect(parse(theme_policy)["worker-src"]).to_not include("child-theme-flag.worker")
    end

    it "is extended automatically when themes reference external scripts" do
      policy # call this first to make sure further actions clear the cache

      theme.set_field(target: :common, name: "header", value: <<~HTML)
        <script src='https://example.com/myscript.js'></script>
        <script src='https://example.com/myscript2.js?with=query'></script>
        <script src='//example2.com/protocol-less-script.js'></script>
        <script src='domain-only.com'></script>
        <script>console.log('inline script')</script>
      HTML

      theme.set_field(target: :desktop, name: "header", value: "")
      theme.save!

      expect(parse(theme_policy)["script-src"]).to include("https://example.com/myscript.js")
      expect(parse(theme_policy)["script-src"]).to include("https://example.com/myscript2.js")
      expect(parse(theme_policy)["script-src"]).not_to include("?")
      expect(parse(theme_policy)["script-src"]).to include("example2.com/protocol-less-script.js")
      expect(parse(theme_policy)["script-src"]).not_to include("domain-only.com")
      expect(parse(theme_policy)["script-src"]).not_to include(
        a_string_matching %r{^/theme-javascripts}
      )

      theme.destroy!

      expect(parse(theme_policy)["script-src"]).to_not include("https://example.com/myscript.js")
    end
  end

  it "can be extended by site setting" do
    SiteSetting.content_security_policy_script_src = "from-site-setting.com|from-site-setting.net"

    expect(parse(policy)["script-src"]).to include("from-site-setting.com", "from-site-setting.net")
  end

  def parse(csp_string)
    csp_string
      .split(";")
      .map do |policy|
        directive, *sources = policy.split
        [directive, sources]
      end
      .to_h
  end

  def policy(theme_id = nil, path_info: "/")
    ContentSecurityPolicy.policy(theme_id, path_info: path_info)
  end
end
