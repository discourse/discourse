# frozen_string_literal: true

require 'rails_helper'

describe UserApiKey do
  context "#allow?" do
    it "can look up permissions correctly" do
      key = UserApiKey.new(scopes: ['message_bus', 'notifications'])

      expect(key.allow?("PATH_INFO" => "/random", "REQUEST_METHOD" => "GET")).to eq(false)
      expect(key.allow?("PATH_INFO" => "/message-bus/1234/poll", "REQUEST_METHOD" => "POST")).to eq(true)

      expect(key.allow?("action_dispatch.request.path_parameters" => { controller: "notifications", action: "mark_read" },
                        "PATH_INFO" => "/xyz", "REQUEST_METHOD" => "PUT")).to eq(true)

      expect(key.allow?("action_dispatch.request.path_parameters" => { controller: "user_api_keys", action: "revoke" },
                        "PATH_INFO" => "/xyz", "REQUEST_METHOD" => "POST")).to eq(true)

    end

    it "can allow all correct scopes to write" do

      key = UserApiKey.new(scopes: ["write"])

      expect(key.allow?("PATH_INFO" => "/random", "REQUEST_METHOD" => "GET")).to eq(true)
      expect(key.allow?("PATH_INFO" => "/random", "REQUEST_METHOD" => "PUT")).to eq(true)
      expect(key.allow?("PATH_INFO" => "/random", "REQUEST_METHOD" => "PATCH")).to eq(true)
      expect(key.allow?("PATH_INFO" => "/random", "REQUEST_METHOD" => "DELETE")).to eq(true)
      expect(key.allow?("PATH_INFO" => "/random", "REQUEST_METHOD" => "POST")).to eq(true)
    end

    it "can allow blanket read" do

      key = UserApiKey.new(scopes: ["read"])

      expect(key.allow?("PATH_INFO" => "/random", "REQUEST_METHOD" => "GET")).to eq(true)
      expect(key.allow?("PATH_INFO" => "/random", "REQUEST_METHOD" => "PUT")).to eq(false)
    end
  end
end
