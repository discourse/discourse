# frozen_string_literal: true

RSpec.describe PrettyText do
  def n(html)
    html.strip
  end

  it "supports multi choice polls" do
    cooked = PrettyText.cook <<~MD
      [poll type=multiple min=1 max=3 public=true]
      * option 1
      * option 2
      * option 3
      [/poll]
    MD

    expect(cooked).to include(
      '<div class="poll" data-poll-max="3" data-poll-min="1" data-poll-name="poll" data-poll-public="true" data-poll-status="open" data-poll-type="multiple">',
    )
  end

  it "supports dynamic attribute passthrough" do
    cooked = PrettyText.cook <<~MD
      [poll dynamic=true]
      * A
      * B
      [/poll]
    MD

    expect(cooked).to include('data-poll-dynamic="true"')
  end

  it "can dynamically generate a poll" do
    cooked = PrettyText.cook <<~MD
      [poll type=number min=1 max=20 step=1]
      [/poll]
    MD

    expect(cooked.scan("<li").length).to eq(20)
  end

  it "can properly bake 2 polls" do
    cooked = PrettyText.cook <<~MD
      this is a test

      - i am a list

      [poll]
      1. test 1
      2. test 2
      [/poll]

      [poll name=poll2]
      1. test 1
      2. test 2
      [/poll]
    MD

    expect(cooked.scan('class="poll"').length).to eq(2)
  end

  it "does not break poll options when going from loose to tight" do
    tight_cooked = PrettyText.cook <<~MD
      [poll type=multiple]
      1. test 1 :) <b>test</b>
      2. test 2
      [/poll]
    MD

    loose_cooked = PrettyText.cook <<~MD
      [poll type=multiple]

      1. test 1 :) <b>test</b>

      2. test 2

      [/poll]
    MD

    tight_hashes = tight_cooked.scan(/data-poll-option-id=['"]([^'"]+)/)
    loose_hashes = loose_cooked.scan(/data-poll-option-id=['"]([^'"]+)/)

    expect(tight_hashes.size).to eq(2)
    expect(tight_hashes).to eq(loose_hashes)
  end

  it "can correctly cook polls" do
    cooked = PrettyText.cook <<~MD
      [poll type=multiple]
      1. test 1 :) <b>test</b>
      2. test 2
      [/poll]
    MD

    expected = <<~HTML
      <div class="poll" data-poll-name="poll" data-poll-status="open" data-poll-type="multiple">
      <div class="poll-container">
      <ol>
      <li data-poll-option-id="b6475cbf6acb8676b20c60582cfc487a">test 1 <img src="/images/emoji/twitter/slight_smile.png?v=#{Emoji::EMOJI_VERSION}" title=":slight_smile:" class="emoji" alt=":slight_smile:" loading="lazy" width="20" height="20"> <b>test</b></li>
      <li data-poll-option-id="7158af352698eb1443d709818df097d4">test 2</li>
      </ol>
      </div>
      <div class="poll-info">
      <div class="poll-info_counts">
      <div class="poll-info_counts-count">
      <span class="info-number">0</span>
      <span class="info-label">voters</span>
      </div>
      </div>
      </div>
      </div>
    HTML

    # note, hashes should remain stable even if emoji changes cause text content is hashed
    expect(n cooked).to eq(n expected)
  end

  it "can onebox posts" do
    post = Fabricate(:post, raw: <<~MD)
      A post with a poll

      [poll type=regular]
      * Hello
      * World
      [/poll]
    MD

    onebox = Oneboxer.onebox_raw(post.full_url, user_id: Fabricate(:user).id)

    expect(onebox[:preview]).to include("A post with a poll")
    expect(onebox[:preview]).to include("<a href=\"#{post.url}\">poll</a>")
  end

  it "can reduce excerpts" do
    post = Fabricate(:post, raw: <<~MD)
      A post with a poll

      [poll type=regular]
      * Hello
      * World
      [/poll]
    MD

    excerpt = PrettyText.excerpt(post.cooked, SiteSetting.post_onebox_maxlength, post: post)
    expect(excerpt).to eq("A post with a poll \n<a href=\"#{post.url}\">poll</a>")

    excerpt = PrettyText.excerpt(post.cooked, SiteSetting.post_onebox_maxlength)
    expect(excerpt).to eq("A post with a poll \npoll")
  end

  it "supports the title attribute" do
    cooked = PrettyText.cook <<~MD
      [poll]
      # What's your favorite *berry*? :wink: https://google.com/
      * Strawberry
      * Raspberry
      * Blueberry
      [/poll]
    MD

    expect(cooked).to include <<~HTML
      <div class="poll-title">What’s your favorite <em>berry</em>? <img src="/images/emoji/twitter/wink.png?v=#{Emoji::EMOJI_VERSION}" title=":wink:" class="emoji" alt=":wink:" loading="lazy" width="20" height="20"> <a href="https://google.com/" rel="noopener nofollow ugc">https://google.com/</a></div>
    HTML
  end

  it "supports polls in block quotes" do
    cooked = PrettyText.cook <<~MD
      [quote]

      [poll]
      * Strawberry
      * Raspberry
      * Blueberry
      [/poll]

      [/quote]
    MD

    expect(cooked).to include "<blockquote>"
    expect(cooked).to include '<div class="poll" data-poll-name="poll" data-poll-status="open">'
  end

  it "supports polls in quotes" do
    cooked = PrettyText.cook <<~MD
      > [poll]
      > * Strawberry
      > * Raspberry
      > * Blueberry
      > [/poll]
    MD

    expect(cooked).to include "<blockquote>"
    expect(cooked).to include '<div class="poll" data-poll-name="poll" data-poll-status="open">'
  end

  it "supports polls in details" do
    cooked = PrettyText.cook <<~MD
      [details=please vote]

      [poll]
      * Strawberry
      * Raspberry
      * Blueberry
      [/poll]

      [/details]
    MD

    expect(cooked).to include "<details>"
    expect(cooked).to include '<div class="poll" data-poll-name="poll" data-poll-status="open">'
  end

  it "does not break when there are headings before/after a poll with a title" do
    cooked = PrettyText.cook <<~MD
      # Pre-heading

      [poll]
      # What's your favorite *berry*? :wink: https://google.com/
      * Strawberry
      * Raspberry
      * Blueberry
      [/poll]

      # Post-heading
    MD

    expect(cooked).to include <<~HTML
      <div class="poll-title">What’s your favorite <em>berry</em>? <img src="/images/emoji/twitter/wink.png?v=#{Emoji::EMOJI_VERSION}" title=":wink:" class="emoji" alt=":wink:" loading="lazy" width="20" height="20"> <a href="https://google.com/" rel="noopener nofollow ugc">https://google.com/</a></div>
    HTML

    expect(cooked).to include(
      '<h1><a name="pre-heading-1" class="anchor" href="#pre-heading-1"></a>Pre-heading</h1>',
    )
    expect(cooked).to include(
      '<h1><a name="post-heading-2" class="anchor" href="#post-heading-2"></a>Post-heading</h1>',
    )
  end

  it "does not break when there are headings before/after a poll without a title" do
    cooked = PrettyText.cook <<~MD
      # Pre-heading

      [poll]
      * Strawberry
      * Raspberry
      * Blueberry
      [/poll]

      # Post-heading
    MD

    expect(cooked).to_not include('<div class="poll-title">')

    expect(cooked).to include('<div class="poll" data-poll-name="poll" data-poll-status="open">')

    expect(cooked).to include(
      '<h1><a name="pre-heading-1" class="anchor" href="#pre-heading-1"></a>Pre-heading</h1>',
    )

    expect(cooked).to include(
      '<h1><a name="post-heading-2" class="anchor" href="#post-heading-2"></a>Post-heading</h1>',
    )
  end
end
