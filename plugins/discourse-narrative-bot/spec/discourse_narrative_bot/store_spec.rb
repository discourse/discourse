require 'rails_helper'

describe DiscourseNarrativeBot::Store do
  describe '.set' do
    it 'should set the right value in the plugin store' do
      key = 'somekey'
      described_class.set(key, 'yay')
      plugin_store_row = PluginStoreRow.last

      expect(plugin_store_row.value).to eq('yay')
      expect(plugin_store_row.plugin_name).to eq(DiscourseNarrativeBot::PLUGIN_NAME)
      expect(plugin_store_row.key).to eq(key)
    end
  end

  describe '.get' do
    it 'should get the right value from the plugin store' do
      PluginStoreRow.create!(
        plugin_name: DiscourseNarrativeBot::PLUGIN_NAME,
        key: 'somekey',
        value: 'yay',
        type_name: 'string'
      )

      expect(described_class.get('somekey')).to eq('yay')
    end
  end
end
