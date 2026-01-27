# frozen_string_literal: true

require "multi_json/adapters/active_support"

MultiJson.adapter = MultiJson::Adapters::ActiveSupport
