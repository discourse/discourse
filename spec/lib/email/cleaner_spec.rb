# frozen_string_literal: true

require "rails_helper"
require "email/receiver"

describe Email::Cleaner do
  it 'removes attachments from raw message' do
    email = email(:attached_txt_file)

    expected_message = "Return-Path: <discourse@bar.com>\r\nDate: Sat, 30 Jan 2016 01:10:11 +0100\r\nFrom: Foo Bar <discourse@bar.com>\r\nTo: reply+4f97315cc828096c9cb34c6f1a0d6fe8@bar.com\r\nMessage-ID: <38@foo.bar.mail>\r\nMime-Version: 1.0\r\nContent-Type: multipart/mixed;\r\n boundary=\"--==_mimepart_56abff5d49749_ddf83fca6d033a28548ad\";\r\n charset=UTF-8\r\nContent-Transfer-Encoding: 7bit\r\n\r\n\r\n----==_mimepart_56abff5d49749_ddf83fca6d033a28548ad\r\nContent-Type: text/plain;\r\n charset=UTF-8\r\nContent-Transfer-Encoding: 7bit\r\n\r\nPlease find some text file attached.\r\n----==_mimepart_56abff5d49749_ddf83fca6d033a28548ad--\r\n"
    expect(described_class.new(email).execute).to eq(expected_message)
  end

  it 'truncates message' do
    email = email(:attached_txt_file)
    SiteSetting.raw_email_max_length = 10

    expected_message = "Return-Path: <discourse@bar.com>\r\nDate: Sat, 30 Jan 2016 01:10:11 +0100\r\nFrom: Foo Bar <discourse@bar.com>\r\nTo: reply+4f97315cc828096c9cb34c6f1a0d6fe8@bar.com\r\nMessage-ID: <38@foo.bar.mail>\r\nMime-Version: 1.0\r\nContent-Type: multipart/mixed;\r\n boundary=\"--==_mimepart_56abff5d49749_ddf83fca6d033a28548ad\";\r\n charset=UTF-8\r\nContent-Transfer-Encoding: 7bit\r\n\r\n\r\n----==_mimepart_56abff5d49749_ddf83fca6d033a28548ad\r\nContent-Type: text/plain;\r\n charset=UTF-8\r\nContent-Transfer-Encoding: 7bit\r\n\r\nPlease fin\r\n----==_mimepart_56abff5d49749_ddf83fca6d033a28548ad--\r\n"
    expect(described_class.new(email).execute).to eq(expected_message)
  end

  it 'truncates rejected message' do
    email = email(:attached_txt_file)
    SiteSetting.raw_rejected_email_max_length = 10

    expected_message = "Return-Path: <discourse@bar.com>\r\nDate: Sat, 30 Jan 2016 01:10:11 +0100\r\nFrom: Foo Bar <discourse@bar.com>\r\nTo: reply+4f97315cc828096c9cb34c6f1a0d6fe8@bar.com\r\nMessage-ID: <38@foo.bar.mail>\r\nMime-Version: 1.0\r\nContent-Type: multipart/mixed;\r\n boundary=\"--==_mimepart_56abff5d49749_ddf83fca6d033a28548ad\";\r\n charset=UTF-8\r\nContent-Transfer-Encoding: 7bit\r\n\r\n\r\n----==_mimepart_56abff5d49749_ddf83fca6d033a28548ad\r\nContent-Type: text/plain;\r\n charset=UTF-8\r\nContent-Transfer-Encoding: 7bit\r\n\r\nPlease fin\r\n----==_mimepart_56abff5d49749_ddf83fca6d033a28548ad--\r\n"
    expect(described_class.new(email, rejected: true).execute).to eq(expected_message)
  end
end
