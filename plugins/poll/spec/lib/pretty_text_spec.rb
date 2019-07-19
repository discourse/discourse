# frozen_string_literal: true

require 'rails_helper'

describe PrettyText do

  def n(html)
    html.strip
  end

  it 'supports multi choice polls' do
    cooked = PrettyText.cook <<~MD
      [poll type=multiple min=1 max=3 public=true]
      * option 1
      * option 2
      * option 3
      [/poll]
    MD

    expect(cooked).to include('class="poll"')
    expect(cooked).to include('data-poll-status="open"')
    expect(cooked).to include('data-poll-name="poll"')
    expect(cooked).to include('data-poll-type="multiple"')
    expect(cooked).to include('data-poll-min="1"')
    expect(cooked).to include('data-poll-max="3"')
    expect(cooked).to include('data-poll-public="true"')
  end

  it 'can dynamically generate a poll' do

    cooked = PrettyText.cook <<~MD
      [poll type=number min=1 max=20 step=1]
      [/poll]
    MD

    expect(cooked.scan('<li').length).to eq(20)
  end

  it 'can properly bake 2 polls' do
    md = <<~MD
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

    cooked = PrettyText.cook(md)
    expect(cooked.scan('class="poll"').length).to eq(2)
  end

  it 'does not break poll options when going from loose to tight' do
    md = <<~MD
      [poll type=multiple]
      1. test 1 :) <b>test</b>
      2. test 2
      [/poll]
    MD

    tight_cooked = PrettyText.cook(md)

    md = <<~MD
      [poll type=multiple]

      1. test 1 :) <b>test</b>

      2. test 2

      [/poll]
    MD

    loose_cooked = PrettyText.cook(md)

    tight_hashes = tight_cooked.scan(/data-poll-option-id=['"]([^'"]+)/)
    loose_hashes = loose_cooked.scan(/data-poll-option-id=['"]([^'"]+)/)

    expect(tight_hashes).to eq(loose_hashes)
  end

  it 'can correctly cook polls' do
    md = <<~MD
      [poll type=multiple]
      1. test 1 :) <b>test</b>
      2. test 2
      [/poll]
    MD

    cooked = PrettyText.cook md

    expected = <<~MD
      <div class="poll" data-poll-status="open" data-poll-type="multiple" data-poll-name="poll">
      <div>
      <div class="poll-container">
      <ol>
      <li data-poll-option-id="b6475cbf6acb8676b20c60582cfc487a">test 1 <img src="/images/emoji/twitter/slight_smile.png?v=#{Emoji::EMOJI_VERSION}" title=":slight_smile:" class="emoji" alt=":slight_smile:"> <b>test</b>
      </li>
      <li data-poll-option-id="7158af352698eb1443d709818df097d4">test 2</li>
      </ol>
      </div>
      <div class="poll-info">
      <p>
      <span class="info-number">0</span>
      <span class="info-label">voters</span>
      </p>
      </div>
      </div>
      </div>
    MD

    # note, hashes should remain stable even if emoji changes cause text content is hashed
    expect(n cooked).to eq(n expected)

  end

  it 'can onebox posts' do
    post = Fabricate(:post, raw: <<~MD)
      A post with a poll

      [poll type=regular]
      * Hello
      * World
      [/poll]
    MD

    onebox = Oneboxer.onebox_raw(post.full_url, user_id: Fabricate(:user).id)
    doc = Nokogiri::HTML(onebox[:preview])

    expect(onebox[:preview]).to include("A post with a poll")
    expect(onebox[:preview]).to include("<a href=\"#{post.url}\">poll</a>")
  end

  it 'can reduce excerpts' do
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
end
