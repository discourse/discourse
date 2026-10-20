# frozen_string_literal: true

RSpec.describe Plugin::JsManager do
  describe ".route_bundle_for_path" do
    let(:manifest) do
      {
        "main" => {
          "routeBundles" => [
            { "url" => "chat/visualizer/*", "fileName" => "visualizer.js" },
            { "url" => "chat/*", "fileName" => "chat.js" },
            { "url" => "u/*/preferences/chat/*", "fileName" => "preferences.js" },
          ],
        },
      }
    end

    before { allow(described_class).to receive(:read_manifest).and_return(manifest) }

    def bundle_for(path)
      described_class.route_bundle_for_path("chat", "main", path)
    end

    it "matches an exact url" do
      expect(bundle_for("chat/visualizer")).to eq("js/plugins/visualizer")
    end

    it "prefers the first matching glob, so a specific url wins over a wildcard covering it" do
      # `chat/visualizer` also matches `chat/*`, but is declared first.
      expect(bundle_for("chat/visualizer")).to eq("js/plugins/visualizer")
      expect(bundle_for("chat/c/some-channel/1")).to eq("js/plugins/chat")
    end

    it "matches the bare parent of a trailing wildcard" do
      expect(bundle_for("chat")).to eq("js/plugins/chat")
    end

    it "does not let a wildcard match a sibling with the same prefix" do
      expect(bundle_for("chatter")).to eq(nil)
    end

    it "matches a wildcard standing in for a dynamic segment" do
      expect(bundle_for("u/bob/preferences/chat")).to eq("js/plugins/preferences")
    end

    it "requires the segments after a wildcard to match" do
      expect(bundle_for("u/bob/preferences/account")).to eq(nil)
      expect(bundle_for("u/bob/preferences")).to eq(nil)
    end

    context "with a splat segment" do
      let(:manifest) do
        { "main" => { "routeBundles" => [{ "url" => "c/**/edit/*", "fileName" => "edit.js" }] } }
      end

      it "matches one segment or many, because a splat eats the rest of the route path" do
        expect(bundle_for("c/announcements/edit")).to eq("js/plugins/edit")
        expect(bundle_for("c/parent/child/5/edit")).to eq("js/plugins/edit")
      end

      it "still requires the segments around it to match" do
        expect(bundle_for("c/announcements/5")).to eq(nil)
        expect(bundle_for("c/edit")).to eq(nil)
        expect(bundle_for("x/announcements/5/edit")).to eq(nil)
      end
    end

    it "returns nothing for an unrelated path" do
      expect(bundle_for("latest")).to eq(nil)
    end

    it "returns nothing when the plugin splits no routes" do
      allow(described_class).to receive(:read_manifest).and_return({ "main" => {} })
      expect(bundle_for("chat")).to eq(nil)
    end
  end

  describe "#compile_js_bundle" do
    let(:plugin_dir) { Dir.mktmpdir }
    let(:plugin) do
      instance_double(
        Plugin::Instance,
        name: "digest-test",
        directory: plugin_dir,
        directory_name: "js_manager_spec_#{SecureRandom.hex(4)}",
        about_json_metadata: nil,
      )
    end
    let(:js_dir) { Rails.root.join("app/assets/generated/#{plugin.directory_name}/js/plugins") }
    let(:compilations) { [] }

    before do
      FileUtils.mkdir_p("#{plugin_dir}/assets/javascripts")
      File.write("#{plugin_dir}/assets/javascripts/main.js", "export default 1;")

      allow(AssetProcessor).to receive(:ember_version).and_return("6.0.0")
      allow(AssetProcessor).to receive(:digest).and_return("processor-a")

      allow(Plugin::JsCompiler).to receive(:new) do |_name, filename_prefix:, filename_suffix:, **|
        compilations << filename_suffix
        file_name = "#{filename_prefix}main.Ab12Cd#{filename_suffix}.js"
        instance_double(
          Plugin::JsCompiler,
          compile!: {
            file_name => {
              "name" => "main",
              "isEntry" => true,
              "code" => "",
            },
          },
        )
      end
    end

    after do
      FileUtils.rm_rf(Rails.root.join("app/assets/generated/#{plugin.directory_name}"))
      FileUtils.rm_rf(plugin_dir)
    end

    it "reuses the existing build when its inputs are unchanged" do
      2.times { described_class.new.compile_js_bundle(plugin) }

      expect(compilations.size).to eq(1)
    end

    it "rebuilds under a new filename when the asset processor changes" do
      described_class.new.compile_js_bundle(plugin)

      allow(AssetProcessor).to receive(:digest).and_return("processor-b")
      described_class.new.compile_js_bundle(plugin)

      expect(compilations.uniq.size).to eq(2)
      expect(Dir.children(js_dir)).to contain_exactly(
        "#{plugin.directory_name}_main.Ab12Cd#{compilations.last}.js",
      )
    end
  end
end
