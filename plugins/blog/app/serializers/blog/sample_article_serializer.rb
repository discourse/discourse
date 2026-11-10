# frozen_string_literal: true

module ::Blog
  class SampleArticleSerializer < ApplicationSerializer
    attributes :id, :title

    def title
      object.article.title
    end
  end
end
