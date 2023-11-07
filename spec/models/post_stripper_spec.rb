# frozen_string_literal: true

RSpec.describe PostStripper do
  it "strips mentions in quotes" do
    mention = '<a class="mention">@andrei</a>'
    cooked = "<aside class='quote'>#{mention}</aside>"
    fragment = Nokogiri::HTML5.fragment(cooked)

    PostStripper.strip(fragment)

    expect(fragment.to_s).to_not include(mention)
  end

  it "strips group mentions in quotes" do
    group_mention = '<a class="mention-group">@moderators</a>'
    cooked = "<aside class='quote'>#{group_mention}</aside>"
    fragment = Nokogiri::HTML5.fragment(cooked)

    PostStripper.strip(fragment)

    expect(fragment.to_s).to_not include(group_mention)
  end

  it "strips oneboxes" do
    onebox =
      '<aside class="onebox">
        Onebox content
      </aside>'
    cooked = "<p>#{onebox}</p>"
    fragment = Nokogiri::HTML5.fragment(cooked)

    PostStripper.strip(fragment)

    expect(fragment.to_s).to_not include(onebox)
  end
end
