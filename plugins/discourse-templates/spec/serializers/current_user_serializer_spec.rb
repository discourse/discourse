# frozen_string_literal: true

require "rails_helper"

describe CurrentUserSerializer, type: :serializer do
  subject(:serializer) { described_class.new(user, scope: guardian, root: false) }

  describe "CurrentUserSerializer extension" do
    let!(:user) { Fabricate(:user) }
    let!(:guardian) { Guardian.new(user) }

    it "includes can_use_templates in serialization" do
      json = serializer.as_json
      expect(json).to have_key(:can_use_templates)
    end
  end
end
