# frozen_string_literal: true

require 'rails_helper'

describe HighlightJs do
  it 'can list languages' do
    expect(HighlightJs.languages).to include('thrift')
  end

  it 'can generate a packed bundle' do
    bundle = HighlightJs.bundle(["thrift", "http"])
    expect(bundle).to match(/thrift/)
    expect(bundle).to match(/http/)
    expect(bundle).not_to match(/applescript/)
  end

  it 'can get a version string' do
    version1 = HighlightJs.version("http|cpp")
    version2 = HighlightJs.version("rust|cpp|fake")

    expect(version1).not_to eq(version2)
  end
end
