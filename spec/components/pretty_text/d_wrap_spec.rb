# frozen_string_literal: true

require 'rails_helper'

describe 'd-wrap' do
  context 'default wrap syntax' do
    it 'wraps it' do
      cooked = PrettyText.cook("[wrap=foo bar=1]\n[/wrap]")
      expect(cooked).to match_html("<div class=\"d-wrap\" data-wrap=\"foo\" data-bar=\"1\"></div>")

      cooked = PrettyText.cook("[wrap=foo bar=1][/wrap]")
      expect(cooked).to match_html("<p><span class=\"d-wrap\" data-wrap=\"foo\" data-bar=\"1\"></span></p>")
    end
  end

  context 'custom wrap syntax' do
    context 'custom tag is defined' do
      before do
        SiteSetting.custom_wrap_tags = 'foo'
      end

      it 'wraps it' do
        cooked = PrettyText.cook("[foo bar=1]\n[/foo]")
        expect(cooked).to match_html("<div class=\"d-wrap\" data-bar=\"1\" data-wrap=\"foo\"></div>")
      end
    end

    context 'custom tag is not defined' do
      it 'doesn’t wrap it' do
        cooked = PrettyText.cook("[foo bar=1]\n[/foo]")
        expect(cooked).to match_html("<p>[foo bar=1]<br>[/foo]</p>")
      end
    end
  end
end
