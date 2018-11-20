require 'rails_helper'
require 'stylesheet/compiler'

describe Stylesheet::Compiler do
  describe 'compilation' do
    Dir["#{Rails.root.join("app/assets/stylesheets")}/*.scss"].each do |path|
      path = File.basename(path, '.scss')

      it "can compile '#{path}' css" do
        css, _map = Stylesheet::Compiler.compile_asset(path)
        expect(css.length).to be > 1000
      end
    end
  end

  it "supports asset-url" do
    css, _map = Stylesheet::Compiler.compile(".body{background-image: asset-url('/images/favicons/github.png');}", "test.scss")

    expect(css).to include("url('/images/favicons/github.png')")
    expect(css).not_to include('asset-url')
  end

  it "supports image-url" do
    css, _map = Stylesheet::Compiler.compile(".body{background-image: image-url('/favicons/github.png');}", "test.scss")

    expect(css).to include("url('/favicons/github.png')")
    expect(css).not_to include('image-url')
  end
end
