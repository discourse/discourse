# frozen_string_literal: true

describe DiscourseAi::Translation::TagLocalizer do
  subject(:localizer) { described_class }

  before do
    enable_current_plugin
    assign_fake_provider_to(:ai_default_llm_model)
  end

  def short_text_translator_stub(opts)
    mock = instance_double(DiscourseAi::Translation::ShortTextTranslator)
    allow(DiscourseAi::Translation::ShortTextTranslator).to receive(:new).with(
      text: opts[:text],
      target_locale: opts[:target_locale],
      llm_model: be_nil,
    ).and_return(mock)
    allow(mock).to receive(:translate).and_return(opts[:translated])
  end

  fab!(:tag) { Fabricate(:tag, name: "test-tag", description: "This is a test tag description") }

  describe ".localize" do
    let(:target_locale) { "fr" }

    it "translates the tag name and description" do
      translated_tag_desc = "C'est une description de tag de test"
      translated_tag_name = "tag-de-test"
      short_text_translator_stub(
        { text: tag.name, target_locale: target_locale, translated: translated_tag_name },
      )
      short_text_translator_stub(
        { text: tag.description, target_locale: target_locale, translated: translated_tag_desc },
      )

      res = localizer.localize(tag, target_locale)

      expect(res.name).to eq(translated_tag_name)
      expect(res.description).to eq(translated_tag_desc)
    end

    it "handles tag without description" do
      tag_no_desc = Fabricate(:tag, name: "no-desc-tag", description: nil)
      translated_tag_name = "tag-sans-description"
      short_text_translator_stub(
        { text: tag_no_desc.name, target_locale: target_locale, translated: translated_tag_name },
      )

      res = localizer.localize(tag_no_desc, target_locale)

      expect(res.name).to eq(translated_tag_name)
      expect(res.description).to be_nil
    end

    it "returns nil if tag is blank" do
      expect(localizer.localize(nil)).to be_nil
    end

    it "returns nil if target locale is blank" do
      expect(localizer.localize(tag, nil)).to be_nil
    end

    it "uses I18n.locale as default when no target locale is provided" do
      I18n.locale = :es
      translated_tag_desc = "Esta es una descripción de tag de prueba"
      translated_tag_name = "tag-de-prueba"
      short_text_translator_stub(
        { text: tag.name, target_locale: "es", translated: translated_tag_name },
      )
      short_text_translator_stub(
        { text: tag.description, target_locale: "es", translated: translated_tag_desc },
      )

      res = localizer.localize(tag)

      expect(res.name).to eq(translated_tag_name)
      expect(res.description).to eq(translated_tag_desc)
      expect(res.locale).to eq("es")
    end

    it "updates existing localization if one exists" do
      existing = Fabricate(:tag_localization, tag: tag, locale: target_locale, name: "old-name")
      translated_tag_name = "tag-de-test"
      translated_tag_desc = "C'est une description"
      short_text_translator_stub(
        { text: tag.name, target_locale: target_locale, translated: translated_tag_name },
      )
      short_text_translator_stub(
        { text: tag.description, target_locale: target_locale, translated: translated_tag_desc },
      )

      expect { localizer.localize(tag, target_locale) }.not_to change { TagLocalization.count }

      existing.reload
      expect(existing.name).to eq(translated_tag_name)
      expect(existing.description).to eq(translated_tag_desc)
    end
  end
end
