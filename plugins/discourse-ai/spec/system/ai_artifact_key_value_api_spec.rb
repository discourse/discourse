# frozen_string_literal: true

RSpec.describe "AI Artifact Key-Value API", type: :system, js: true do
  fab!(:user)
  fab!(:private_message_topic) { Fabricate(:private_message_topic, user: user) }
  fab!(:private_message_post) { Fabricate(:post, topic: private_message_topic, user: user) }
  fab!(:artifact) do
    Fabricate(
      :ai_artifact,
      post: private_message_post,
      metadata: {
        public: true,
      },
      html: '<div id="log">Artifact Loaded</div>',
      js: <<~JS,
        const logElement = document.getElementById('log');

        window.addEventListener('load', async function() {
          try {
            logElement.innerHTML = "TESTING KEY-VALUE API...";
            const log = [];
            await window.discourseArtifact.set('test_key', 'test_value');
            log.push('Set operation completed');
            logElement.innerHTML = log.join('<br>');

            const value = await window.discourseArtifact.get('test_key');
            log.push('Got value:' + value);

            await window.discourseArtifact.delete('test_key');
            log.push('Delete operation completed');

            const deletedValue = await window.discourseArtifact.get('test_key');
            log.push('Deleted value should be null:' + deletedValue);

            logElement.innerHTML = log.join('<br>');
            logElement.setAttribute('data-test-complete', 'true');
          } catch (error) {
            logElement.innerHTML = error.message;
            logElement.setAttribute('data-test-error', 'true');
          }
        });
      JS
    )
  end

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
    sign_in(user)
  end

  it "provides working key-value API in artifact JavaScript" do
    visit "/discourse-ai/ai-bot/artifacts/#{artifact.id}"

    within_frame(find("iframe")) do
      expect(page).to have_selector("#log", wait: 2)
      expect(page).to have_selector("#log[data-test-complete='true']", wait: 2)
      expect(page).to have_no_selector("#log[data-test-error]")
    end

    expect(artifact.key_values.find_by(key: "test_key", user: user)).to be_nil
  end
end
