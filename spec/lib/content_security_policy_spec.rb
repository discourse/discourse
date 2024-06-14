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

  describe "strict-dynamic script-src and worker-src" do
    it "includes strict-dynamic keyword" do
      script_srcs = parse(policy)["script-src"]
      expect(script_srcs).to include("'strict-dynamic'")
    end

    it "does not set worker-src" do
      worker_src = parse(policy)["worker-src"]
      expect(worker_src).to eq(nil)
    end

    it 'includes "report-sample" when report collection is enabled' do
      SiteSetting.content_security_policy_collect_reports = true
      script_srcs = parse(policy)["script-src"]
      expect(script_srcs).to include("'report-sample'")
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

  it "can be extended by site setting" do
    SiteSetting.content_security_policy_script_src = "'unsafe-eval'"

    expect(parse(policy)["script-src"]).to include("'unsafe-eval'")
  end

  it "strips unsupported values from setting" do
    SiteSetting.content_security_policy_script_src =
      "'unsafe-eval'|blob:|https://example.com/script.js"

    script_src = parse(policy)["script-src"]
    expect(script_src).to include("'unsafe-eval'")
    expect(script_src).not_to include("blob:")
    expect(script_src).not_to include("https://example.com/script.js")
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
