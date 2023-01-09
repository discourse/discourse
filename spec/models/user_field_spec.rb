# frozen_string_literal: true

RSpec.describe UserField do
  describe "doesn't validate presence of name if field type is 'confirm'" do
    subject { described_class.new(field_type: "confirm") }
    it { is_expected.not_to validate_presence_of :name }
  end

  describe "validates presence of name for other field types" do
    subject { described_class.new(field_type: "dropdown") }
    it { is_expected.to validate_presence_of :name }
  end

  it "sanitizes the description" do
    xss = "<b onmouseover=alert('Wufff!')>click me!</b><script>alert('TEST');</script>"
    user_field = Fabricate(:user_field)

    user_field.update!(description: xss)

    expect(user_field.description).to eq("<b>click me!</b>alert('TEST');")
  end

  it "allows target attribute in the description" do
    link = "<a target=\"_blank\" href=\"/elsewhere\">elsewhere</a>"
    user_field = Fabricate(:user_field)

    user_field.update!(description: link)

    expect(user_field.description).to eq(link)
  end
end
