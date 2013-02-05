require 'spec_helper'
require 'discourse_plugin_registry'

describe DiscoursePluginRegistry do

  let(:registry) { DiscoursePluginRegistry.new }

  context '.register_css' do
    before do
      registry.register_css('hello.css')
    end

    it 'is returned by DiscoursePluginRegistry.stylesheets' do
      registry.stylesheets.include?('hello.css').should be_true
    end

    it "won't add the same file twice" do
      lambda { registry.register_css('hello.css') }.should_not change(registry.stylesheets, :size)
    end    
  end

  context '.register_js' do
    before do
      registry.register_js('hello.js')
    end

    it 'is returned by DiscoursePluginRegistry.javascripts' do
      registry.javascripts.include?('hello.js').should be_true
    end

    it "won't add the same file twice" do
      lambda { registry.register_js('hello.js') }.should_not change(registry.javascripts, :size)
    end    
  end

  context '.register_archetype' do
    it "delegates archetypes to the Archetype component" do
      Archetype.expects(:register).with('threaded', hello: 123)
      registry.register_archetype('threaded', hello: 123)
    end
  end

end
