# frozen_string_literal: true

RSpec.describe PrettyText do
  before { freeze_time }

  describe "emails simplified rendering" do
    it "works with default markup" do
      SiteSetting.discourse_local_dates_email_format = "YYYY-MM-DDTHH:mm:ss[Z] z"
      cooked = PrettyText.cook("[date=2018-05-08]")
      cooked_mail =
        '<p><span class="discourse-local-date" data-date="2018-05-08" data-email-preview="2018-05-08T00:00:00Z UTC">2018-05-08T00:00:00Z UTC</span></p>'

      expect(PrettyText.format_for_email(cooked)).to match_html(cooked_mail)
    end

    it "works with time" do
      SiteSetting.discourse_local_dates_email_format = "YYYY-MM-DDTHH:mm:ss[Z] UTC"
      cooked = PrettyText.cook("[date=2018-05-08  time=20:00:00]")
      cooked_mail =
        '<p><span class="discourse-local-date" data-date="2018-05-08" data-email-preview="2018-05-08T20:00:00Z UTC" data-time="20:00:00">2018-05-08T20:00:00Z UTC</span></p>'

      expect(PrettyText.format_for_email(cooked)).to match_html(cooked_mail)
    end

    it "works with multiple timezones" do
      SiteSetting.discourse_local_dates_email_format = "YYYY-MM-DDTHH:mm:ss[Z] UTC"
      cooked =
        PrettyText.cook(
          '[date=2023-05-08 timezone="Europe/Paris" timezones="America/Los_Angeles|Pacific/Auckland"]',
        )
      cooked_mail =
        '<p><span class="discourse-local-date" data-date="2023-05-08" data-email-preview="2023-05-07T22:00:00Z UTC" data-timezone="Europe/Paris" data-timezones="America/Los_Angeles|Pacific/Auckland">2023-05-07T22:00:00Z UTC</span></p>'

      expect(PrettyText.format_for_email(cooked)).to match_html(cooked_mail)
    end

    describe "discourse_local_dates_email_timezone" do
      before do
        SiteSetting.discourse_local_dates_email_timezone = "Europe/Paris"
        SiteSetting.discourse_local_dates_email_format = "llll"
      end

      it "uses the site setting" do
        cooked = PrettyText.cook("[date=2018-05-08]")

        cooked_mail =
          '<p><span class="discourse-local-date" data-date="2018-05-08" data-email-preview="Tue, May 8, 2018 2:00 AM">Tue, May 8, 2018 2:00 AM</span></p>'

        expect(PrettyText.format_for_email(cooked)).to match_html(cooked_mail)
      end
    end

    describe "discourse_local_dates_email_format" do
      before { SiteSetting.discourse_local_dates_email_format = "DD/MM UTC" }

      it "uses the site setting" do
        cooked = PrettyText.cook("[date=2018-05-08]")
        cooked_mail =
          '<p><span class="discourse-local-date" data-date="2018-05-08" data-email-preview="08/05 UTC">08/05 UTC</span></p>'

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

  describe "date normalization" do
    it "normalizes dates without leading zeros in date-range" do
      cooked =
        PrettyText.cook('[date-range from=2024-3-9T09:00:00 to=2024-3-9T17:00:00 timezone="UTC"]')

      expect(cooked).to include('data-date="2024-03-09"')
      expect(cooked).not_to include('data-date="2024-3-9"')
    end

    it "normalizes dates without leading zeros in single date" do
      cooked = PrettyText.cook("[date=2024-3-9]")

      expect(cooked).to include('data-date="2024-03-09"')
      expect(cooked).not_to include('data-date="2024-3-9"')
    end
  end
end
