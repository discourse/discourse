require 'spec_helper'

require 'cooked_post_processor'

describe CookedPostProcessor do
  let :cpp do
    post = Fabricate.build(:post_with_youtube)
    post.id = 123
    CookedPostProcessor.new(post)
  end

  context 'process_onebox' do

    before do
      post = Fabricate.build(:post_with_youtube)
      post.id = 123
      @cpp = CookedPostProcessor.new(post, invalidate_oneboxes: true)
      Oneboxer.expects(:onebox).with("http://www.youtube.com/watch?v=9bZkp7q19f0", post_id: 123, invalidate_oneboxes: true).returns('GANGNAM STYLE')
      @cpp.post_process_oneboxes
    end

    it 'should be dirty' do
      @cpp.should be_dirty
    end

    it 'inserts the onebox' do
      @cpp.html.should == <<EXPECTED
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN" "http://www.w3.org/TR/REC-html40/loose.dtd">
<html><body>GANGNAM STYLE</body></html>
EXPECTED
    end

  end

  context 'process_images' do

    it "has no topic image if there isn't one in the post" do
      @post = Fabricate(:post)
      @post.topic.image_url.should be_blank
    end

    context 'with sized images in the post' do
      before do
        @topic = Fabricate(:topic)
        @post = Fabricate.build(:post_with_image_url, topic: @topic, user: @topic.user)
        @cpp = CookedPostProcessor.new(@post, :image_sizes => {'http://www.forumwarz.com/images/header/logo.png' => {'width' => 111, 'height' => 222}})
        @cpp.expects(:get_size).returns([111,222])
      end

      it "doesn't call image_dimensions because it knows the size" do
        @cpp.expects(:image_dimensions).never
        @cpp.post_process_images
      end

      it "adds the width from the image sizes provided" do
        @cpp.post_process_images
        @cpp.html.should =~ /width=\"111\"/
      end

    end

    context 'with unsized images in the post' do
      before do
        FastImage.stubs(:size).returns([123, 456])
        CookedPostProcessor.any_instance.expects(:image_dimensions).returns([123, 456])
        @post = Fabricate(:post_with_images)
      end

      it "adds a topic image if there's one in the post" do
        @post.topic.reload
        @post.topic.image_url.should == "/path/to/img.jpg"
      end

      it "adds the height and width to images that don't have them" do
        @post.reload
        @post.cooked.should =~ /width=\"123\" height=\"456\"/
      end

    end
  end

  context 'link convertor' do
    before do
      SiteSetting.stubs(:crawl_images?).returns(true)
    end

    let :post_with_img do
      Fabricate.build(:post, cooked: '<p><img src="http://hello.com/image.png"></p>')
    end

    let :cpp_for_post do
      CookedPostProcessor.new(post_with_img)
    end

    it 'convert img tags to links if they are sized down' do
      cpp_for_post.expects(:get_size).returns([2000,2000]).twice
      cpp_for_post.post_process
      cpp_for_post.html.should =~ /a href/
    end

    it 'does not convert img tags to links if they are small' do
      cpp_for_post.expects(:get_size).returns([200,200]).twice
      cpp_for_post.post_process
      (cpp_for_post.html !~ /a href/).should be_true
    end

  end

  context 'image_dimensions' do
    it "returns unless called with a http or https url" do
      cpp.image_dimensions('/tmp/image.jpg').should be_blank
    end

    context 'with valid url' do
      before do
        @url = 'http://www.forumwarz.com/images/header/logo.png'
      end

      it "doesn't call fastimage if image crawling is disabled" do
        SiteSetting.expects(:crawl_images?).returns(false)
        FastImage.expects(:size).never
        cpp.image_dimensions(@url)
      end

      it "calls fastimage if image crawling is enabled" do
        SiteSetting.expects(:crawl_images?).returns(true)
        FastImage.expects(:size).with(@url)
        cpp.image_dimensions(@url)
      end
    end
  end

end
