# frozen_string_literal: true

class NavigationDestination
  attr_reader :id, :path

  def initialize(id:, path:, title:, description:, keywords: [], &available)
    if !path.match?(%r{\A/(?!/)[a-zA-Z0-9/_-]*\z})
      raise ArgumentError, "navigation destination must use a static local path without a base path"
    end
    raise ArgumentError, "navigation destination requires an availability block" if !available

    @id = id
    @path = path
    @title = title
    @description = description
    @keywords = keywords
    @available = available
  end

  def available?(guardian)
    @available.call(guardian)
  end

  def search_text
    [
      I18n.t(@title),
      I18n.t(@description),
      I18n.t(@title, locale: :en),
      I18n.t(@description, locale: :en),
      *@keywords,
    ].join(" ").downcase
  end

  def to_h
    {
      id: id,
      title: I18n.t(@title),
      description: I18n.t(@description),
      url: "#{Discourse.base_url}#{path}",
    }
  end
end
