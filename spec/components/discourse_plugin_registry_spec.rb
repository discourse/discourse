require 'spec_helper'
require 'discourse_plugin_registry'

describe DiscoursePluginRegistry do

  class TestRegistry < DiscoursePluginRegistry; end

  let(:registry) { TestRegistry }
  let(:registry_instance) { registry.new }

  context '#stylesheets' do
    it 'defaults to an empty Set' do
      registry.stylesheets = nil
      expect(registry.stylesheets).to eq(Set.new)
    end
  end

  context '#mobile_stylesheets' do
    it 'defaults to an empty Set' do
      registry.mobile_stylesheets = nil
      expect(registry.mobile_stylesheets).to eq(Set.new)
    end
  end

  context '#javascripts' do
    it 'defaults to an empty Set' do
      registry.javascripts = nil
      expect(registry.javascripts).to eq(Set.new)
    end
  end

  context '#server_side_javascripts' do
    it 'defaults to an empty Set' do
      registry.server_side_javascripts = nil
      expect(registry.server_side_javascripts).to eq(Set.new)
    end
  end

  context '#admin_javascripts' do
    it 'defaults to an empty Set' do
      registry.admin_javascripts = nil
      expect(registry.admin_javascripts).to eq(Set.new)
    end
  end

  context '#seed_data' do
    it 'defaults to an empty Set' do
      registry.seed_data = nil
      expect(registry.seed_data).to be_a(Hash)
      expect(registry.seed_data.size).to eq(0)
    end
  end

  context '.register_css' do
    before do
      registry_instance.register_css('hello.css')
    end

    it 'is not leaking' do
      expect(DiscoursePluginRegistry.new.stylesheets).to be_blank
    end

    it 'is returned by DiscoursePluginRegistry.stylesheets' do
      expect(registry_instance.stylesheets.include?('hello.css')).to eq(true)
    end

    it "won't add the same file twice" do
      expect { registry_instance.register_css('hello.css') }.not_to change(registry.stylesheets, :size)
    end
  end

  context '.register_js' do
    before do
      registry_instance.register_js('hello.js')
    end

    it 'is returned by DiscoursePluginRegistry.javascripts' do
      expect(registry_instance.javascripts.include?('hello.js')).to eq(true)
    end

    it "won't add the same file twice" do
      expect { registry_instance.register_js('hello.js') }.not_to change(registry.javascripts, :size)
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

      expect(registry.mobile_stylesheets.count).to eq(0)
      expect(registry.stylesheets.count).to eq(2)
    end

    it "registers desktop css properly" do
      registry.register_asset("test.css", :desktop)

      expect(registry.mobile_stylesheets.count).to eq(0)
      expect(registry.desktop_stylesheets.count).to eq(1)
      expect(registry.stylesheets.count).to eq(0)
    end

    it "registers mobile css properly" do
      registry.register_asset("test.css", :mobile)

      expect(registry.mobile_stylesheets.count).to eq(1)
      expect(registry.stylesheets.count).to eq(0)
    end

    it "registers desktop css properly" do
      registry.register_asset("test.css", :desktop)

      expect(registry.desktop_stylesheets.count).to eq(1)
      expect(registry.stylesheets.count).to eq(0)
    end

    it "registers sass variable properly" do
      registry.register_asset("test.css", :variables)

      expect(registry.sass_variables.count).to eq(1)
      expect(registry.stylesheets.count).to eq(0)
    end

    it "registers admin javascript properly" do
      registry.register_asset("my_admin.js", :admin)

      expect(registry.admin_javascripts.count).to eq(1)
      expect(registry.javascripts.count).to eq(0)
      expect(registry.server_side_javascripts.count).to eq(0)
    end

    it "registers server side javascript properly" do
      registry.register_asset("my_admin.js", :server_side)

      expect(registry.server_side_javascripts.count).to eq(1)
      expect(registry.javascripts.count).to eq(1)
      expect(registry.admin_javascripts.count).to eq(0)
    end
  end

  context '#register_seed_data' do
    let(:registry) { DiscoursePluginRegistry }

    after do
      registry.reset!
    end

    it "registers seed data properly" do
      registry.register_seed_data("admin_quick_start_title", "Banana Hosting: Quick Start Guide")
      registry.register_seed_data("admin_quick_start_filename", File.expand_path("../docs/BANANA-QUICK-START.md", __FILE__))

      expect(registry.seed_data["admin_quick_start_title"]).to eq("Banana Hosting: Quick Start Guide")
      expect(registry.seed_data["admin_quick_start_filename"]).to eq(File.expand_path("../docs/BANANA-QUICK-START.md", __FILE__))
    end
  end

end
