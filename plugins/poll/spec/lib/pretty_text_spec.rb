require 'rails_helper'
require 'html_normalize'

describe PrettyText do

  def n(html)
    HtmlNormalize.normalize(html)
  end

  context 'markdown it' do
    before do
      SiteSetting.enable_experimental_markdown_it = true
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

    it 'works correctly for new vs old engine with trivial cases' do
      md = <<~MD
        [poll]
        1. test 1
        2. test 2
        [/poll]
      MD

      new_engine = n(PrettyText.cook(md))

      SiteSetting.enable_experimental_markdown_it = false
      old_engine = n(PrettyText.cook(md))

      expect(new_engine).to eq(old_engine)
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
        <div class="poll" data-poll-status="open" data-poll-name="poll">
        <div>
        <div class="poll-container">
        <ol>
        <li data-poll-option-id='b6475cbf6acb8676b20c60582cfc487a'>test 1 <img alt=':slight_smile:' class='emoji' src='/images/emoji/twitter/slight_smile.png?v=5' title=':slight_smile:'> <b>test</b>
        </li>
        <li data-poll-option-id='7158af352698eb1443d709818df097d4'>test 2</li>
        </li>
        </ol>
        </div>
        <div class="poll-info">
        <p>
        <span class="info-number">0</span>
        <span class="info-text">voters</span>
        </p>
        <p>
        Choose up to <strong>2</strong> options</p>
        </div>
        </div>
        <div class="poll-buttons">
        <a title="Cast your votes">Vote now!</a>
        <a title="Display the poll results">Show results</a>
        </div>
        </div>
      MD

      # note, hashes should remain stable even if emoji changes cause text content is hashed
      expect(n cooked).to eq(n expected)

    end
  end
end
