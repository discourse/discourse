require 'rails_helper'
require_dependency 'category'

describe CategorySerializer do
  let(:category) { Fabricate(:category) }

  it 'includes custom fields' do
    category.custom_fields['enable_marketplace'] = true
    category.save_custom_fields

    json =
      described_class.new(category, scope: Guardian.new, root: false).as_json
    expect(json[:custom_fields]).to be_present
  end
end
