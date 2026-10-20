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
end
