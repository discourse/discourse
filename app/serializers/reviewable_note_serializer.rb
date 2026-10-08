# frozen_string_literal: true

class ReviewableNoteSerializer < ApplicationSerializer
  MENTION_PATTERN = /(?<![^\s\p{P}\p{S}])@(\w[\w.-]{0,58}[^\W_]|\w)(?![^\s\p{P}\p{S}])/
  UNICODE_MENTION_PATTERN =
    /(?<![^\s\p{P}\p{S}])@([\p{Alphabetic}\p{M}\p{Nd}_][\p{Alphabetic}\p{M}\p{Nd}._-]{0,58}[\p{Alphabetic}\p{M}\p{Nd}]|[\p{Alphabetic}\p{M}\p{Nd}_])(?![^\s\p{P}\p{S}])/

  attributes :id, :content, :cooked, :created_at, :updated_at

  has_one :user, serializer: BasicUserSerializer, embed: :objects

  def cooked
    content = object.content.to_s
    return "<p>#{ERB::Util.html_escape(content)}</p>" if !SiteSetting.enable_mentions

    pattern = SiteSetting.unicode_usernames ? UNICODE_MENTION_PATTERN : MENTION_PATTERN
    matches = content.to_enum(:scan, pattern).map { Regexp.last_match.dup }
    usernames = matches.map { |match| match[1].downcase }.uniq
    users = User.where(username_lower: usernames, staged: false).pluck(:username_lower).to_set

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
end
