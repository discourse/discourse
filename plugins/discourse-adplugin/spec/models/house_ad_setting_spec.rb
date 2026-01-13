# frozen_string_literal: true

describe AdPlugin::HouseAdSetting do
  let(:defaults) { AdPlugin::HouseAdSetting::DEFAULTS }

  before { enable_current_plugin }

  describe ".all" do
    subject(:setting) { AdPlugin::HouseAdSetting.all }

    it "returns defaults when nothing has been set" do
      expect(setting).to eq(defaults)
    end

    it "returns defaults and overrides" do
      AdPlugin.pstore_set("ad-setting:topic_list_top", "Banner")
      expect(setting[:topic_list_top]).to eq("Banner")
      expect(setting.except(:topic_list_top)).to eq(defaults.except(:topic_list_top))
    end
  end

  describe ".update" do
    before do
      AdPlugin::HouseAd.create(name: "Banner", html: "<p>Banner</p>")
      AdPlugin::HouseAd.create(name: "Donate", html: "<p>Donate</p>")
    end

    it "can set override for the first time" do
      expect { AdPlugin::HouseAdSetting.update(:topic_list_top, "Banner|Donate") }.to change {
        PluginStoreRow.count
      }.by(1)
      expect(AdPlugin::HouseAdSetting.all[:topic_list_top]).to eq("Banner|Donate")
    end

    it "can update an existing override" do
      AdPlugin.pstore_set("ad-setting:topic_list_top", "Banner")
      expect { AdPlugin::HouseAdSetting.update(:topic_list_top, "Banner|Donate") }.to_not change {
        PluginStoreRow.count
      }
      expect(AdPlugin::HouseAdSetting.all[:topic_list_top]).to eq("Banner|Donate")
    end

    it "removes ad names that don't exist" do
      AdPlugin::HouseAdSetting.update(:topic_list_top, "Coupon|Banner|Donate")
      expect(AdPlugin::HouseAdSetting.all[:topic_list_top]).to eq("Banner|Donate")
    end

    it "can reset to default" do
      AdPlugin.pstore_set("ad-setting:topic_list_top", "Banner")
      expect { AdPlugin::HouseAdSetting.update(:topic_list_top, "") }.to change {
        PluginStoreRow.count
      }.by(-1)
      expect(AdPlugin::HouseAdSetting.all[:topic_list_top]).to eq("")
    end

    it "raises error on invalid setting name" do
      expect { AdPlugin::HouseAdSetting.update(:nope, "Click Me") }.to raise_error(
        Discourse::NotFound,
      )
      expect(AdPlugin.pstore_get("ad-setting:nope")).to be_nil
    end

    it "raises error on invalid value" do
      expect { AdPlugin::HouseAdSetting.update(:topic_list_top, "<script>") }.to raise_error(
        Discourse::InvalidParameters,
      )
      expect(AdPlugin::HouseAdSetting.all[:topic_list_top]).to eq("")
    end
  end

  describe ".publish_settings" do
    fab!(:anon_ad) do
      Fabricate(
        :house_ad,
        name: "anon-ad",
        html: "<whatever-anon>",
        visible_to_anons: true,
        visible_to_logged_in_users: false,
      )
    end

    fab!(:logged_in_ad) do
      Fabricate(
        :house_ad,
        name: "logged-in-ad",
        html: "<whatever-logged-in>",
        visible_to_anons: false,
        visible_to_logged_in_users: true,
      )
    end

    before { AdPlugin::HouseAdSetting.update("topic_list_top", "logged-in-ad|anon-ad") }

    it "publishes different payloads to different channels for anons and logged in users" do
      messages = MessageBus.track_publish { AdPlugin::HouseAdSetting.publish_settings }
      expect(messages.size).to eq(2)

      anon_message = messages.find { |m| m.channel == "/site/house-creatives/anonymous" }
      logged_in_message = messages.find { |m| m.channel == "/site/house-creatives/logged-in" }

      expect(anon_message.data[:creatives]).to match(
        "anon-ad" => {
          html: "<whatever-anon>",
          category_ids: [],
          id: a_kind_of(Integer),
          routes: [],
        },
      )
      expect(anon_message.group_ids).to eq(nil)
      expect(anon_message.user_ids).to eq(nil)

      expect(logged_in_message.data[:creatives]).to match(
        "logged-in-ad" => {
          html: "<whatever-logged-in>",
          category_ids: [],
          id: a_kind_of(Integer),
          routes: [],
        },
      )
      expect(logged_in_message.group_ids).to eq([Group::AUTO_GROUPS[:trust_level_0]])
      expect(logged_in_message.user_ids).to eq(nil)
    end
  end
end
