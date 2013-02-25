require 'spec_helper'
require 'content_buffer'

describe ContentBuffer do

  it "handles deletion across lines properly" do
    c = ContentBuffer.new("a\nbc\nc")
    c.apply_transform!(start: {row: 0, col: 0}, finish: {col: 1, row: 1}, operation: :delete)
    c.to_s.should == "c\nc"
  end
  it "handles deletion inside lines properly" do
    c = ContentBuffer.new("hello world")
    c.apply_transform!(start: {row: 0, col: 1}, finish: {col: 4, row: 0}, operation: :delete)
    c.to_s.should == "ho world"
  end

  it "handles inserts inside lines properly" do
    c = ContentBuffer.new("hello!")
    c.apply_transform!(start: {row: 0, col: 5}, operation: :insert, text: " world")
    c.to_s.should == "hello world!"
  end

  it "handles multiline inserts" do
    c = ContentBuffer.new("hello!")
    c.apply_transform!(start: {row: 0, col: 5}, operation: :insert, text: "\nworld")
    c.to_s.should == "hello\nworld!"
  end

end
