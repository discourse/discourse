# frozen_string_literal: true

RSpec.describe Blog::BlogTheme::AttributesContract, type: :model do
  subject(:contract) { described_class.new(**attributes) }

  let(:attributes) do
    {
      name: "Quiet draft",
      accent_color: "112233",
      paper_color: "fafafa",
      ink_color: "AABBCC",
      css: ".blog { color: red; }",
      javascript: "",
    }
  end
  let(:invalid_message) { I18n.t("blog.themes.invalid") }
  let(:template_message) { I18n.t("blog.themes.template_invalid") }

  it do
    is_expected.to allow_value("a" * 100).for(:name).with_message(invalid_message, against: :base)
  end

  it do
    is_expected.not_to allow_values("", "   ", "a" * 101, nil).for(:name).with_message(
      invalid_message,
      against: :base,
    )
  end

  it "accepts only six-digit hexadecimal colors" do
    Blog::BlogTheme::COLOR_FIELDS.each do |field|
      expect(described_class.new(**attributes)).to allow_value("09afAF").for(field).with_message(
        invalid_message,
        against: :base,
      )
      expect(described_class.new(**attributes)).not_to allow_values(
        "red; }",
        "12345",
        "1234567",
        "#12345",
        nil,
      ).for(field).with_message(invalid_message, against: :base)
    end
  end

  it "bounds CSS and JavaScript by bytes and encoding" do
    Blog::BlogTheme::CODE_FIELDS.each do |field|
      expect(described_class.new(**attributes)).to allow_values("", "a" * 65_536).for(
        field,
      ).with_message(invalid_message, against: :base)
      expect(described_class.new(**attributes)).not_to allow_values(
        "a" * 65_537,
        "ü" * 32_769,
        "\xFF",
        nil,
      ).for(field).with_message(invalid_message, against: :base)
    end
  end

  it "accepts unparseable templates within the size limit" do
    is_expected.to allow_values(
      "",
      "{% unknown_tag %}",
      "a" * Blog::TemplateRenderer::MAX_TEMPLATE_BYTES,
    ).for(:template_index).with_message(template_message, against: :base)
  end

  it do
    is_expected.not_to allow_values(
      "a" * (Blog::TemplateRenderer::MAX_TEMPLATE_BYTES + 1),
      "\xFF",
      nil,
    ).for(:template_index).with_message(template_message, against: :base)
  end

  describe "#theme_attributes" do
    it "returns every theme field, defaulting templates to the built-in ones" do
      expect(contract.theme_attributes).to eq(
        attributes.stringify_keys.merge(
          Blog::BlogTheme::TEMPLATE_FIELDS.to_h { |field| [field, ""] },
        ),
      )
    end
  end
end
