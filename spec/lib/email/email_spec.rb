# frozen_string_literal: true

require "email"

RSpec.describe Email do
  describe ".extract_smtp_status" do
    it "reads a status that leads the diagnostic" do
      expect(
        Email.extract_smtp_status("5.1.1 The email account that you tried to reach does not exist"),
      ).to eq("5.1.1")
      expect(Email.extract_smtp_status("smtp; 550-5.1.1 The email account does not exist")).to eq(
        "550",
      )
      expect(Email.extract_smtp_status("smtp;550 5.1.1 RESOLVER.ADR.RecipNotFound")).to eq("550")
      expect(Email.extract_smtp_status("451, temporary local problem")).to eq("451")
    end

    it "reads a status that introduces an enhanced one further into the text" do
      expect(
        Email.extract_smtp_status(
          "smtp; host mx.example.com[74.125.24.27] said: 450 4.2.1 receiving mail too quickly",
        ),
      ).to eq("450")
      expect(
        Email.extract_smtp_status("smtp; host mail.example.com[4.4.1.9] said: 450 4.2.1 too fast"),
      ).to eq("450")
      expect(
        Email.extract_smtp_status("smtp; Sat, 12 Mar 2022 10:11:12 +0000: 452 4.2.2 Over quota"),
      ).to eq("452")
    end

    it "does not mistake an IP, a port, a date, a version or a count for a status" do
      [
        "Error: mail.example.com[93.184.216.34]:25: Connection timed out",
        "Error: mail.example.com[5.9.44.234]:25: Connection refused",
        "Error: mail.example.com[4.3.2.1]:25: Connection refused",
        "Error: mail.example.com[5.1.24.7]:25: Connection refused",
        "Error: mail.example.com[93.184.216.34]:465 Connection refused",
        "Error: [IPv6:2a00:1450:4013:c07::1a]:587 Connection timed out",
        "Delivery delayed. Last attempt: Mon, 12 Feb 2024 09:31:04 +0000",
        "smtp; <20240212093104.ABC123@mx1.example.com> queued",
        "smtp; mta450.example.com refused the connection",
        "This message was created automatically by mail delivery software (Exim 4.94.2)",
        "Messages temporarily deferred - 4.16.50. Please refer to",
        "Mailbox full - quota exceeded (450 of 500 MB used)",
        "Mailgun could not deliver the message. DNS lookup failed",
      ].each { |diagnostic| expect(Email.extract_smtp_status(diagnostic)).to eq(nil) }
    end

    it "returns nil when there is nothing to read" do
      expect(Email.extract_smtp_status(nil)).to eq(nil)
      expect(Email.extract_smtp_status("")).to eq(nil)
    end
  end

  describe "is_valid?" do
    it "treats a nil as invalid" do
      expect(Email.is_valid?(nil)).to eq(false)
    end

    it "treats a good email as valid" do
      expect(Email.is_valid?("sam@sam.com")).to eq(true)
    end

    it "treats a bad email as invalid" do
      expect(Email.is_valid?("sam@sam")).to eq(false)
    end

    it "allows museum tld" do
      expect(Email.is_valid?("sam@nic.museum")).to eq(true)
    end

    it "does not think a word is an email" do
      expect(Email.is_valid?("sam")).to eq(false)
    end
  end

  describe "downcase" do
    it "downcases local and host part" do
      expect(Email.downcase("SAM@GMAIL.COM")).to eq("sam@gmail.com")
      expect(Email.downcase("sam@GMAIL.COM")).to eq("sam@gmail.com")
    end

    it "leaves invalid emails untouched" do
      expect(Email.downcase("SAM@GMAILCOM")).to eq("SAM@GMAILCOM")
      expect(Email.downcase("samGMAIL.COM")).to eq("samGMAIL.COM")
      expect(Email.downcase("sam@GM@AIL.COM")).to eq("sam@GM@AIL.COM")
    end
  end

  describe "obfuscate" do
    it "correctly obfuscates emails" do
      expect(Email.obfuscate("a@b.com")).to eq("*@*.com")
      expect(Email.obfuscate("test@test.co.uk")).to eq("t***@t***.**.uk")
      expect(Email.obfuscate("simple@example.com")).to eq("s****e@e*****e.com")
      expect(Email.obfuscate("very.common@example.com")).to eq("v*********n@e*****e.com")
      expect(Email.obfuscate("disposable.style.email.with+symbol@example.com")).to eq(
        "d********************************l@e*****e.com",
      )
      expect(Email.obfuscate("other.email-with-hyphen@example.com")).to eq(
        "o*********************n@e*****e.com",
      )
      expect(Email.obfuscate("fully-qualified-domain@example.com")).to eq(
        "f********************n@e*****e.com",
      )
      expect(Email.obfuscate("user.name+tag+sorting@example.com")).to eq(
        "u*******************g@e*****e.com",
      )
      expect(Email.obfuscate("x@example.com")).to eq("*@e*****e.com")
      expect(Email.obfuscate("example-indeed@strange-example.com")).to eq(
        "e************d@s*************e.com",
      )
      expect(Email.obfuscate("example@s.example")).to eq("e*****e@*.example")
      expect(Email.obfuscate("mailhost!username@example.org")).to eq(
        "m***************e@e*****e.org",
      )
      expect(Email.obfuscate("user%example.com@example.org")).to eq("u**************m@e*****e.org")
      expect(Email.obfuscate("user-@example.org")).to eq("u***-@e*****e.org")
    end
  end
end
