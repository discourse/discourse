require 'rails_helper'

describe SimilarTopicsController do
  context 'similar_to' do

    let(:title) { 'this title is long enough to search for' }
    let(:raw) { 'this body is long enough to search for' }

    it "requires a title" do
      expect do
        get :index, params: { raw: raw }, format: :json
      end.to raise_error(ActionController::ParameterMissing)
    end

    it "returns no results if the title length is below the minimum" do
      Topic.expects(:similar_to).never
      SiteSetting.min_title_similar_length = 100
      get :index, params: { title: title, raw: raw }, format: :json
      json = ::JSON.parse(response.body)
      expect(json["similar_topics"].size).to eq(0)
    end

    describe "minimum_topics_similar" do

      before do
        SiteSetting.minimum_topics_similar = 30
      end

      after do
        get :index, params: { title: title, raw: raw }, format: :json
      end

      describe "With enough topics" do
        before do
          Topic.stubs(:count).returns(50)
        end

        it "deletes to Topic.similar_to if there are more topics than `minimum_topics_similar`" do
          Topic.expects(:similar_to).with(title, raw, nil).returns([Fabricate(:topic)])
        end

        describe "with a logged in user" do
          let(:user) { log_in }

          it "passes a user through if logged in" do
            Topic.expects(:similar_to).with(title, raw, user).returns([Fabricate(:topic)])
          end
        end

      end

      it "does not call Topic.similar_to if there are fewer topics than `minimum_topics_similar`" do
        Topic.stubs(:count).returns(10)
        Topic.expects(:similar_to).never
      end

    end

  end

end
