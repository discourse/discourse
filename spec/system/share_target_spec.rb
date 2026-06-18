# frozen_string_literal: true

RSpec.describe "Share target" do
  fab!(:user)

  let(:composer) { PageObjects::Components::Composer.new }
  let(:share_target_modal) { PageObjects::Modals::ShareTarget.new }

  before { sign_in(user) }

  it "lets the user start a new topic from shared content" do
    title = "Shared topic title"
    text = "Shared text from another app"
    url = "https://example.com/shared-link"
    expected_body = "#{text}\n\n#{url}"

    visit("/")
    seed_shared_content(title:, text:, url:)

    visit("/share-target")

    expect(share_target_modal).to be_open
    expect(share_target_modal).to have_preview_text(text)
    expect(share_target_modal).to have_preview_text(url)

    share_target_modal.click_new_topic

    expect(composer).to be_opened
    expect(composer).to have_input_title(title)
    expect(composer).to have_value(expected_body)
  end

  def seed_shared_content(title:, text:, url:)
    page.execute_script(<<~JS)
        window.__shareTargetCacheSeeded = false;
        window.__shareTargetCacheSeedError = "";

        (async () => {
          await caches.delete("discourse-share-target");
          const cache = await caches.open("discourse-share-target");
          await cache.put(
            new Request("/__discourse_share_target__/meta"),
            new Response(
              JSON.stringify({
                title: #{title.to_json},
                text: #{text.to_json},
                url: #{url.to_json},
                files: [],
              }),
              { headers: { "content-type": "application/json" } }
            )
          );
          window.__shareTargetCacheSeeded = true;
        })().catch((error) => {
          window.__shareTargetCacheSeedError = `${error.name}: ${error.message}`;
        });
      JS

    wait_for(timeout: 5) { page.evaluate_script("window.__shareTargetCacheSeeded === true") }

    expect(page.evaluate_script("window.__shareTargetCacheSeedError")).to eq("")
  end
end
