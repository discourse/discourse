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

  context "with plugins" do
    after { DiscoursePluginRegistry.reset_register!(:post_strippers) }

    it "runs strippers registered by plugins" do
      plugin_element = '<div class="plugin_class"></div>'

      block = Proc.new { |nokogiri_fragment| nokogiri_fragment.css(".plugin_class").remove }
      plugin = OpenStruct.new(enabled?: true)
      DiscoursePluginRegistry.register_post_stripper({ block: block }, plugin)

      fragment = Nokogiri::HTML5.fragment("<p>#{plugin_element}</p>")

      PostStripper.strip(fragment)

      expect(fragment.to_s).to_not include(plugin_element)
    end
  end
end
