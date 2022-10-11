# frozen_string_literal: true

RSpec.shared_examples "#display_sidebar_tags" do |serializer_klass|
  fab!(:tag) { Fabricate(:tag) }
  fab!(:user) { Fabricate(:user) }
  let(:serializer) { serializer_klass.new(user, scope: Guardian.new(user), root: false) }

  before do
    SiteSetting.enable_experimental_sidebar_hamburger = true
  end

  it 'should not be included in serialised object when experimental hamburger and sidebar has been disabled' do
    SiteSetting.tagging_enabled = true
    SiteSetting.enable_experimental_sidebar_hamburger = false

    expect(serializer.as_json[:display_sidebar_tags]).to eq(nil)
  end

  it 'should not be included in serialised object when tagging has been disabled' do
    SiteSetting.tagging_enabled = false

    expect(serializer.as_json[:display_sidebar_tags]).to eq(nil)
  end

  it 'should be true when user has visible tags' do
    SiteSetting.tagging_enabled = true

    Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [tag.name])
    user.update!(admin: true)

    expect(serializer.as_json[:display_sidebar_tags]).to eq(true)
  end

  it 'should be false when user has no visible tags' do
    SiteSetting.tagging_enabled = true

    Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [tag.name])

    expect(serializer.as_json[:display_sidebar_tags]).to eq(false)
  end
end
