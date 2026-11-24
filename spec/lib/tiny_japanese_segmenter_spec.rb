# frozen_string_literal: true

RSpec.describe TinyJapaneseSegmenter do
  describe ".segment" do
    it "generates the segments for a given japanese text" do
      expect(
        TinyJapaneseSegmenter.segment("TinySegmenterはJavascriptだけ書かれた極めてコンパクトな日本語分かち書きソフトウェアです。"),
      ).to eq(%w[TinySegmenter は Javascript だけ 書か れ た 極め て コンパクト な 日本 語分 かち 書き ソフトウェア です 。])
    end

    it "returns an empty array for nil or ASCII-blank strings while preserving ideographic spaces" do
      expect(TinyJapaneseSegmenter.segment(nil)).to eq([])
      expect(TinyJapaneseSegmenter.segment("")).to eq([])
      expect(TinyJapaneseSegmenter.segment("  \t\n\x00 ")).to eq([])
      expect(TinyJapaneseSegmenter.segment("　")).to eq(["　"])
    end

    it "handles single characters, kanji numerals, iteration marks, and halfwidth katakana" do
      expect(TinyJapaneseSegmenter.segment("あ")).to eq(["あ"])
      expect(
        TinyJapaneseSegmenter.segment("日々の開発では々や〆切、一ヵ月・三ヶ月の管理、ﾊﾝｶｸｶﾀｶﾅやｶﾞｷﾞｸﾞｹﾞｺﾞも重要です。"),
      ).to eq(%w[日々 の 開発 で は 々や 〆切 、 一ヵ月 ・ 三ヶ月 の 管理 、 ﾊﾝｶｸｶﾀｶﾅ や ｶﾞｷﾞｸﾞｹﾞｺﾞ も 重要 です 。])
    end

    it "handles sentinel-like substrings and supplementary-plane emoji" do
      expect(TinyJapaneseSegmenter.segment("B1階とB2階からE1東名高速道路へ向かう🚀👍🏽テスト")).to eq(
        %w[B 1 階 と B 2 階 から E 1 東 名高 速道 路 へ 向かう 🚀 👍🏽 テスト],
      )
    end
  end
end
