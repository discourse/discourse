require 'rails_helper'

RSpec.describe ListController do
  let(:topic) { Fabricate(:topic) }

  describe 'titles for crawler layout' do
    it 'has no title for the default URL' do
      topic
      filter = Discourse.anonymous_filters[0]
      get "/#{filter}", params: { _escaped_fragment_: 'true' }

      expect(response.body).to include(I18n.t("rss_description.posts"))

      expect(response.body).to_not include(
        I18n.t('js.filters.with_topics', filter: filter)
      )
    end

    it 'has a title for non-default URLs' do
      topic
      filter = Discourse.anonymous_filters[1]
      get "/#{filter}", params: { _escaped_fragment_: 'true' }

      expect(response.body).to include(
        I18n.t('js.filters.with_topics', filter: filter)
      )
    end
  end
end
