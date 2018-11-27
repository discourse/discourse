require 'rails_helper'

def generate_html(text, opts = {})
  output = "<p><span"
  output += " data-date=\"#{opts[:date]}\"" if opts[:date]
  output += " data-time=\"#{opts[:time]}\"" if opts[:time]
  output += " class=\"discourse-local-date\""
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
      cooked_mail = generate_html("2018-05-08T00:00:00Z (Etc: UTC)",
        date: "2018-05-08",
        email_preview: "2018-05-08T00:00:00Z (Etc: UTC)"
      )

      expect(PrettyText.format_for_email(cooked)).to match_html(cooked_mail)
    end

    it 'works with format' do
      cooked = PrettyText.cook("[date=2018-05-08  format=LLLL]")
      cooked_mail = generate_html("Tuesday, May 8, 2018 12:00 AM (Etc: UTC)",
        date: "2018-05-08",
        email_preview: "Tuesday, May 8, 2018 12:00 AM (Etc: UTC)",
        format: "LLLL"
      )

      expect(PrettyText.format_for_email(cooked)).to match_html(cooked_mail)
    end

    it 'works with time' do
      cooked = PrettyText.cook("[date=2018-05-08  time=20:00:00]")
      cooked_mail = generate_html("2018-05-08T20:00:00Z (Etc: UTC)",
        date: "2018-05-08",
        email_preview: "2018-05-08T20:00:00Z (Etc: UTC)",
        time: "20:00:00"
      )

      expect(PrettyText.format_for_email(cooked)).to match_html(cooked_mail)
    end
  end
end
