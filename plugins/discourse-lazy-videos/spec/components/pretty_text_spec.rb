# frozen_string_literal: true

require "rails_helper"
require "pretty_text"

RSpec.describe PrettyText do
  let(:post) { Fabricate(:post) }

  it "replaces lazy videos in emails" do
    cooked_html = <<~HTML
      <div class="youtube-onebox lazy-video-container" data-video-id="kPRA0W1kECg" data-video-title="15 Sorting Algorithms in 6 Minutes" data-provider-name="youtube">
        <a href="https://www.youtube.com/watch?v=kPRA0W1kECg" target="_blank" rel="noopener">
          <img class="youtube-thumbnail" src="thumbnail.jpeg" title="15 Sorting Algorithms in 6 Minutes" width="690" height="388">
        </a>
      </div>

      <div class="vimeo-onebox lazy-video-container" data-video-id="786646692" data-video-title="Dear Rich" data-provider-name="vimeo">
        <a href="https://vimeo.com/786646692" target="_blank" rel="noopener">
          <img class="vimeo-thumbnail" src="thumbnail.jpeg" title="Dear Rich" width="640" height="360">
        </a>
      </div>

    HTML

    email_formated = <<~HTML
      <p><a href="https://www.youtube.com/watch?v=kPRA0W1kECg">15 Sorting Algorithms in 6 Minutes</a></p>
      <p><a href="https://vimeo.com/786646692">Dear Rich</a></p>
      HTML

    expect(PrettyText.format_for_email(cooked_html, post)).to match_html(email_formated)
  end
end
