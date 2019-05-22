# frozen_string_literal: true

require "spec_helper"

describe Onebox::Engine::WechatMpOnebox do

  let(:link) { "https://mp.weixin.qq.com/s?__biz=MjM5NjM4MDAxMg==&mid=2655075181&idx=1&sn=7c58f17de2c687f4763f17359ecc6e72&chksm=bd5fb76e8a283e7856cae30a74e905a18d9511e81c047b6e12390889de15976fb2c297b04106#rd" }
  let(:html) { described_class.new(link).to_html }

  describe "#to_html" do
    before do
      fake("https://mp.weixin.qq.com/s?__biz=MjM5NjM4MDAxMg==&mid=2655075181&idx=1&sn=7c58f17de2c687f4763f17359ecc6e72&chksm=bd5fb76e8a283e7856cae30a74e905a18d9511e81c047b6e12390889de15976fb2c297b04106", response("wechat-mp"))
    end

    it "has the article's title" do
      expect(html).to include("不是月光宝盒，但也能回到过去")
    end

    it "has the article's description" do
      expect(html).to include("你知道吗？从今天起，公众号后台编辑文章时可以……")
    end

    it "has the article's author" do
      expect(html).to include("微信派")
    end
  end

end
