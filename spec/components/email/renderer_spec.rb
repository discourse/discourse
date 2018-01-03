require 'rails_helper'
require 'email/renderer'

describe Email::Renderer do

  let(:message) do
    mail = Mail.new

    mail.text_part = Mail::Part.new do
      body 'Key &amp; Peele'
    end

    mail.html_part = Mail::Part.new do
      content_type 'text/html; charset=UTF-8'
      body '<h1>Key &amp; Peele</h1>'
    end

    mail
  end

  it "escapes HTML entities from text" do
    renderer = Email::Renderer.new(message)
    expect(renderer.text).to eq("Key & Peele")
  end

end
