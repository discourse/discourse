require 'rails_helper'

def generate_html(text, opts = {})
  output = "<p><span"
  output += " data-date=\"#{opts[:date]}\"" if opts[:date]
  output += " data-time=\"#{opts[:time]}\"" if opts[:time]
  output += " class=\"discourse-local-date\""
  output += " data-timezones=\"#{opts[:timezones]}\"" if opts[:timezones]
  output += " data-timezone=\"#{opts[:timezone]}\"" if opts[:timezone]
  output += " data-format=\"#{opts[:format]}\"" if opts[:format]
  output += " data-email-preview=\"#{opts[:email_preview]}\"" if opts[:email_preview]
  output += ">"
  output += text
  output + "</span></p>"
end

describe PrettyText do
  before do
    freeze_time
  end

  context 'emails simplified rendering' do
    it 'works with default markup' do
      cooked = PrettyText.cook("[date=2018-05-08]")
      cooked_mail = generate_html("2018-05-08T00:00:00Z UTC",
        date: "2018-05-08",
        email_preview: "2018-05-08T00:00:00Z UTC"
      )

      expect(PrettyText.format_for_email(cooked)).to match_html(cooked_mail)
    end

    it 'works with time' do
      cooked = PrettyText.cook("[date=2018-05-08  time=20:00:00]")
      cooked_mail = generate_html("2018-05-08T20:00:00Z UTC",
        date: "2018-05-08",
        email_preview: "2018-05-08T20:00:00Z UTC",
        time: "20:00:00"
      )

      expect(PrettyText.format_for_email(cooked)).to match_html(cooked_mail)
    end

    it 'works with multiple timezones' do
      cooked = PrettyText.cook('[date=2018-05-08 timezone="Europe/Paris" timezones="America/Los_Angeles|Pacific/Auckland"]')
      cooked_mail = generate_html("2018-05-07T22:00:00Z UTC",
        date: "2018-05-08",
        email_preview: "2018-05-07T22:00:00Z UTC",
        timezone: "Europe/Paris",
        timezones: "America/Los_Angeles|Pacific/Auckland"
      )

      expect(PrettyText.format_for_email(cooked)).to match_html(cooked_mail)
    end

    describe 'discourse_local_dates_email_format' do
      before do
        SiteSetting.discourse_local_dates_email_format = "DD/MM"
      end

      it 'uses the site setting' do
        cooked = PrettyText.cook("[date=2018-05-08]")
        cooked_mail = generate_html("08/05 UTC",
          date: "2018-05-08",
          email_preview: "08/05 UTC"
        )

        expect(PrettyText.format_for_email(cooked)).to match_html(cooked_mail)
      end
    end
  end
end
