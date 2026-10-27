# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::Tools::GenerateAppearanceChange do
  fab!(:admin)
  fab!(:moderator)

  let(:context) { DiscourseAi::Agents::BotContext.new(user: admin, messages: []) }

  before do
    enable_current_plugin
    Theme.foundation_theme.set_default!
  end

  def invoke(**parameters)
    described_class.new(parameters, bot_user: Discourse.system_user, llm: nil, context:).invoke
  end

  def draft(result)
    DiscourseAi::Agents::AppearanceAuthoring::Draft.read(result[:draft_token])
  end

  def access_modifier(feature, message)
    proc do |decision, request|
      decision.deny!(message) if request.feature == feature
      decision
    end
  end

  it "builds readable palettes for the current theme without changing the site" do
    palettes = ColorSchemes::Action::BuildFromBrand.call(brand: "e8590c")
    result = nil

    expect { result = invoke(name: "Acme", brand_color: "#E8590C") }.not_to change {
      ColorScheme.count
    }
    expect(result).to include(
      status: "success",
      name: "Acme",
      saves_as:
        I18n.t(
          "discourse_ai.appearance_authoring.palettes_target",
          theme: Theme.foundation_theme.name,
        ),
    )
    expect(result[:readability_adjustments]).to include(
      { color: "Links and buttons", from: "#e8590c", to: "##{palettes.light["tertiary"]}" },
    )
    expect(draft(result)).to include(
      kind: "palettes",
      theme_id: Theme.foundation_theme.id,
      user_id: admin.id,
      light_colors: palettes.light,
      dark_colors: palettes.dark,
    )
  end

  it "drafts a new theme when asked, warning when the site's layout would change" do
    Theme.horizon_theme.set_default!

    result = invoke(name: "Acme", brand_color: "#e8590c", new_theme: true)

    expect(result[:saves_as]).to eq(
      I18n.t(
        "discourse_ai.appearance_authoring.new_theme_target_with_layout_change",
        theme: Theme.horizon_theme.name,
      ),
    )
    expect(draft(result)).to include(kind: "theme")
    expect(draft(result)).not_to have_key(:theme_id)
  end

  it "only uses fonts Discourse offers" do
    result = invoke(name: "Acme", brand_color: "#e8590c", body_font: "Lora")

    expect(result[:fonts]).to eq("base_font" => "Lora")
    expect(draft(result)[:site_settings]).to eq("base_font" => "lora")
    expect(invoke(name: "Acme", brand_color: "#e8590c", heading_font: "Comic Sans")[:error]).to eq(
      I18n.t(
        "discourse_ai.appearance_authoring.unknown_font",
        font: "Comic Sans",
        fonts: DiscourseFonts.fonts.map { |font| font[:name] }.join(", "),
      ),
    )
  end

  it "refuses requests it can't carry out" do
    expect(invoke(name: "Acme", brand_color: "orange")).to eq(
      status: "error",
      error: I18n.t("discourse_ai.appearance_authoring.invalid_color", colors: "orange"),
    )
    expect(invoke(name: " ", brand_color: "#e8590c")[:error]).to eq(
      I18n.t("discourse_ai.appearance_authoring.name_required"),
    )
    expect(invoke(name: "Acme")[:error]).to eq(
      I18n.t("discourse_ai.appearance_authoring.brand_color_required"),
    )

    context.user = moderator
    expect(invoke(name: "Acme", brand_color: "#e8590c")[:error]).to eq(
      I18n.t("discourse_ai.appearance_authoring.not_allowed"),
    )
  end

  it "lets a plugin keep new themes off while palettes stay available" do
    plugin = Plugin::Instance.new
    modifier = access_modifier(:theme_authoring, "New themes aren't available here.")
    plugin.register_modifier(:admin_assistant_feature_access, &modifier)

    expect(invoke(name: "Acme", brand_color: "#e8590c", new_theme: true)[:error]).to eq(
      "New themes aren't available here.",
    )
    expect(invoke(name: "Acme", brand_color: "#e8590c")[:status]).to eq("success")
  ensure
    DiscoursePluginRegistry.unregister_modifier(plugin, :admin_assistant_feature_access, &modifier)
  end

  it "doesn't draft a new theme on a site that can't create themes" do
    plugin = Plugin::Instance.new
    modifier = proc { false }
    plugin.register_modifier(:user_guardian_can_create_theme, &modifier)

    expect(invoke(name: "Acme", brand_color: "#e8590c", new_theme: true)[:error]).to eq(
      I18n.t("discourse_ai.appearance_authoring.themes_unavailable"),
    )
  ensure
    DiscoursePluginRegistry.unregister_modifier(plugin, :user_guardian_can_create_theme, &modifier)
  end

  it "is only offered to administrators who can change how the site looks" do
    expect(described_class.available_for_context?(context)).to eq(true)

    plugin = Plugin::Instance.new
    modifier = access_modifier(:appearance_authoring, nil)
    plugin.register_modifier(:admin_assistant_feature_access, &modifier)
    expect(described_class.available_for_context?(context)).to eq(false)

    context.user = moderator
    expect(described_class.available_for_context?(context)).to eq(false)
  ensure
    DiscoursePluginRegistry.unregister_modifier(plugin, :admin_assistant_feature_access, &modifier)
  end

  context "with a website" do
    fab!(:llm_model)

    let(:llm) { DiscourseAi::Completions::Llm.proxy(llm_model) }
    let(:page_url) { "https://brand.example.com/" }
    let(:design) do
      {
        "brand_color" => "#635bff",
        "accent_color" => "",
        "header_color" => "",
        "candidates" => ["#635bff"],
        "dark" => false,
        "confidence" => "high",
        "body_font" => "lora",
        "body_font_exact" => true,
        "heading_font" => "merriweather",
        "heading_font_exact" => false,
      }
    end

    before do
      stub_request(:get, /.*/).to_return(status: 404)
      stub_request(:get, page_url).to_return(
        headers: {
          "Content-Type" => "text/html",
        },
        body: '<meta name="theme-color" content="#635bff">',
      )
    end

    # The model's answer about the website's design.
    def invoke_with_design(answer = design, **parameters)
      DiscourseAi::Completions::Llm.with_prepared_responses([answer]) do
        described_class.new(parameters, bot_user: Discourse.system_user, llm:, context:).invoke
      end
    end

    it "takes the brand color and the fonts Discourse offers from it" do
      result = invoke_with_design(name: "Acme", website_url: "brand.example.com")

      expect(result).to include(status: "success", fonts: { "base_font" => "Lora" })
      expect(result[:website]).to eq(
        domain: "brand.example.com",
        brand_color_confidence: :high,
        dark_website: false,
        closest_available_fonts: {
          headings: "Merriweather",
        },
      )
      expect(draft(result)[:light_colors]).to eq(
        ColorSchemes::Action::BuildFromBrand.call(brand: "635bff").light,
      )
    end

    it "asks which color is the brand when the website doesn't point clearly at one" do
      answer = design.merge("confidence" => "medium", "candidates" => %w[#635bff #0066cc])

      expect(invoke_with_design(answer, name: "Acme", website_url: page_url)).to eq(
        status: "needs_brand_color",
        message:
          I18n.t(
            "discourse_ai.appearance_authoring.confirm_brand_color",
            domain: "brand.example.com",
          ),
        candidates: %w[#635bff #0066cc],
      )
    end

    it "says when the website has no clear brand color" do
      answer = design.merge("brand_color" => "", "candidates" => [], "confidence" => "low")

      expect(invoke_with_design(answer, name: "Acme", website_url: page_url)).to eq(
        status: "needs_brand_color",
        message:
          I18n.t(
            "discourse_ai.appearance_authoring.no_brand_color_found",
            domain: "brand.example.com",
          ),
      )
    end

    it "uses a brand color the administrator picked over the website's" do
      result = invoke_with_design(name: "Acme", website_url: page_url, brand_color: "#0066cc")

      expect(draft(result)[:light_colors]).to eq(
        ColorSchemes::Action::BuildFromBrand.call(brand: "0066cc").light,
      )
    end

    it "says when it can't read the website" do
      stub_request(:get, page_url).to_return(status: 404)

      expect(invoke_with_design(name: "Acme", website_url: page_url)[:error]).to eq(
        I18n.t("discourse_ai.appearance_authoring.website_unreadable", url: page_url),
      )
    end

    it "says it can't read the website when the model fails, instead of failing the reply" do
      failure = DiscourseAi::Completions::Endpoints::Base::CompletionFailed.new("unavailable")

      expect(invoke_with_design(failure, name: "Acme", website_url: page_url)[:error]).to eq(
        I18n.t("discourse_ai.appearance_authoring.website_unreadable", url: page_url),
      )
    end

    it "limits how often an administrator can have websites read" do
      RateLimiter.enable

      stub_const(described_class, :WEBSITE_LOOKUPS_PER_HOUR, 1) do
        expect(
          invoke_with_design(name: "Acme", website_url: page_url, brand_color: "#0066cc"),
        ).to include(status: "success")
        expect(
          invoke_with_design(name: "Acme", website_url: page_url, brand_color: "#0066cc"),
        ).to eq(
          status: "error",
          error: I18n.t("discourse_ai.appearance_authoring.website_rate_limited"),
        )
      end
    end
  end
end
