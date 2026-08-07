# frozen_string_literal: true

RSpec.describe "Share target" do
  fab!(:user)

  let(:composer) { PageObjects::Components::Composer.new }
  let(:share_target_modal) { PageObjects::Modals::ShareTarget.new }

  before { sign_in(user) }

  it "lets the user start a new topic from shared content", mobile: true do
    title = "Shared topic title"
    text = "Shared text from another app"
    url = "https://example.com/shared-link"
    expected_body = "#{text}\n\n#{url}"

    visit("/")
    seed_shared_content(title:, text:, url:, files: [shared_image_file])

    visit("/share-target")

    expect(share_target_modal).to be_open
    expect(share_target_modal).to have_preview_text(text)
    expect(share_target_modal).to have_preview_text(url)

    share_target_modal.click_new_topic

    expect(composer).to be_opened
    expect(composer).to have_input_title(title)

    wait_for(timeout: 5) { composer.composer_input.value.include?("upload://") }
    expect(composer).to have_no_in_progress_uploads

    composer_value = composer.composer_input.value
    expect(composer_value).to include(expected_body)
    expect(composer_value).to match(%r{!\[shared-image\|.*\]\(upload://.*\)})
  end

  def seed_shared_content(title:, text:, url:, files:)
    page.execute_script(<<~JS)
        window.__shareTargetCacheSeeded = false;
        window.__shareTargetCacheSeedError = "";

        (async () => {
          await caches.delete("discourse-share-target");
          const cache = await caches.open("discourse-share-target");
          const files = #{files.to_json};

          for (const [index, file] of files.entries()) {
            const binary = atob(file.base64);
            const bytes = new Uint8Array(binary.length);

            for (let byteIndex = 0; byteIndex < binary.length; byteIndex++) {
              bytes[byteIndex] = binary.charCodeAt(byteIndex);
            }

            await cache.put(
              new Request(file.key),
              new Response(
                new Blob([bytes], { type: file.type }),
                {
                  headers: {
                    "content-type": file.type,
                    "x-share-filename": encodeURIComponent(file.name || `shared-file-${index}`),
                  },
                }
              )
            );
          }

          await cache.put(
            new Request("/__discourse_share_target__/meta"),
            new Response(
              JSON.stringify({
                title: #{title.to_json},
                text: #{text.to_json},
                url: #{url.to_json},
                files: files.map(({ key, name, type }) => ({ key, name, type })),
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

  def shared_image_file
    {
      key: "/__discourse_share_target__/file-0",
      name: "shared-image.png",
      type: "image/png",
      base64:
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=",
    }
  end
end
