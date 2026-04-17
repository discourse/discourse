# frozen_string_literal: true

describe "discourse_workflows_enabled site setting hook" do
  it "calls PluginEnableHandler.handle! when the setting flips false to true" do
    allow(DiscourseWorkflows::PluginEnableHandler).to receive(:handle!)

    SiteSetting.discourse_workflows_enabled = false
    SiteSetting.discourse_workflows_enabled = true

    expect(DiscourseWorkflows::PluginEnableHandler).to have_received(:handle!).once
  end

  it "does not call PluginEnableHandler.handle! when the setting flips true to false" do
    allow(DiscourseWorkflows::PluginEnableHandler).to receive(:handle!)

    SiteSetting.discourse_workflows_enabled = false

    expect(DiscourseWorkflows::PluginEnableHandler).not_to have_received(:handle!)
  end

  it "does not call PluginEnableHandler.handle! for unrelated settings" do
    allow(DiscourseWorkflows::PluginEnableHandler).to receive(:handle!)

    DiscourseEvent.trigger(:site_setting_changed, :title, "old", "new")

    expect(DiscourseWorkflows::PluginEnableHandler).not_to have_received(:handle!)
  end
end
