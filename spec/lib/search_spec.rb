# frozen_string_literal: true

require 'rails_helper'

describe Search do

  context "#ts_config" do
    it "maps locales to correct Postgres dictionaries" do
      expect(Search.ts_config).to eq("english")
      expect(Search.ts_config("en")).to eq("english")
      expect(Search.ts_config("en_US")).to eq("english")
      expect(Search.ts_config("pt_BR")).to eq("portuguese")
      expect(Search.ts_config("tr")).to eq("turkish")
      expect(Search.ts_config("xx")).to eq("simple")
    end
  end

  context "#GroupedSearchResults.blurb_for" do
    it "strips audio and video URLs from search blurb" do
      cooked = <<~RAW
        link to an external page: https://google.com/?u=bar

        link to an audio file: https://somesite.com/content/file123.m4a

        link to a video file: https://somesite.com/content/somethingelse.MOV
      RAW
      result = Search::GroupedSearchResults.blurb_for(cooked)
      expect(result).to eq("link to an external page: https://google.com/?u=bar link to an audio file: #{I18n.t("search.audio")} link to a video file: #{I18n.t("search.video")}")
    end

    it "strips URLs correctly when blurb is longer than limit" do
      cooked = <<~RAW
        Here goes a test cooked with enough characters to hit the blurb limit.

        Something is very interesting about this audio file.

        http://localhost/uploads/default/original/1X/90adc0092b30c04b761541bc0322d0dce3d896e7.m4a
      RAW

      result = Search::GroupedSearchResults.blurb_for(cooked)
      expect(result).to eq("Here goes a test cooked with enough characters to hit the blurb limit. Something is very interesting about this audio file. #{I18n.t("search.audio")}")
    end

    it "does not fail on bad URLs" do
      cooked = <<~RAW
        invalid URL: http:error] should not trip up blurb generation.
      RAW
      result = Search::GroupedSearchResults.blurb_for(cooked)
      expect(result).to eq("invalid URL: http:error] should not trip up blurb generation.")
    end
  end

end
