require 'spec_helper'

describe OptimizedImage do

  it { should belong_to :upload }

  let(:upload) { build(:upload) }
  let(:oi) { OptimizedImage.create_for(upload, 100, 100) }

  describe ".create_for" do

    before(:each) do
      ImageSorcery.any_instance.stubs(:convert).returns(true)
      FastImage.any_instance.stubs(:size).returns([244, 66])
      # make sure we don't hit the filesystem
      FileUtils.stubs(:mkdir_p)
      File.stubs(:open)
    end

    it "works" do
      Tempfile.any_instance.expects(:close).once
      Tempfile.any_instance.expects(:unlink).once
      oi.sha1.should == "da39a3ee5e6b4b0d3255bfef95601890afd80709"
      oi.extension.should == ".jpg"
      oi.width.should == 244
      oi.height.should == 66
    end

  end

end
