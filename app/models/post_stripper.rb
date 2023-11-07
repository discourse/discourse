# frozen_string_literal: true

# We strip posts before detecting mentions, oneboxes, attachments etc.
# We strip those elements that shouldn't be detected. For example,
# a mention inside a quote should be ignored, so we strip it off.
class PostStripper
  def self.strip(nokogiri_fragment)
    run_core_strippers(nokogiri_fragment)
    run_plugin_strippers(nokogiri_fragment)
    nokogiri_fragment
  end

  private

  def self.run_core_strippers(nokogiri_fragment)
    nokogiri_fragment.css(
      "pre .mention, aside.quote > .title, aside.quote .mention, aside.quote .mention-group, .onebox, .elided",
    ).remove
  end

  def self.run_plugin_strippers(nokogiri_fragment)
    DiscoursePluginRegistry.post_strippers.each do |stripper|
      stripper[:block].call(nokogiri_fragment)
    end
  end

  private_class_method :run_core_strippers, :run_plugin_strippers
end
