# frozen_string_literal: true

# Notes remain plaintext, so literal code and quote syntax use the same mention rules.
class PlaintextMentions
  MENTION_PATTERN = /(?<![^\s\p{P}\p{S}])@(\w[\w.-]{0,58}[^\W_]|\w)(?![^\s\p{P}\p{S}])/
  UNICODE_MENTION_PATTERN =
    /(?<![^\s\p{P}\p{S}])@([\p{Alphabetic}\p{M}\p{Nd}_][\p{Alphabetic}\p{M}\p{Nd}._-]{0,58}[\p{Alphabetic}\p{M}\p{Nd}]|[\p{Alphabetic}\p{M}\p{Nd}_])(?![^\s\p{P}\p{S}])/

  def self.known_usernames(contents)
    usernames = contents.flat_map { |content| new(content).usernames }.uniq
    User.where(username_lower: usernames, staged: false).pluck(:username_lower).to_set
  end

  def initialize(content)
    @content = content.to_s
  end

  def usernames
    matches.map { |match| match[1].downcase }.uniq
  end

  def render(known_usernames: nil)
    content = @content
    return "<p>#{ERB::Util.html_escape(content)}</p>" if !SiteSetting.enable_mentions

    users = known_usernames || self.class.known_usernames([content])
    result = +"<p>"
    cursor = 0
    matches.each do |match|
      result << ERB::Util.html_escape(content[cursor...match.begin(0)])
      if users.include?(match[1].downcase)
        href = "#{Discourse.base_path}/u/#{UrlHelper.encode_component(match[1].downcase)}"
        label = PrettyText::Helpers.format_username(match[0])
        result << "<a class=\"mention\" href=\"#{ERB::Util.html_escape(href)}\">#{ERB::Util.html_escape(label)}</a>"
      else
        result << ERB::Util.html_escape(match[0])
      end
      cursor = match.end(0)
    end
    result << ERB::Util.html_escape(content[cursor..])
    result << "</p>"
  end

  private

  def matches
    @matches ||=
      begin
        pattern = SiteSetting.unicode_usernames ? UNICODE_MENTION_PATTERN : MENTION_PATTERN
        @content.to_enum(:scan, pattern).map { Regexp.last_match.dup }
      end
  end
end
