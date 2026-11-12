# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::RtfToText do
  it "extracts formatted body text" do
    with_document_file("rtf", <<~'RTF') do |path|
      {\rtf1\ansi\ansicpg1252 This is {\b bold}\par Caf\'e9\par Unicode \u8212? dash\tab done}
    RTF
      expect(described_class.convert(path)).to eq("This is bold\nCafé\nUnicode — dash\tdone")
    end
  end

  it "ignores formatting tables and embedded binary destinations" do
    with_document_file("rtf", <<~'RTF') do |path|
      {\rtf1\ansi{\fonttbl{\f0 Arial;}}{\colortbl;\red255\green0\blue0;}{\pict\pngblip abcdef}Visible\par More text}
    RTF
      expect(described_class.convert(path)).to eq("Visible\nMore text")
    end
  end

  it "preserves escaped literal braces and backslashes" do
    with_document_file("rtf", <<~'RTF') do |path|
      {\rtf1\ansi literal \{brace\} and \\slash}
    RTF
      expect(described_class.convert(path)).to eq("literal {brace} and \\slash")
    end
  end
end
