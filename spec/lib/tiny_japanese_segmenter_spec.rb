# frozen_string_literal: true

require 'rails_helper'

describe TinyJapaneseSegmenter do
  describe '.segment' do
    it 'generates the segments for a given japanese text' do
      expect(TinyJapaneseSegmenter.segment("TinySegmenterはJavascriptだけ書かれた極めてコンパクトな日本語分かち書きソフトウェアです。")).to eq(
        %w{TinySegmenter は Javascript だけ 書か れ た 極め て コンパクト な 日本 語分 かち 書き ソフトウェア です 。}
      )
    end
  end
end
