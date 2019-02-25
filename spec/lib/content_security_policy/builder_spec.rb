# frozen_string_literal: true
require 'rails_helper'

describe ContentSecurityPolicy::Builder do
  let(:builder) { described_class.new }

  describe '#<<' do
    it 'normalizes directive name' do
      builder << {
        script_src: ['symbol_underscore'],
        'script-src': ['symbol_dash'],
        'script_src' => ['string_underscore'],
        'script-src' => ['string_dash'],
      }

      script_srcs = parse(builder.build)['script-src']

      expect(script_srcs).to include(*%w[symbol_underscore symbol_dash string_underscore symbol_underscore])
    end

    it 'rejects invalid directives and ones that are not allowed to be extended' do
      builder << {
        invalid_src: ['invalid'],
      }

      expect(builder.build).to_not include('invalid')
    end

    it 'no-ops on invalid values' do
      previous = builder.build

      builder << nil
      builder << 123
      builder << "string"
      builder << []
      builder << {}

      expect(builder.build).to eq(previous)
    end
  end

  def parse(csp_string)
    csp_string.split(';').map do |policy|
      directive, *sources = policy.split
      [directive, sources]
    end.to_h
  end
end
