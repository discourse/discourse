# frozen_string_literal: true

RSpec.describe Onebox::Engine::DiscourseTopicOnebox do
  subject(:onebox) { described_class.new(url) }

  describe "#data" do
    subject(:data) { onebox.data }

    let(:url) do
      "https://meta.discourse.org/t/congratulations-most-stars-in-2013-github-octoverse/12483"
    end
    let(:expected_data) do
      {
        article_published_time: "6 Feb 14",
        article_published_time_title: "04:55AM - 06 February 2014",
        article_tags: %w[how-to sso],
        card: "summary",
        categories: [{ name: "praise", color: "9EB83B" }],
        data1: "1 mins 🕑",
        data2: "9 ❤",
        description:
          "Congratulations Discourse for qualifying Repositories with the most stars on GitHub Octoverse.     And that too in just over an year, way to go! 💥",
        domain: "Discourse Meta",
        favicon:
          "https://d11a6trkgmumsb.cloudfront.net/optimized/3X/b/3/b33be9538df3547fcf9d1a51a4637d77392ac6f9_2_32x32.png",
        ignore_canonical: "true",
        image:
          "https://d11a6trkgmumsb.cloudfront.net/optimized/2X/d/d063b3b0807377d98695ee08042a9ba0a8c593bd_2_690x362.png",
        label1: "Reading time",
        label2: "Likes",
        link:
          "https://meta.discourse.org/t/congratulations-most-stars-in-2013-github-octoverse/12483",
        published_time: "2014-02-06T04:55:19+00:00",
        render_category_block?: true,
        render_tags?: true,
        site_name: "Discourse Meta",
        title: "Congratulations, most stars in 2013 GitHub Octoverse!",
        url:
          "https://meta.discourse.org/t/congratulations-most-stars-in-2013-github-octoverse/12483",
      }
    end

    before do
      stub_request(:get, url).to_return(status: 200, body: onebox_response("discourse_topic"))
    end

    it "returns the expected data" do
      expect(data).to include expected_data
    end
  end
end
