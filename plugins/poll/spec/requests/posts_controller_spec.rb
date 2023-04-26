# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostsController do
  let(:admin) { Fabricate(:admin) }

  describe "#create" do
    it "fails gracefully without a post body" do
      key = Fabricate(:api_key).key

      expect do
        post "/posts.json",
             params: {
               title: "this is test body",
             },
             headers: {
               HTTP_API_USERNAME: admin.username,
               HTTP_API_KEY: key,
             }
      end.not_to change { Topic.count }

      expect(response.status).to eq(422)
    end
  end
end
