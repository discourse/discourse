require 'rails_helper'
require_dependency 'discourse_plugin'

describe DiscoursePlugin do

  class TestPlugin < DiscoursePlugin
    module SomeModule
    end

    module TestMixin
    end
  end

  let(:registry) { mock }
  let(:plugin) { TestPlugin.new(registry) }

  describe ".mixins" do
    it "finds its mixins" do
      expect(TestPlugin.mixins).to eq([TestPlugin::TestMixin])
    end
  end

  it "delegates adding js to the registry" do
    registry.expects(:register_js).with('test.js', any_parameters)
    plugin.register_js('test.js')
  end

  it "delegates adding css to the registry" do
    registry.expects(:register_css).with('test.css')
    plugin.register_css('test.css')
  end

  it "delegates creating archetypes" do
    registry.expects(:register_archetype).with('banana', oh: 'no!')
    plugin.register_archetype('banana', oh: 'no!')
  end

  context 'registering for callbacks' do
    before do
      plugin.stubs(:hello)
      @proc = plugin.listen_for(:hello).first
    end

    after do
      DiscourseEvent.off(:hello, &@proc)
    end

    it "calls the method when it is triggered" do
      plugin.expects(:hello).with('there')
      DiscourseEvent.trigger(:hello, 'there')
    end

  end

end
