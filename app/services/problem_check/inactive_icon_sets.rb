# frozen_string_literal: true

# Only one icon set applies per theme, so a second declaring component is
# discarded. Without this it looks installed and enabled while doing nothing.
class ProblemCheck::InactiveIconSets < ProblemCheck
  self.priority = "low"

  def call
    return no_problem if inactive.empty?

    problem
  end

  private

  def translation_data
    { themes_list: }
  end

  def inactive
    @inactive ||= SvgSprite.inactive_icon_set_themes
  end

  def themes_list
    <<~HTML.squish
      <ul>#{
      inactive
        .map do |name, id|
          "<li><a href=\"#{Discourse.base_path}/admin/customize/themes/#{id}\">#{CGI.escapeHTML(name)}</a></li>"
        end
        .join("\n")
    }</ul>
    HTML
  end
end
