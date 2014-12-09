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
      registry_instance.stylesheets.include?('hello.css').should == true
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
      registry_instance.javascripts.include?('hello.js').should == true
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

  context '#register_asset' do
    let(:registry) { DiscoursePluginRegistry }

    after do
      registry.reset!
    end

    it "does register general css properly" do
      registry.register_asset("test.css")
      registry.register_asset("test2.css")

      registry.mobile_stylesheets.count.should == 0
      registry.stylesheets.count.should == 2
    end

    it "registers desktop css properly" do
      registry.register_asset("test.css", :desktop)

      registry.mobile_stylesheets.count.should == 0
      registry.desktop_stylesheets.count.should == 1
      registry.stylesheets.count.should == 0
    end

    it "registers mobile css properly" do
      registry.register_asset("test.css", :mobile)

      registry.mobile_stylesheets.count.should == 1
      registry.stylesheets.count.should == 0
    end

    it "registers desktop css properly" do
      registry.register_asset("test.css", :desktop)

      registry.desktop_stylesheets.count.should == 1
      registry.stylesheets.count.should == 0
    end

    it "registers sass variable properly" do
      registry.register_asset("test.css", :variables)

      registry.sass_variables.count.should == 1
      registry.stylesheets.count.should == 0
    end

    it "registers admin javascript properly" do
      registry.register_asset("my_admin.js", :admin)

      registry.admin_javascripts.count.should == 1
      registry.javascripts.count.should == 0
      registry.server_side_javascripts.count.should == 0
    end

    it "registers server side javascript properly" do
      registry.register_asset("my_admin.js", :server_side)

      registry.server_side_javascripts.count.should == 1
      registry.javascripts.count.should == 1
      registry.admin_javascripts.count.should == 0
    end
  end

end
