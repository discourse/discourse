# encoding: utf-8
# frozen_string_literal: true

require 'rails_helper'
require 'slug'

describe Slug do

  describe '#for' do
    let(:default_slug) { 'topic' }

    let(:very_long_string) do
      '内容似乎不清晰，这是个完整的句子吗？内容似乎不清晰，这是个完整的句子吗？' * 10
    end

    it 'returns topic by default' do
      expect(Slug.for('')).to eq default_slug
    end

    it 'return topic by default if the string boils down to a number' do
      expect(Slug.for('=213=-!(@#+@)(!*_(@#&(!)#')).to eq default_slug
    end

    it 'accepts fallback' do
      expect(Slug.for('', 'king')).to eq 'king'
    end

    it 'replaces the underscore' do
      expect(Slug.for("o_o_o")).to eq("o-o-o")
    end

    it 'strips emoji string' do
      expect(Slug.for(":smile: To Infinity and beyond! 🚀 :woman:t5:")).to eq("to-infinity-and-beyond")
    end

    context 'ascii generator' do
      before { SiteSetting.slug_generation_method = 'ascii' }

      it 'generates the slug' do
        expect(Slug.for("hello world")).to eq('hello-world')
      end

      it 'generates default slug when nothing' do
        expect(Slug.for('')).to eq(default_slug)
      end

      it "doesn't generate slugs that are just numbers" do
        expect(Slug.for('123')).to eq(default_slug)
      end

      it "fallbacks to empty string if it's too long" do
        expect(Slug.for(very_long_string)).to eq(default_slug)
      end

      it "transliterates with the default locale" do
        SiteSetting.default_locale = :de
        I18n.locale = :en
        expect(Slug.for('löwe')).to eq('loewe')
      end
    end

    context 'encoded generator' do
      before { SiteSetting.slug_generation_method = 'encoded' }
      after { SiteSetting.slug_generation_method = 'ascii' }

      it 'generates the slug' do
        expect(Slug.for("熱帶風暴畫眉")).to eq('%E7%86%B1%E5%B8%B6%E9%A2%A8%E6%9A%B4%E7%95%AB%E7%9C%89')
        expect(Slug.for("Jeff hate's !~-_|,=#this")).to eq("jeff-hates-this")
      end

      it 'generates default slug when nothing' do
        expect(Slug.for('')).to eq(default_slug)
      end

      it "doesn't generate slugs that are just numbers" do
        expect(Slug.for('123')).to eq(default_slug)
      end

      it "handles the special characters" do
        expect(Slug.for(
          " - English and Chinese title with special characters / 中文标题 !@:?\\:'`#^& $%&*()` -- "
        )).to eq("english-and-chinese-title-with-special-characters-%E4%B8%AD%E6%96%87%E6%A0%87%E9%A2%98")
      end

      it "kills the trailing dash" do
        expect(Slug.for("2- -this!~-_|,we-#-=^-")).to eq('2-this-we')
      end

      it "returns a slug that can be used in a valid URL" do
        slug = Slug.for("Γνωμη για αγορα μπουζουκιου μεσω ιντερνετ και εκτίμηση")
        expect { URI.parse("http://example.com/#{slug}") }.not_to raise_error
      end
    end

    context 'none generator' do
      before { SiteSetting.slug_generation_method = 'none' }
      after { SiteSetting.slug_generation_method = 'ascii' }

      it 'generates the slug' do
        expect(Slug.for("hello world", 'category')).to eq('category')
        expect(Slug.for("hello world")).to eq(default_slug)
        expect(Slug.for('')).to eq(default_slug)
        expect(Slug.for('123')).to eq(default_slug)
      end
    end
  end

  describe '#ascii_generator' do
    before { SiteSetting.slug_generation_method = 'ascii' }

    it 'replaces spaces with hyphens' do
      expect(Slug.ascii_generator("hello world")).to eq('hello-world')
    end

    it 'changes accented characters' do
      expect(Slug.ascii_generator('àllo')).to eq('allo')
    end

    it 'replaces symbols' do
      expect(Slug.ascii_generator('evil#trout')).to eq('evil-trout')
    end

    it 'handles a.b.c properly' do
      expect(Slug.ascii_generator("a.b.c")).to eq("a-b-c")
    end

    it 'handles double dots right' do
      expect(Slug.ascii_generator("a....b.....c")).to eq("a-b-c")
    end

    it 'strips trailing punctuation' do
      expect(Slug.ascii_generator("hello...")).to eq("hello")
    end

    it 'strips leading punctuation' do
      expect(Slug.ascii_generator("...hello")).to eq("hello")
    end

    it 'handles our initial transliteration' do
      from = "àáäâčďèéëěêìíïîľĺňòóöôŕřšťůùúüûýžñç"
      to   = "aaaacdeeeeeiiiillnoooorrstuuuuuyznc"
      expect(Slug.ascii_generator(from)).to eq(to)
    end

    it "doesn't keep single quotes within word" do
      expect(Slug.ascii_generator("Jeff hate's this")).to eq("jeff-hates-this")
    end

    it 'generates null when nothing' do
      expect(Slug.ascii_generator('')).to eq('')
    end

    it "keeps number unchanged" do
      expect(Slug.ascii_generator('123')).to eq('123')
    end
  end

  describe '#encoded_generator' do
    before { SiteSetting.slug_generation_method = 'encoded' }
    after { SiteSetting.slug_generation_method = 'ascii' }

    it 'generates precentage encoded string' do
      expect(Slug.encoded_generator("뉴스피드")).to eq("%EB%89%B4%EC%8A%A4%ED%94%BC%EB%93%9C")
      expect(Slug.encoded_generator("آموزش اضافه کردن لینک اختیاری به هدر")).to eq("%D8%A2%D9%85%D9%88%D8%B2%D8%B4-%D8%A7%D8%B6%D8%A7%D9%81%D9%87-%DA%A9%D8%B1%D8%AF%D9%86-%D9%84%DB%8C%D9%86%DA%A9-%D8%A7%D8%AE%D8%AA%DB%8C%D8%A7%D8%B1%DB%8C-%D8%A8%D9%87-%D9%87%D8%AF%D8%B1")
      expect(Slug.encoded_generator("熱帶風暴畫眉")).to eq("%E7%86%B1%E5%B8%B6%E9%A2%A8%E6%9A%B4%E7%95%AB%E7%9C%89")
    end

    it 'reject RFC 3986 reserved character and blank' do
      expect(Slug.encoded_generator(":/?#[]@!$ &'()*+,;=% -_`~.")).to eq("---") # will be clear by #for
    end

    it 'generates null when nothing' do
      expect(Slug.encoded_generator('')).to eq('')
    end

    it "keeps number unchanged" do
      expect(Slug.encoded_generator('123')).to eq('123')
    end

    it 'downcase the string' do
      expect(Slug.encoded_generator("LoWer")).to eq('lower')
    end
  end

  describe '#none_generator' do
    before { SiteSetting.slug_generation_method = 'none' }
    after { SiteSetting.slug_generation_method = 'ascii' }

    it 'generates nothing' do
      expect(Slug.none_generator("Jeff hate's this")).to eq('')
      expect(Slug.none_generator(nil)).to eq('')
      expect(Slug.none_generator('')).to eq('')
      expect(Slug.none_generator('31')).to eq('')
    end
  end
end
