# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::Tools::UpdateSetting do
  fab!(:llm_model)
  fab!(:admin)

  let(:bot_user) { DiscourseAi::AiBot::EntryPoint.find_user_from_model(llm_model.name) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy(llm_model) }
  let(:context) { DiscourseAi::Agents::BotContext.new(user: admin) }

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
  end

  def tool(params = nil, **kwargs)
    params ||= kwargs
    described_class.new(params, bot_user: bot_user, llm: llm, context: context)
  end

  it "updates a site setting and logs the approving administrator" do
    result = tool(setting_name: "title", value: "A different forum").invoke

    expect(result[:status]).to eq("success")
    expect(SiteSetting.title).to eq("A different forum")

    history = UserHistory.where(action: UserHistory.actions[:change_site_setting]).last
    expect(history).to have_attributes(
      acting_user_id: admin.id,
      subject: "title",
      new_value: "A different forum",
    )
  end

  it "rejects updates from non-admins" do
    regular_user = Fabricate(:user)
    context.user = regular_user

    result = tool(setting_name: "title", value: "A different forum").invoke

    expect(result[:status]).to eq("error")
    expect(SiteSetting.title).not_to eq("A different forum")
  end

  it "rejects unknown settings" do
    result = tool(setting_name: "not_a_site_setting", value: "value").invoke

    expect(result[:status]).to eq("error")
  end
end
