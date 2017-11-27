require 'rails_helper'

describe Hijack do
  class Hijack::Tester
    attr_reader :io

    include Hijack
    def initialize
      @io = StringIO.new
    end

    def hijack_test(&blk)
      hijack do
        self.instance_eval(&blk)
      end
    end

    def request
      @req ||= ActionController::TestRequest.new(
        { "rack.hijack" => lambda { @io } },
        nil,
        nil
      )
    end

    def render(*opts)
      # don't care
    end
  end

  let :tester do
    Hijack::Tester.new
  end

  it "renders non 200 status if asked for" do
    tester.hijack_test do
      render body: "hello world", status: 402
    end

    expect(tester.io.string).to include("402")
    expect(tester.io.string).to include("world")
  end

  it "renders stuff correctly if it works" do
    tester.hijack_test do
      render plain: "hello world"
    end

    result = "HTTP/1.1 200 OK\r\nContent-Length: 11\r\nContent-Type: text/plain; charset=utf-8\r\nConnection: close\r\n\r\nhello world"
    expect(tester.io.string).to eq(result)
  end

  it "returns 500 by default" do
    tester.hijack_test

    expected = "HTTP/1.1 500 OK\r\nContent-Length: 0\r\nContent-Type: text/plain\r\nConnection: close\r\n\r\n"
    expect(tester.io.string).to eq(expected)
  end

  it "does not run the block if io is closed" do
    tester.io.close

    ran = false
    tester.hijack_test do
      ran = true
    end

    expect(ran).to eq(false)
  end
end
