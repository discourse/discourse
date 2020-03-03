# frozen_string_literal: true
require 'rails_helper'

describe ThemeFlagSet do
  describe "#resolve_flag_for_themes" do
    it "returns nil for unknown flag" do
      expect(ThemeFlagSet.resolve_flag_for_themes([1, 2], :unknown_flag)).to eq(nil)
    end

    it "resolves serialize_topic_excerpts correctly" do
      t1 = Fabricate(:theme)
      t1.theme_flag_set.update!(serialize_topic_excerpts: true)
      t2 = Fabricate(:theme)
      t2.theme_flag_set.update!(serialize_topic_excerpts: false)

      expect(ThemeFlagSet.resolve_flag_for_themes([t1.id, t2.id], :serialize_topic_excerpts)).to eq(true)

      t1 = Fabricate(:theme)
      t1.theme_flag_set.update!(serialize_topic_excerpts: nil)

      expect(ThemeFlagSet.resolve_flag_for_themes([t1.id, t2.id], :serialize_topic_excerpts)).to eq(false)
    end
  end
end
