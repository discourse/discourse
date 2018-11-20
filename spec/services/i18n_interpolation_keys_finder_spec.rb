require 'rails_helper'
require "i18n/i18n_interpolation_keys_finder"

RSpec.describe I18nInterpolationKeysFinder do
  describe '#find' do
    it 'should return the right keys' do
      expect(described_class.find('%{first} %{second} {{third}}'))
        .to eq(['first', 'second', 'third'])
    end
  end
end
