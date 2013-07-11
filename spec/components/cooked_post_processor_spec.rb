require 'spec_helper'
require 'cooked_post_processor'

describe CookedPostProcessor do

  context "post_process" do

    let(:post) { build(:post) }
    let(:cpp) { CookedPostProcessor.new(post) }
    let(:post_process) { sequence("post_process") }

    it "post process in sequence" do
      cpp.expects(:post_process_attachments).in_sequence(post_process)
      cpp.expects(:post_process_images).in_sequence(post_process)
      cpp.expects(:post_process_oneboxes).in_sequence(post_process)
      cpp.post_process
    end

  end

  context "post_process_attachments" do

    context "with attachment" do

      let(:upload) { Fabricate(:upload) }
      let(:post) { Fabricate(:post_with_an_attachment) }
      let(:cpp) { CookedPostProcessor.new(post) }

      # all in one test to speed things up
      it "works" do
        Upload.expects(:get_from_url).returns(upload)
        cpp.post_process_attachments
        # ensures absolute urls on attachment
        cpp.html.should =~ /#{LocalStore.base_url}/
        # ensure name is present
        cpp.html.should =~ /archive.zip/
        # ensure size is present
        cpp.html.should =~ /<span class=\"size\">\(1.21 KB\)<\/span>/
        # dirty
        cpp.should be_dirty
        # keeps the reverse index up to date
        post.uploads.reload
        post.uploads.count.should == 1
      end

    end

  end

  context "post_process_images" do

    context "with images in quotes and oneboxes" do

      let(:post) { build(:post_with_images_in_quote_and_onebox) }
      let(:cpp) { CookedPostProcessor.new(post) }
      before { cpp.post_process_images }

      it "does not process them" do
        cpp.html.should match_html post.cooked
        cpp.should_not be_dirty
      end

      it "has no topic image if there isn't one in the post" do
        post.topic.image_url.should be_blank
      end

    end

    context "with uploaded images" do

      let(:upload) { Fabricate(:upload) }
      let(:post) { Fabricate(:post_with_uploaded_images) }
      let(:cpp) { CookedPostProcessor.new(post) }
      before { FastImage.stubs(:size) }

      # all in one test to speed things up
      it "works" do
        Upload.expects(:get_from_url).returns(upload).twice
        cpp.post_process_images
        # ensures absolute urls on uploaded images
        cpp.html.should =~ /#{LocalStore.base_url}/
        # dirty
        cpp.should be_dirty
        # keeps the reverse index up to date
        post.uploads.reload
        post.uploads.count.should == 1
      end

    end

    context "with sized images" do

      let(:post) { build(:post_with_image_url) }
      let(:cpp) { CookedPostProcessor.new(post, image_sizes: {'http://foo.bar/image.png' => {'width' => 111, 'height' => 222}}) }

      before { FastImage.stubs(:size).returns([150, 250]) }

      it "doesn't call image_dimensions because it knows the size" do
        cpp.expects(:image_dimensions).never
        cpp.post_process_images
      end

      it "adds the width from the image sizes provided" do
        cpp.post_process_images
        cpp.html.should =~ /width=\"111\"/
        cpp.should be_dirty
      end

    end

    context "with unsized images" do

      let(:post) { build(:post_with_unsized_images) }
      let(:cpp) { CookedPostProcessor.new(post) }

      it "adds the width and height to images that don't have them" do
        FastImage.expects(:size).returns([123, 456])
        cpp.post_process_images
        cpp.html.should =~ /width="123" height="456"/
        cpp.should be_dirty
      end

    end

    context "with large images" do

      let(:upload) { Fabricate(:upload) }
      let(:post) { build(:post_with_large_image) }
      let(:cpp) { CookedPostProcessor.new(post) }

      before do
        SiteSetting.stubs(:create_thumbnails?).returns(true)
        Upload.expects(:get_from_url).returns(upload)
        cpp.stubs(:associate_to_post)
        FastImage.stubs(:size).returns([1000, 2000])
        # optimized_image
        FileUtils.stubs(:mkdir_p)
        File.stubs(:open)
        ImageSorcery.any_instance.expects(:convert).returns(true)
      end

      it "generates overlay information" do
        cpp.post_process_images
        cpp.html.should match_html '<div><a href="http://test.localhost/uploads/default/1/1234567890123456.jpg" class="lightbox"><img src="http://test.localhost/uploads/default/_optimized/da3/9a3/ee5e6b4b0d3_100x200.jpg" width="690" height="1380"><div class="meta">
<span class="filename">uploaded.jpg</span><span class="informations">1000x2000 | 1.21 KB</span><span class="expand"></span>
</div></a></div>'
        cpp.should be_dirty
      end

    end

    context "topic image" do

      let(:topic) { build(:topic, id: 1) }
      let(:post) { Fabricate(:post_with_uploaded_images, topic: topic) }
      let(:cpp) { CookedPostProcessor.new(post) }

      it "adds a topic image if there's one in the post" do
        FastImage.stubs(:size).returns([100, 100])
        cpp.post_process_images
        post.topic.reload
        post.topic.image_url.should == "http://test.localhost/uploads/default/2/3456789012345678.png"
      end

    end

  end

  context "post_process_oneboxes" do

    let(:post) { build(:post_with_youtube, id: 123) }
    let(:cpp) { CookedPostProcessor.new(post, invalidate_oneboxes: true) }

    before do
      Oneboxer.expects(:onebox).with("http://www.youtube.com/watch?v=9bZkp7q19f0", post_id: 123, invalidate_oneboxes: true).returns('<div>GANGNAM STYLE</div>')
      cpp.post_process_oneboxes
    end

    it "should be dirty" do
      cpp.should be_dirty
    end

    it "inserts the onebox without wrapping p" do
      cpp.html.should match_html "<div>GANGNAM STYLE</div>"
    end

  end

  context "get_filename" do

    let(:post) { build(:post) }
    let(:cpp) { CookedPostProcessor.new(post) }

    it "returns the filename of the src when there is no upload" do
      cpp.get_filename(nil, "http://domain.com/image.png").should == "image.png"
    end

    it "returns the original filename of the upload when there is an upload" do
      upload = build(:upload, { original_filename: "upload.jpg" })
      cpp.get_filename(upload, "http://domain.com/image.png").should == "upload.jpg"
    end

    it "returns a generic name for pasted images" do
      upload = build(:upload, { original_filename: "blob.png" })
      cpp.get_filename(upload, "http://domain.com/image.png").should == I18n.t('upload.pasted_image_filename')
    end

  end

  context "image_dimensions" do

    let(:post) { build(:post) }
    let(:cpp) { CookedPostProcessor.new(post) }

    it "calls the resizer" do
      SiteSetting.stubs(:max_image_width).returns(200)
      cpp.expects(:get_size).returns([1000, 2000])
      cpp.image_dimensions("http://foo.bar/image.png").should == [200, 400]
    end

    it "doesn't call the resizer when there is no size" do
      cpp.expects(:get_size).returns(nil)
      cpp.image_dimensions("http://foo.bar/image.png").should == nil
    end

  end

  context "get_size" do

    let(:post) { build(:post) }
    let(:cpp) { CookedPostProcessor.new(post) }

    it "ensures s3 urls have a default scheme" do
      Upload.stubs(:is_on_s3?).returns(true)
      FastImage.stubs(:size)
      cpp.expects(:is_valid_image_uri?).with("http://bucket.s3.aws.amazon.com/image.jpg")
      cpp.get_size("//bucket.s3.aws.amazon.com/image.jpg")
    end

    context "crawl_images is disabled" do

      before { SiteSetting.stubs(:crawl_images?).returns(false) }

      it "doesn't call FastImage" do
        FastImage.expects(:size).never
        cpp.get_size("http://foo.bar/image.png").should == nil
      end

      it "is always allowed to crawled our own images" do
        Upload.expects(:has_been_uploaded?).returns(true)
        FastImage.expects(:size).returns([100, 200])
        cpp.get_size("http://foo.bar/image.png").should == [100, 200]
      end

    end

    it "caches the results" do
      SiteSetting.stubs(:crawl_images?).returns(true)
      FastImage.expects(:size).returns([200, 400])
      cpp.get_size("http://foo.bar/image.png")
      cpp.get_size("http://foo.bar/image.png").should == [200, 400]
    end

  end

  context "is_valid_image_uri?" do

    let(:post) { build(:post) }
    let(:cpp) { CookedPostProcessor.new(post) }

    it "needs the scheme to be either http or https" do
      cpp.is_valid_image_uri?("http://domain.com").should   == true
      cpp.is_valid_image_uri?("https://domain.com").should  == true
      cpp.is_valid_image_uri?("ftp://domain.com").should    == false
      cpp.is_valid_image_uri?("ftps://domain.com").should   == false
      cpp.is_valid_image_uri?("//domain.com").should        == false
      cpp.is_valid_image_uri?("/tmp/image.png").should      == false
    end

    it "doesn't throw an exception with a bad URI" do
      cpp.is_valid_image_uri?("http://do<main.com").should  == nil
    end

  end

end
