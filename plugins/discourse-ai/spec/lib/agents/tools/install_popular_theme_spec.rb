# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::Tools::InstallPopularTheme do
  fab!(:admin)
  fab!(:other_admin, :admin)
  fab!(:moderator)
  fab!(:ai_agent)

  let(:remote_url) { "https://github.com/discourse/discourse-mint-theme" }
  let(:context) { DiscourseAi::Agents::BotContext.new(user: admin, messages: []) }
  let(:tool) { build_tool("mint") }

  before do
    enable_current_plugin
    allow(RemoteTheme).to receive(:import_theme) do |url, user, guardian:|
      Fabricate(:theme, name: "Mint", user:, remote_theme: RemoteTheme.create!(remote_url: url))
    end
  end

  def build_tool(theme)
    described_class.new({ theme: }, bot_user: Discourse.system_user, llm: nil, context:)
  end

  def build_reviewable(theme = "mint")
    action =
      AiToolAction.create!(
        tool_name: described_class.name,
        tool_parameters: build_tool(theme).parameters_for_approval,
        ai_agent:,
        bot_user_id: Discourse.system_user.id,
      )
    item =
      ReviewableAiToolAction.needs_review!(
        target: action,
        created_by: Discourse.system_user,
        reviewable_by_moderator: true,
      )
    item.add_score(
      Discourse.system_user,
      ReviewableScore.types[:needs_approval],
      force_review: true,
    )
    item
  end

  def approve_as(approver, reviewable)
    context.user = approver
    context.reviewable_id = reviewable.id
    tool.invoke
  end

  def error(key, **params)
    { status: "error", error: I18n.t("discourse_ai.appearance_authoring.#{key}", **params) }
  end

  it "offers only full themes from the popular list" do
    parameter = described_class.signature[:parameters].sole

    expect(parameter[:enum]).to include("graceful", "mint", "concord")
    expect(parameter[:enum]).not_to include("brand_header")
    expect(described_class.signature[:description]).to include(
      "- mint: Mint. #{I18n.t("popular_themes.mint.description")}",
    )
  end

  it "needs approval and says where the theme comes from" do
    expect(described_class.mandatory_approval?).to eq(true)
    expect(tool.approval_title).to eq("Install theme: Mint")
    expect(tool.approval_details).to include(I18n.t("popular_themes.mint.description"), remote_url)
    expect(tool.validation_error).to be_nil
  end

  it "installs the theme once approved, without making it live, and links to a preview" do
    result = nil
    expect { result = approve_as(other_admin, build_reviewable) }.to change {
      AppearanceChange.count
    }.by(1)

    appearance_change = AppearanceChange.last
    expect(RemoteTheme).to have_received(:import_theme).with(
      remote_url,
      other_admin,
      guardian: an_instance_of(Guardian),
    )
    expect(appearance_change).to have_attributes(
      kind: "installed_theme",
      name: "Mint",
      activated_at: nil,
    )
    expect(appearance_change.theme).not_to be_default
    expect(result).to include(
      status: "success",
      appearance_change_id: appearance_change.id,
      preview_url: DiscourseAi::Agents::AppearanceAuthoring.preview_url(appearance_change),
    )
  end

  it "installs nothing without approval" do
    expect(tool.invoke).to eq(error(:approval_required))
    expect(RemoteTheme).not_to have_received(:import_theme)
  end

  it "only installs the theme that was approved" do
    reviewable = build_reviewable("graceful")

    expect(approve_as(other_admin, reviewable)).to eq(error(:approval_required))
    expect(RemoteTheme).not_to have_received(:import_theme)
  end

  it "refuses themes that aren't on the list" do
    expect(build_tool("brand_header").validation_error).to eq(error(:not_popular))
    expect(build_tool("https://github.com/example/theme").validation_error).to eq(
      error(:not_popular),
    )
  end

  context "when the site already has the theme" do
    fab!(:existing_theme) do
      Fabricate(
        :theme,
        name: "Mint Theme",
        remote_theme:
          RemoteTheme.create!(remote_url: "https://github.com/discourse/discourse-mint-theme.git"),
      )
    end

    it "offers to use it, and saves it once approved without installing it again" do
      expect(tool.validation_error).to be_nil
      expect(tool.approval_title).to eq("Use theme: Mint Theme")
      expect(tool.approval_details).to include("Mint Theme is already installed")

      result = approve_as(other_admin, build_reviewable)

      appearance_change = AppearanceChange.last
      expect(RemoteTheme).not_to have_received(:import_theme)
      expect(appearance_change).to have_attributes(kind: "existing_theme", theme: existing_theme)
      expect(result).to include(
        status: "success",
        appearance_change_id: appearance_change.id,
        message: I18n.t("discourse_ai.appearance_authoring.saved_existing_theme"),
      )
    end

    it "requires fresh approval instead of installing a removed theme" do
      reviewable = build_reviewable
      existing_theme.destroy!

      expect(approve_as(other_admin, reviewable)).to eq(error(:approval_required))
      expect(RemoteTheme).not_to have_received(:import_theme)
    end

    it "previews the theme's current palette when reusing a draft" do
      existing_theme.update!(color_scheme: Fabricate(:color_scheme))
      approve_as(other_admin, build_reviewable)
      existing_theme.update!(color_scheme: Fabricate(:color_scheme))

      result = approve_as(other_admin, build_reviewable)

      expect(result[:preview_url]).to eq(
        "#{Discourse.base_url}/?preview_theme_id=#{existing_theme.id}",
      )
      authoring = DiscourseAi::Agents::AppearanceAuthoring
      expect(authoring.change_palettes(AppearanceChange.last)).to eq(
        authoring.theme_palettes(existing_theme),
      )
    end

    it "doesn't need the site to allow new themes" do
      plugin = Plugin::Instance.new
      modifier =
        proc do |decision, request|
          decision.deny!("No new themes here.") if request.feature == :theme_authoring
          decision
        end
      plugin.register_modifier(:admin_assistant_feature_access, &modifier)

      expect(tool.validation_error).to be_nil
    ensure
      DiscoursePluginRegistry.unregister_modifier(
        plugin,
        :admin_assistant_feature_access,
        &modifier
      )
    end

    it "says when it's already the default theme" do
      existing_theme.set_default!

      expect(tool.validation_error).to eq(error(:already_default, name: "Mint Theme"))
    end

    it "makes it live and switches back without removing it" do
      approve_as(other_admin, build_reviewable)
      appearance_change = AppearanceChange.last
      previous_default = Theme.find_default

      expect(
        AppearanceChange::Activate.call(
          params: {
            appearance_change_id: appearance_change.id,
          },
          guardian: admin.guardian,
        ),
      ).to run_successfully
      expect(existing_theme.reload).to be_default
      expect(
        AppearanceChange::Revert.call(
          params: {
            appearance_change_id: appearance_change.id,
          },
          guardian: admin.guardian,
        ),
      ).to run_successfully
      expect(Theme.find_default).to eq(previous_default)
      expect(Theme.exists?(existing_theme.id)).to eq(true)
    end
  end

  it "says when the theme can't be installed" do
    allow(RemoteTheme).to receive(:import_theme).and_raise(RemoteTheme::ImportError, "gone")

    expect(approve_as(other_admin, build_reviewable)).to eq(error(:install_failed))
    expect(AppearanceChange.count).to eq(0)
  end

  it "follows the limits on new themes" do
    plugin = Plugin::Instance.new
    modifier =
      proc do |decision, request|
        decision.deny!("No new themes here.") if request.feature == :theme_authoring
        decision
      end
    plugin.register_modifier(:admin_assistant_feature_access, &modifier)

    expect(tool.validation_error).to eq(status: "error", error: "No new themes here.")
  ensure
    DiscoursePluginRegistry.unregister_modifier(plugin, :admin_assistant_feature_access, &modifier)
  end

  it "only lets administrators approve it" do
    expect(approve_as(moderator, build_reviewable)).to eq(error(:not_allowed))
    expect(RemoteTheme).not_to have_received(:import_theme)
  end

  it "can be made live and switched back like other appearance changes" do
    approve_as(other_admin, build_reviewable)
    appearance_change = AppearanceChange.last

    activate =
      DiscourseAi::Agents::Tools::ActivateAppearanceChange.new(
        { appearance_change_id: appearance_change.id },
        bot_user: Discourse.system_user,
        llm: nil,
        context:,
      )
    expect(activate.approval_changes).to include(
      a_hash_including(
        label: I18n.t("discourse_ai.appearance_authoring.default_theme"),
        after: "Mint",
      ),
    )
    expect(
      AppearanceChange::Activate.call(
        params: {
          appearance_change_id: appearance_change.id,
        },
        guardian: admin.guardian,
      ),
    ).to run_successfully
    expect(appearance_change.theme.reload).to be_default
  end
end
