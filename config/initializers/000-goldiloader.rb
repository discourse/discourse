# frozen_string_literal: true

require "goldiloader" if (Rails.env.test? || GlobalSetting.try(:load_goldiloader))
