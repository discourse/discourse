# frozen_string_literal: true

def generate_html(text, opts = {})
  output = "<p><span"
  output += " class=\"discourse-local-date\""
  output += " data-date=\"#{opts[:date]}\"" if opts[:date]
  output += " data-email-preview=\"#{opts[:email_preview]}\"" if opts[:email_preview]
  output += " data-format=\"#{opts[:format]}\"" if opts[:format]
  output += " data-time=\"#{opts[:time]}\"" if opts[:time]
  output += " data-timezone=\"#{opts[:timezone]}\"" if opts[:timezone]
  output += " data-timezones=\"#{opts[:timezones]}\"" if opts[:timezones]
  output += ">"
  output += text
  output + "</span></p>"
end

RSpec.describe PrettyText do
  before { freeze_time }

  describe "emails simplified rendering" do
    it "works with default markup" do
      cooked = PrettyText.cook("[date=2018-05-08]")
      cooked_mail =
        generate_html(
          "2018-05-08T00:00:00Z UTC",
          date: "2018-05-08",
          email_preview: "2018-05-08T00:00:00Z UTC",
        )

      expect(PrettyText.format_for_email(cooked)).to match_html(cooked_mail)
    end

    it "works with time" do
      cooked = PrettyText.cook("[date=2018-05-08  time=20:00:00]")
      cooked_mail =
        generate_html(
          "2018-05-08T20:00:00Z UTC",
          date: "2018-05-08",
          email_preview: "2018-05-08T20:00:00Z UTC",
          time: "20:00:00",
        )

      expect(PrettyText.format_for_email(cooked)).to match_html(cooked_mail)
    end

    it "works with multiple timezones" do
      cooked =
        PrettyText.cook(
          '[date=2023-05-08 timezone="Europe/Paris" timezones="America/Los_Angeles|Pacific/Auckland"]',
        )
      cooked_mail =
        generate_html(
          "2023-05-07T22:00:00Z UTC",
          date: "2023-05-08",
          email_preview: "2023-05-07T22:00:00Z UTC",
          timezone: "Europe/Paris",
          timezones: "America/Los_Angeles|Pacific/Auckland",
        )

      expect(PrettyText.format_for_email(cooked)).to match_html(cooked_mail)
    end

    describe "discourse_local_dates_email_format" do
      before { SiteSetting.discourse_local_dates_email_format = "DD/MM" }

      it "uses the site setting" do
        cooked = PrettyText.cook("[date=2018-05-08]")
        cooked_mail = generate_html("08/05 UTC", date: "2018-05-08", email_preview: "08/05 UTC")

        expect(PrettyText.format_for_email(cooked)).to match_html(cooked_mail)
      end
    end
  end

  describe "excerpt simplified rendering" do
    let(:post) do
      Fabricate(
        :post,
        raw: '[date=2019-10-16 time=14:00:00 format="LLLL" timezone="America/New_York"]',
      )
    end

    it "adds UTC" do
      excerpt = PrettyText.excerpt(post.cooked, 200)
      expect(excerpt).to eq("Wednesday, October 16, 2019 6:00 PM (UTC)")
    end
  end

  describe "special quotes" do
    it "converts special quotes to regular quotes" do
      # german
      post =
        Fabricate(
          :post,
          raw: '[date=2019-10-16 time=14:00:00 format="LLLL" timezone=„America/New_York“]',
        )
      excerpt = PrettyText.excerpt(post.cooked, 200)
      expect(excerpt).to eq("Wednesday, October 16, 2019 6:00 PM (UTC)")

      # french
      post =
        Fabricate(
          :post,
          raw: '[date=2019-10-16 time=14:00:00 format="LLLL" timezone=«America/New_York»]',
        )
      excerpt = PrettyText.excerpt(post.cooked, 200)
      expect(excerpt).to eq("Wednesday, October 16, 2019 6:00 PM (UTC)")

      post =
        Fabricate(
          :post,
          raw: '[date=2019-10-16 time=14:00:00 format="LLLL" timezone=“America/New_York”]',
        )
      excerpt = PrettyText.excerpt(post.cooked, 200)
      expect(excerpt).to eq("Wednesday, October 16, 2019 6:00 PM (UTC)")
    end
  end

  describe "french quotes" do
    let(:post) do
      Fabricate(
        :post,
        raw: '[date=2019-10-16 time=14:00:00 format="LLLL" timezone=«America/New_York»]',
      )
    end

    it "converts french quotes to regular quotes" do
      excerpt = PrettyText.excerpt(post.cooked, 200)
      expect(excerpt).to eq("Wednesday, October 16, 2019 6:00 PM (UTC)")
    end
  end
end
