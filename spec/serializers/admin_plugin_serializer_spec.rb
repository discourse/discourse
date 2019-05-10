# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AdminPluginSerializer do
  let(:instance) { Plugin::Instance.new }

  subject { described_class.new(instance) }

  describe 'enabled_setting' do
    it 'should return the right value' do
      instance.enabled_site_setting('test')
      expect(subject.enabled_setting).to eq('test')
    end
  end
end
