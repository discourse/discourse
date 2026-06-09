# frozen_string_literal: true

RSpec.describe "AI artifact composer" do
  fab!(:admin)
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }

  let(:composer) { PageObjects::Components::Composer.new }
  let(:toolbar) { PageObjects::Components::AiArtifactComposerToolbar.new }
  let(:builder) { PageObjects::Modals::AiArtifactBuilder.new }
  let(:composer_artifact) { PageObjects::Components::AiArtifact.new }

  before do
    enable_current_plugin
    Jobs.run_immediately!
  end

  context "when the user cannot create artifacts" do
    it "hides the toolbar option when ai_artifact_security is disabled" do
      SiteSetting.ai_artifact_security = "disabled"
      sign_in(admin)

      visit "/new-topic"

      expect(toolbar).to have_no_insert_artifact_option
    end

    it "hides the toolbar option when the user is not in the allowed group" do
      SiteSetting.ai_artifact_security = "lax"
      SiteSetting.ai_artifact_allowed_groups = ""
      sign_in(user)

      visit "/new-topic"

      expect(toolbar).to have_no_insert_artifact_option
    end
  end

  context "when the user can create artifacts" do
    before do
      SiteSetting.ai_artifact_security = "lax"
      sign_in(admin)
    end

    it "creates an artifact and inserts a reference into the composer" do
      visit "/new-topic"
      toolbar.open_insert_artifact
      builder.fill_in_artifact(name: "My Artifact", html: "<div id='hello'>Hello</div>")
      builder.submit

      expect(composer).to have_value(
        %r{<div class="ai-artifact" data-ai-artifact-id="\d+" data-ai-artifact-version="latest"></div>},
      )
    end

    it "renders the inserted artifact in the composer preview behind a click-to-run" do
      visit "/new-topic"
      toolbar.open_insert_artifact
      builder.fill_in_artifact(name: "Preview Artifact", html: "<div id='hello'>Preview body</div>")
      builder.submit

      composer_artifact.click_run

      expect(composer_artifact).to have_rendered_body("Preview body")
    end

    it "edits an existing artifact in place via the pencil button" do
      topic = Fabricate(:topic, user: admin)
      artifact =
        Fabricate(:ai_artifact, user: admin, name: "My Artifact", html: "<div>Original</div>")
      Fabricate(
        :post,
        user: admin,
        topic: topic,
        raw: "Look\n\n<div class=\"ai-artifact\" data-ai-artifact-id=\"#{artifact.id}\"></div>",
      )
      post = topic.posts.first
      artifact.update!(post: post)
      post_artifact = PageObjects::Components::AiArtifact.new(post: post)

      visit "/t/#{topic.slug}/#{topic.id}"
      post_artifact.click_edit

      expect(builder).to have_field_value("name", artifact.name)

      builder.fill_in_artifact(name: artifact.name, html: "<div id='hello'>Updated</div>")
      builder.submit

      expect(artifact.versions.reload.last.html).to eq("<div id='hello'>Updated</div>")
    end
  end
end
