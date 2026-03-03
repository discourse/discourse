# frozen_string_literal: true

require "email/receiver"

RSpec.describe Email::Cleaner do
  it "removes attachments from raw message" do
    email = email(:attached_txt_file)

    expected_message =
      "Return-Path: <discourse@bar.com>\r\nDate: Sat, 30 Jan 2016 01:10:11 +0100\r\nFrom: Foo Bar <discourse@bar.com>\r\nTo: reply+4f97315cc828096c9cb34c6f1a0d6fe8@bar.com\r\nMessage-ID: <38@foo.bar.mail>\r\nMIME-Version: 1.0\r\nContent-Type: multipart/mixed;\r\n boundary=\"--==_mimepart_56abff5d49749_ddf83fca6d033a28548ad\";\r\n charset=UTF-8\r\nContent-Transfer-Encoding: 7bit\r\n\r\n\r\n----==_mimepart_56abff5d49749_ddf83fca6d033a28548ad\r\nContent-Type: text/plain;\r\n charset=UTF-8\r\nContent-Transfer-Encoding: 7bit\r\n\r\nPlease find some text file attached.\r\n----==_mimepart_56abff5d49749_ddf83fca6d033a28548ad--\r\n"
    expect(described_class.new(email).execute).to eq(expected_message)
  end

  it "truncates message" do
    email = email(:attached_txt_file)
    SiteSetting.raw_email_max_length = 10

    expected_message =
      "Return-Path: <discourse@bar.com>\r\nDate: Sat, 30 Jan 2016 01:10:11 +0100\r\nFrom: Foo Bar <discourse@bar.com>\r\nTo: reply+4f97315cc828096c9cb34c6f1a0d6fe8@bar.com\r\nMessage-ID: <38@foo.bar.mail>\r\nMIME-Version: 1.0\r\nContent-Type: multipart/mixed;\r\n boundary=\"--==_mimepart_56abff5d49749_ddf83fca6d033a28548ad\";\r\n charset=UTF-8\r\nContent-Transfer-Encoding: 7bit\r\n\r\n\r\n----==_mimepart_56abff5d49749_ddf83fca6d033a28548ad\r\nContent-Type: text/plain;\r\n charset=UTF-8\r\nContent-Transfer-Encoding: 7bit\r\n\r\nPlease fin\r\n----==_mimepart_56abff5d49749_ddf83fca6d033a28548ad--\r\n"
    expect(described_class.new(email).execute).to eq(expected_message)
  end

  it "truncates rejected message" do
    email = email(:attached_txt_file)
    SiteSetting.raw_rejected_email_max_length = 10

    expected_message =
      "Return-Path: <discourse@bar.com>\r\nDate: Sat, 30 Jan 2016 01:10:11 +0100\r\nFrom: Foo Bar <discourse@bar.com>\r\nTo: reply+4f97315cc828096c9cb34c6f1a0d6fe8@bar.com\r\nMessage-ID: <38@foo.bar.mail>\r\nMIME-Version: 1.0\r\nContent-Type: multipart/mixed;\r\n boundary=\"--==_mimepart_56abff5d49749_ddf83fca6d033a28548ad\";\r\n charset=UTF-8\r\nContent-Transfer-Encoding: 7bit\r\n\r\n\r\n----==_mimepart_56abff5d49749_ddf83fca6d033a28548ad\r\nContent-Type: text/plain;\r\n charset=UTF-8\r\nContent-Transfer-Encoding: 7bit\r\n\r\nPlease fin\r\n----==_mimepart_56abff5d49749_ddf83fca6d033a28548ad--\r\n"
    expect(described_class.new(email, rejected: true).execute).to eq(expected_message)
  end

  it "does not mangle encoded text bodies" do
    raw = email(:base64_encoded_body)
    email = Mail.new(raw)
    cleaned_email = Mail.new(described_class.new(raw).execute)

    expect(email.parts[0].body.decoded).to eq(cleaned_email.parts[0].body.decoded)
    expect(email.parts[1].body.decoded).to eq(cleaned_email.parts[1].body.decoded)
  end

  it "does not sort message parts" do
    raw = email(:unsorted_parts)
    email = Mail.new(raw)
    cleaned_email = Mail.new(described_class.new(raw).execute)

    expect(email.parts.length).to eq(cleaned_email.parts.length)
    email.parts.length.times do |i|
      next if email.parts[i].multipart?
      expect(email.parts[i].body.decoded.to_s).to eq(cleaned_email.parts[i].body.decoded.to_s)
    end
  end
end
