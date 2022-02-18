# frozen_string_literal: true

require 'rails_helper'

describe ActiveSupport::SafeBuffer do
  it "can cope with encoding weirdness" do
    buffer = ActiveSupport::SafeBuffer.new
    buffer << (+"\330").force_encoding("ASCII-8BIT")
    buffer.force_encoding "ASCII-8BIT"
    buffer << "hello\330\271"
    buffer << (+"hello#{254.chr}").force_encoding("ASCII-8BIT").freeze

    # we pay a cost for force encoding, the h gets dropped
    expect(buffer).to match(/ello.*hello/)
  end
end
