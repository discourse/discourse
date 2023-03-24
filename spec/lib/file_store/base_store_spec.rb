# frozen_string_literal: true

RSpec.describe FileStore::BaseStore do
  fab!(:upload) do
    Upload.delete(9999) # In case of any collisions
    Fabricate(:upload, id: 9999, sha1: Digest::SHA1.hexdigest("9999"))
  end

  describe "#get_path_for_upload" do
    def expect_correct_path(expected_path)
      expect(described_class.new.get_path_for_upload(upload)).to eq(expected_path)
    end

    context "with empty URL" do
      before { upload.update!(url: "") }

      it "should return the right path" do
        expect_correct_path("original/2X/4/4170ac2a2782a1516fe9e13d7322ae482c1bd594.png")
      end

      describe "when Upload#extension has not been set" do
        it "should return the right path" do
          upload.update!(extension: nil)
          expect_correct_path("original/2X/4/4170ac2a2782a1516fe9e13d7322ae482c1bd594.png")
        end
      end

      describe "when id is negative" do
        it "should return the right depth" do
          upload.update!(id: -999)
          expect_correct_path("original/1X/4170ac2a2782a1516fe9e13d7322ae482c1bd594.png")
        end
      end
    end

    context "with existing URL" do
      context "with regular site" do
        it "returns the correct path for files stored on local storage" do
          upload.update!(
            url: "/uploads/default/original/1X/63b76551662ccea1a594e161c37dd35188d77657.jpeg",
          )
          expect_correct_path("original/1X/63b76551662ccea1a594e161c37dd35188d77657.jpeg")

          upload.update!(
            url: "/uploads/default/original/3X/63/63b76551662ccea1a594e161c37dd35188d77657.jpeg",
          )
          expect_correct_path("original/3X/63/63b76551662ccea1a594e161c37dd35188d77657.jpeg")
        end

        it "returns the correct path for files stored on S3" do
          upload.update!(
            url:
              "//bucket-name.s3.dualstack.us-west-2.amazonaws.com/original/1X/63b76551662ccea1a594e161c37dd35188d77657.jpeg",
          )
          expect_correct_path("original/1X/63b76551662ccea1a594e161c37dd35188d77657.jpeg")

          upload.update!(
            url:
              "//bucket-name.s3.dualstack.us-west-2.amazonaws.com/original/3X/63/63b76551662ccea1a594e161c37dd35188d77657.jpeg",
          )
          expect_correct_path("original/3X/63/63b76551662ccea1a594e161c37dd35188d77657.jpeg")
        end
      end

      context "with multisite" do
        it "returns the correct path for files stored on local storage" do
          upload.update!(
            url: "/uploads/foo/original/1X/63b76551662ccea1a594e161c37dd35188d77657.jpeg",
          )
          expect_correct_path("original/1X/63b76551662ccea1a594e161c37dd35188d77657.jpeg")

          upload.update!(
            url: "/uploads/foo/original/3X/63/63b76551662ccea1a594e161c37dd35188d77657.jpeg",
          )
          expect_correct_path("original/3X/63/63b76551662ccea1a594e161c37dd35188d77657.jpeg")
        end

        it "returns the correct path for files stored on S3" do
          upload.update!(
            url:
              "//bucket-name.s3.dualstack.us-west-2.amazonaws.com/uploads/foo/original/1X/63b76551662ccea1a594e161c37dd35188d77657.jpeg",
          )
          expect_correct_path("original/1X/63b76551662ccea1a594e161c37dd35188d77657.jpeg")

          upload.update!(
            url:
              "//bucket-name.s3.dualstack.us-west-2.amazonaws.com/uploads/foo/original/3X/63/63b76551662ccea1a594e161c37dd35188d77657.jpeg",
          )
          expect_correct_path("original/3X/63/63b76551662ccea1a594e161c37dd35188d77657.jpeg")
        end

        it "returns the correct path when the site name is 'original'" do
          upload.update!(
            url: "/uploads/original/original/1X/63b76551662ccea1a594e161c37dd35188d77657.jpeg",
          )
          expect_correct_path("original/1X/63b76551662ccea1a594e161c37dd35188d77657.jpeg")

          upload.update!(
            url:
              "//bucket-name.s3.dualstack.us-west-2.amazonaws.com/uploads/original/original/1X/63b76551662ccea1a594e161c37dd35188d77657.jpeg",
          )
          expect_correct_path("original/1X/63b76551662ccea1a594e161c37dd35188d77657.jpeg")
        end
      end
    end
  end

  describe "#get_path_for_optimized_image" do
    let!(:upload) { Fabricate.build(:upload, id: 100) }
    let!(:optimized_path) { "optimized/1X/#{upload.sha1}_1_100x200.png" }

    context "with empty URL" do
      it "should return the right path" do
        optimized = Fabricate.build(:optimized_image, upload: upload, version: 1)
        expect(FileStore::BaseStore.new.get_path_for_optimized_image(optimized)).to eq(
          optimized_path,
        )
      end

      it "should return the right path for `nil` version" do
        optimized = Fabricate.build(:optimized_image, upload: upload, version: nil)
        expect(FileStore::BaseStore.new.get_path_for_optimized_image(optimized)).to eq(
          optimized_path,
        )
      end
    end

    context "with existing URL" do
      let!(:optimized) { Fabricate.build(:optimized_image, upload: upload, version: 1) }
      let!(:optimized_path) { "optimized/1X/#{upload.sha1}_1_100x200.jpg" }

      def expect_correct_optimized_path
        expect(described_class.new.get_path_for_optimized_image(optimized)).to eq(optimized_path)
      end

      context "with regular site" do
        it "returns the correct path for files stored on local storage" do
          optimized.update!(url: "/uploads/default/optimized/1X/#{upload.sha1}_1_100x200.jpg")
          expect_correct_optimized_path
        end

        it "returns the correct path for files stored on S3" do
          optimized.update!(
            url:
              "//bucket-name.s3.dualstack.us-west-2.amazonaws.com/optimized/1X/#{upload.sha1}_1_100x200.jpg",
          )
          expect_correct_optimized_path
        end
      end

      context "with multisite" do
        it "returns the correct path for files stored on local storage" do
          optimized.update!(url: "/uploads/foo/optimized/1X/#{upload.sha1}_1_100x200.jpg")
          expect_correct_optimized_path
        end

        it "returns the correct path for files stored on S3" do
          optimized.update!(
            url:
              "//bucket-name.s3.dualstack.us-west-2.amazonaws.com/uploads/foo/optimized/1X/#{upload.sha1}_1_100x200.jpg",
          )
          expect_correct_optimized_path
        end

        it "returns the correct path when the site name is 'optimized'" do
          optimized.update!(url: "/uploads/optimized/optimized/1X/#{upload.sha1}_1_100x200.jpg")
          expect_correct_optimized_path

          optimized.update!(
            url:
              "//bucket-name.s3.dualstack.us-west-2.amazonaws.com/uploads/optimized/optimized/1X/#{upload.sha1}_1_100x200.jpg",
          )
          expect_correct_optimized_path
        end
      end
    end
  end

  describe "#download" do
    before do
      setup_s3
      stub_request(:get, upload_s3.url).to_return(status: 200, body: "Hello world")
    end

    let(:upload_s3) { Fabricate(:upload_s3) }
    let(:store) { FileStore::BaseStore.new }

    it "should return consistent encodings for fresh and cached downloads" do
      # Net::HTTP always returns binary ASCII-8BIT encoding. File.read auto-detects the encoding
      # Make sure we File.read after downloading a file for consistency

      first_encoding = store.download(upload_s3).read.encoding

      second_encoding = store.download(upload_s3).read.encoding

      expect(first_encoding).to eq(Encoding::UTF_8)
      expect(second_encoding).to eq(Encoding::UTF_8)
    end

    it "should return the file" do
      file = store.download(upload_s3)

      expect(file.class).to eq(File)
    end

    it "should return the file when s3 cdn enabled" do
      SiteSetting.s3_cdn_url = "https://cdn.s3.#{SiteSetting.s3_region}.amazonaws.com"
      stub_request(:get, Discourse.store.cdn_url(upload_s3.url)).to_return(
        status: 200,
        body: "Hello world",
      )

      file = store.download(upload_s3)

      expect(file.class).to eq(File)
    end

    it "should return the file when secure uploads are enabled" do
      SiteSetting.login_required = true
      SiteSetting.secure_uploads = true

      stub_request(:head, "https://s3-upload-bucket.s3.#{SiteSetting.s3_region}.amazonaws.com/")
      signed_url = Discourse.store.signed_url_for_path(upload_s3.url)
      stub_request(:get, signed_url).to_return(status: 200, body: "Hello world")

      file = store.download(upload_s3)

      expect(file.class).to eq(File)
    end
  end
end
