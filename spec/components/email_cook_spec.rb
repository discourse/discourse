require 'rails_helper'
require 'email_cook'

describe EmailCook do

  it 'adds linebreaks to short lines' do
    expect(EmailCook.new("hello\nworld\n").cook).to eq("hello\n<br>world\n<br>")
  end

  it "doesn't add linebreaks to long lines" do
    long = <<LONG_EMAIL
Hello,

Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nunc convallis volutpat
risus. Nulla ac faucibus quam, quis cursus lorem. Sed rutrum eget nunc sed accumsan.
Vestibulum feugiat mi vitae turpis tempor dignissim.
LONG_EMAIL

    long_cooked = <<LONG_COOKED
Hello,
<br>
<br>Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nunc convallis volutpat
risus. Nulla ac faucibus quam, quis cursus lorem. Sed rutrum eget nunc sed accumsan.
Vestibulum feugiat mi vitae turpis tempor dignissim.
<br><br>
LONG_COOKED
    expect(EmailCook.new(long).cook).to eq(long_cooked.strip)
  end

  it 'autolinks' do
    expect(EmailCook.new("https://www.eviltrout.com").cook).to eq("<a href='https://www.eviltrout.com'>https://www.eviltrout.com</a><br>")
  end

  it 'autolinks without the beginning of a line' do
    expect(EmailCook.new("my site: https://www.eviltrout.com").cook).to eq("my site: <a href='https://www.eviltrout.com'>https://www.eviltrout.com</a><br>")
  end

  it 'links even within a quote' do
    expect(EmailCook.new("> https://www.eviltrout.com").cook).to eq("<blockquote><a href='https://www.eviltrout.com'>https://www.eviltrout.com</a><br></blockquote>")
  end
end
