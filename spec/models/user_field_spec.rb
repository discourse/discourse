# frozen_string_literal: true

RSpec.describe UserField do
  it do
    is_expected.to define_enum_for(:requirement).with_values(
      %w[optional for_all_users on_signup for_existing_users],
    )
  end

  describe "doesn't validate presence of name if field type is 'confirm'" do
    subject(:confirm_field) { described_class.new(field_type: "confirm") }

    it { is_expected.not_to validate_presence_of :name }
  end

  describe "validates presence of name for other field types" do
    subject(:dropdown_field) { described_class.new(field_type: "dropdown") }

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

  it "enqueues index user fields job on save" do
    user_field = Fabricate(:user_field)

    user_field.update!(description: "tomtom")

    expect(
      job_enqueued?(job: Jobs::IndexUserFieldsForSearch, args: { user_field_id: user_field.id }),
    ).to eq(true)
  end

  describe "#required?" do
    let(:user_field) { Fabricate(:user_field, requirement:) }

    context "when requirement is optional" do
      let(:requirement) { "optional" }

      it { expect(user_field).not_to be_required }
    end

    context "when requirement is for all users" do
      let(:requirement) { "for_all_users" }

      it { expect(user_field).to be_required }
    end

    context "when requirement is on signup" do
      let(:requirement) { "on_signup" }

      it { expect(user_field).to be_required }
    end
  end
end
