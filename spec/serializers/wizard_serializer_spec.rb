# frozen_string_literal: true

RSpec.describe WizardSerializer do
  let(:admin) { Fabricate(:admin) }

  after { ColorScheme.hex_cache.clear }

  describe "color scheme" do
    it "works with base colors" do
      expect(Theme.where(id: SiteSetting.default_theme_id).first&.color_scheme).to be_nil

      wizard = Wizard::Builder.new(admin).build
      serializer = WizardSerializer.new(wizard, scope: Guardian.new(admin))
      json = MultiJson.load(MultiJson.dump(serializer.as_json))

      expect(json["wizard"]["current_color_scheme"][0]["name"]).to eq("primary")
      expect(json["wizard"]["current_color_scheme"][0]["hex"]).to eq("222")
    end

    it "should provide custom colors correctly" do
      colors =
        ColorScheme.create_from_base(
          name: "Customized",
          colors: {
            header_background: "00FF00",
            header_primary: "20CCFF",
          },
        )
      theme = Fabricate(:theme, color_scheme_id: colors.id)

      SiteSetting.default_theme_id = theme.id

      wizard = Wizard::Builder.new(admin).build

      serializer = WizardSerializer.new(wizard, scope: Guardian.new(admin))
      # serializer.as_json leaves in Ruby objects, force to true json
      json = MultiJson.load(MultiJson.dump(serializer.as_json))

      expect(json["wizard"]["current_color_scheme"].to_s).to include(
        '{"name"=>"header_background", "hex"=>"00FF00"}',
      )
    end
  end

  describe "steps" do
    let(:wizard) { Wizard::Builder.new(admin).build }
    let(:serializer) { WizardSerializer.new(wizard, scope: Guardian.new(admin)) }

    it "has expected steps" do
      SiteSetting.login_required = true
      SiteSetting.invite_only = true
      SiteSetting.must_approve_users = true

      json = MultiJson.load(MultiJson.dump(serializer.as_json))
      steps = json["wizard"]["steps"]

      expect(steps.first["id"]).to eq("introduction")
      expect(steps.last["id"]).to eq("corporate")

      privacy_step = steps.find { |s| s["id"] == "privacy" }
      expect(privacy_step).to_not be_nil

      login_required_field = privacy_step["fields"].find { |f| f["id"] == "login_required" }
      expect(login_required_field["value"]).to eq("private")

      invite_only_field = privacy_step["fields"].find { |f| f["id"] == "invite_only" }
      expect(invite_only_field["value"]).to eq("invite_only")

      must_approve_users_field = privacy_step["fields"].find { |f| f["id"] == "must_approve_users" }
      expect(must_approve_users_field["value"]).to eq("yes")
    end
  end
end
