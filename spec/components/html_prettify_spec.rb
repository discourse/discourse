require 'rails_helper'
require 'html_prettify'

describe HtmlPrettify do

  def t(source, expected)
    expect(HtmlPrettify.render(source)).to eq(expected)
  end

  it 'correctly prettifies html' do
    t "<p>All's well!</p>", "<p>All&rsquo;s well!</p>"
    t "<p>Eatin' Lunch'.</p>", "<p>Eatin&rsquo; Lunch&rsquo;.</p>"
    t "<p>a 1/4. is a fraction but not 1/4/2000</p>", "<p>a &frac14;. is a fraction but not 1/4/2000</p>"
    t "<p>Well that'll be the day</p>", "<p>Well that&rsquo;ll be the day</p>"
    t %(<p>"Quoted text"</p>), %(<p>&ldquo;Quoted text&rdquo;</p>)
    t "<p>I've been meaning to tell you ..</p>", "<p>I&rsquo;ve been meaning to tell you ..</p>"
    t "<p>single `backticks` in HTML should be preserved</p>", "<p>single `backticks` in HTML should be preserved</p>"
    t "<p>double hyphen -- ndash --- mdash</p>", "<p>double hyphen &ndash; ndash &mdash; mdash</p>"
    t "a long time ago...", "a long time ago&hellip;"
    t "is 'this a mistake'?", "is &lsquo;this a mistake&rsquo;?"
    t ERB::Util.html_escape("'that went well'"), "&lsquo;that went well&rsquo;"
    t '"that went well"', "&ldquo;that went well&rdquo;"
    t ERB::Util.html_escape('"that went well"'), "&ldquo;that went well&rdquo;"

    t 'src="test.png"&gt; yay', "src=&ldquo;test.png&rdquo;&gt; yay"

    t ERB::Util.html_escape('<img src="test.png"> yay'), "&lt;img src=&ldquo;test.png&rdquo;&gt; yay"
  end

end
