# frozen_string_literal: true

describe Jobs::ProcessLocalizedCooked do
  subject(:job) { described_class.new }

  fab!(:post)
  fab!(:post_localization) do
    Fabricate(
      :post_localization,
      post: post,
      locale: "ja",
      raw: "これはテスト投稿です。",
      cooked: "<p>これはテスト投稿です。</p>",
    )
  end

  it "returns when the post_localization cannot be found" do
    expect { job.execute(post_localization_id: 999_999) }.not_to raise_error
  end

  it "returns when the post_localization's post is deleted" do
    post_localization.post.destroy!
    expect { job.execute(post_localization_id: post_localization.id) }.not_to raise_error
  end

  it "returns when the post_localization's topic is deleted" do
    post_localization.post.topic.destroy!
    expect { job.execute(post_localization_id: post_localization.id) }.not_to raise_error
  end

  it "does not replace cooked when LocalizedCookedPostProcessor returns blank" do
    LocalizedCookedPostProcessor.any_instance.expects(:html).returns(" ")
    original_cooked = post_localization.cooked

    job.execute(post_localization_id: post_localization.id)

    post_localization.reload
    expect(post_localization.cooked).to eq(original_cooked)
  end

  it "updates cooked when processor makes changes" do
    processed_html = "<p>これはテスト投稿です。</p><div class='onebox'>Processed</div>"
    LocalizedCookedPostProcessor.any_instance.expects(:html).returns(processed_html)

    job.execute(post_localization_id: post_localization.id)

    post_localization.reload
    expect(post_localization.cooked).to eq(processed_html)
  end

  it "does not update cooked when processor returns same content" do
    LocalizedCookedPostProcessor.any_instance.expects(:html).returns(post_localization.cooked)

    expect { job.execute(post_localization_id: post_localization.id) }.not_to change {
      post_localization.reload.cooked
    }
  end

  it "publishes MessageBus notification" do
    processed_html = "<p>これはテスト投稿です。</p><div class='onebox'>Processed</div>"
    LocalizedCookedPostProcessor.any_instance.expects(:html).returns(processed_html)

    messages =
      MessageBus.track_publish("/topic/#{post.topic_id}") do
        job.execute(post_localization_id: post_localization.id)
      end

    expect(messages.length).to eq(1)
    expect(messages.first.data[:type]).to eq(:localized)
    expect(messages.first.data[:id]).to eq(post.id)
  end

  it "processes oneboxes and images" do
    stub_image_size
    onebox_html = <<~HTML
      <aside class="onebox">
        <article class="onebox-body">
          <h3><a href="https://www.discourse.org">Discourse</a></h3>
          <p>A platform for community discussion</p>
        </article>
      </aside>
    HTML

    post_localization.update!(
      raw: "Check out https://www.discourse.org",
      cooked: "<p>Check out https://www.discourse.org</p>\n#{onebox_html}",
    )

    job.execute(post_localization_id: post_localization.id)

    post_localization.reload
    expect(post_localization.cooked).to include("onebox")
  end
end
