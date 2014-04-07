require 'spec_helper'
require 'discourse_plugin_registry'

describe DiscoursePluginRegistry do

  class TestRegistry < DiscoursePluginRegistry; end

  let(:registry) { TestRegistry }
  let(:registry_instance) { registry.new }

  context '#stylesheets' do
    it 'defaults to an empty Set' do
      registry.stylesheets = nil
      registry.stylesheets.should == Set.new
    end
  end

  context '#mobile_stylesheets' do
    it 'defaults to an empty Set' do
      registry.mobile_stylesheets = nil
      registry.mobile_stylesheets.should == Set.new
    end
  end

  context '#javascripts' do
    it 'defaults to an empty Set' do
      registry.javascripts = nil
      registry.javascripts.should == Set.new
    end
  end

  context '#server_side_javascripts' do
    it 'defaults to an empty Set' do
      registry.server_side_javascripts = nil
      registry.server_side_javascripts.should == Set.new
    end
  end

  context '#admin_javascripts' do
    it 'defaults to an empty Set' do
      registry.admin_javascripts = nil
      registry.admin_javascripts.should == Set.new
    end
  end

  context '.register_css' do
    before do
      registry_instance.register_css('hello.css')
    end

    it 'is not leaking' do
      DiscoursePluginRegistry.new.stylesheets.should be_blank
    end

    it 'is returned by DiscoursePluginRegistry.stylesheets' do
      registry_instance.stylesheets.include?('hello.css').should be_true
    end

    it "won't add the same file twice" do
      lambda { registry_instance.register_css('hello.css') }.should_not change(registry.stylesheets, :size)
    end
  end

  context '.register_js' do
    before do
      registry_instance.register_js('hello.js')
    end

    it 'is returned by DiscoursePluginRegistry.javascripts' do
      registry_instance.javascripts.include?('hello.js').should be_true
    end

    it "won't add the same file twice" do
      lambda { registry_instance.register_js('hello.js') }.should_not change(registry.javascripts, :size)
    end
  end

  context '.register_archetype' do
    it "delegates archetypes to the Archetype component" do
      Archetype.expects(:register).with('threaded', hello: 123)
      registry_instance.register_archetype('threaded', hello: 123)
    end
  end

end
