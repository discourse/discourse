# frozen_string_literal: true

class EmojisController < ApplicationController
  def index
    render json: MultiJson.dump(Emoji.grouped)
  end

  def search_aliases
    aliases = Emoji.search_aliases

    locale_aliases = Emoji.locale_search_aliases(I18n.locale)
    if locale_aliases
      aliases =
        aliases.merge(locale_aliases) { |_key, base_val, locale_val| (base_val + locale_val).uniq }
    end

    render json: MultiJson.dump(aliases)
  end
end
