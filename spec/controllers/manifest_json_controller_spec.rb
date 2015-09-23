require 'spec_helper'

RSpec.describe ManifestJsonController do
  context 'index' do
    it 'returns the right output' do
      title = 'MyApp'
      SiteSetting.title = title
      get :index
      expect(response.body).to include(title)
    end
  end
end
