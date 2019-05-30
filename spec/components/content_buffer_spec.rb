# frozen_string_literal: true

require 'rails_helper'
require 'content_buffer'

describe ContentBuffer do

  it "handles deletion across lines properly" do
    c = ContentBuffer.new("a\nbc\nc")
    c.apply_transform!(start: { row: 0, col: 0 }, finish: { col: 1, row: 1 }, operation: :delete)
    expect(c.to_s).to eq("c\nc")
  end
  it "handles deletion inside lines properly" do
    c = ContentBuffer.new("hello world")
    c.apply_transform!(start: { row: 0, col: 1 }, finish: { col: 4, row: 0 }, operation: :delete)
    expect(c.to_s).to eq("ho world")
  end

  it "handles inserts inside lines properly" do
    c = ContentBuffer.new("hello!")
    c.apply_transform!(start: { row: 0, col: 5 }, operation: :insert, text: " world")
    expect(c.to_s).to eq("hello world!")
  end

  it "handles multiline inserts" do
    c = ContentBuffer.new("hello!")
    c.apply_transform!(start: { row: 0, col: 5 }, operation: :insert, text: "\nworld")
    expect(c.to_s).to eq("hello\nworld!")
  end

end
