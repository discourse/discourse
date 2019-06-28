# frozen_string_literal: true

require "rails_helper"

describe 'Oj' do
  it "is enabled" do
    classes = Set.new
    tracer = TracePoint.new(:c_call) { |tp| classes << tp.defined_class }
    tracer.enable { ActiveModel::ArraySerializer.new([1, 2, 3]).to_json }

    expect(classes).to include(Oj::Rails::Encoder)
  end

  it "escapes HTML entities the same as ActiveSupport" do
    expect("<b>hello</b>".to_json).to eq("\"\\u003cb\\u003ehello\\u003c/b\\u003e\"")
    expect('"hello world"'.to_json). to eq('"\"hello world\""')
    expect("\u2028\u2029><&".to_json).to eq('"\u2028\u2029\u003e\u003c\u0026"')
  end
end
