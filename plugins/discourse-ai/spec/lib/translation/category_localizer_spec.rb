# frozen_string_literal: true

describe DiscourseAi::Translation::CategoryLocalizer do
  subject(:localizer) { described_class }

  before do
    enable_current_plugin
    assign_fake_provider_to(:ai_default_llm_model)
  end

  def post_raw_translator_stub(opts)
    mock = instance_double(DiscourseAi::Translation::PostRawTranslator)
    allow(DiscourseAi::Translation::PostRawTranslator).to receive(:new).with(
      text: opts[:text],
      target_locale: opts[:target_locale],
    ).and_return(mock)
    allow(mock).to receive(:translate).and_return(opts[:translated])
  end

  def short_text_translator_stub(opts)
    mock = instance_double(DiscourseAi::Translation::ShortTextTranslator)
    allow(DiscourseAi::Translation::ShortTextTranslator).to receive(:new).with(
      text: opts[:text],
      target_locale: opts[:target_locale],
    ).and_return(mock)
    allow(mock).to receive(:translate).and_return(opts[:translated])
  end

  fab!(:category) do
    Fabricate(:category, name: "Test Category", description: "This is a test category. " * 50)
  end

  describe ".localize" do
    let(:target_locale) { "fr" }

    it "translates the category name and description" do
      translated_cat_desc = "C'est une catégorie de test"
      translated_cat_name = "Catégorie de Test"
      short_text_translator_stub(
        { text: category.name, target_locale: target_locale, translated: translated_cat_name },
      )
      post_raw_translator_stub(
        {
          text: category.description_excerpt,
          target_locale: target_locale,
          translated: translated_cat_desc,
        },
      )

      res = localizer.localize(category, target_locale)

      expect(res.name).to eq(translated_cat_name)
      expect(res.description).to eq(translated_cat_desc)
    end

    it "handles locale format standardization" do
      translated_cat_desc = "C'est une catégorie de test"
      translated_cat_name = "Catégorie de Test"
      short_text_translator_stub(
        { text: category.name, target_locale:, translated: translated_cat_name },
      )
      post_raw_translator_stub(
        { text: category.description_excerpt, target_locale:, translated: translated_cat_desc },
      )

      res = localizer.localize(category, target_locale)

      expect(res.name).to eq(translated_cat_name)
      expect(res.description).to eq(translated_cat_desc)
    end

    it "returns nil if category is blank" do
      expect(localizer.localize(nil)).to be_nil
    end

    it "returns nil if target locale is blank" do
      expect(localizer.localize(category, nil)).to be_nil
    end

    it "uses I18n.locale as default when no target locale is provided" do
      I18n.locale = :es
      translated_cat_desc = "C'est une catégorie de test"
      translated_cat_name = "Esta es una categoría de prueba"
      short_text_translator_stub(
        { text: category.name, target_locale: "es", translated: translated_cat_name },
      )
      post_raw_translator_stub(
        {
          text: category.description_excerpt,
          target_locale: "es",
          translated: translated_cat_desc,
        },
      )

      res = localizer.localize(category)

      expect(res.name).to eq(translated_cat_name)
      expect(res.description).to eq(translated_cat_desc)
      expect(res.locale).to eq("es")
    end
  end
end
