require 'rails_helper'
require 'email_cook'

describe EmailCook do

  it 'adds linebreaks' do
    expect(EmailCook.new("hello\nworld\n").cook).to eq("hello\n<br>world\n<br>")
  end

  it 'autolinks' do
    expect(EmailCook.new("https://www.eviltrout.com").cook).to eq("<a href='https://www.eviltrout.com'>https://www.eviltrout.com</a><br>")
  end
end
