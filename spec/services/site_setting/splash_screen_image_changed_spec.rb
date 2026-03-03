# frozen_string_literal: true

RSpec.describe SiteSetting::SplashScreenImageChanged do
  describe ".call" do
    subject(:result) { described_class.call(params:) }

    fab!(:user)

    def create_svg_upload(svg_content, filename: "splash.svg")
      file = file_from_contents(svg_content, filename, "images")
      UploadCreator.new(file, filename).create_for(user.id)
    end

    def write_upload_file(upload, content)
      path = Discourse.store.path_for(upload)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, content)
    end

    let(:params) { { upload_id: upload.id } }
    let(:upload) { create_svg_upload(svg_content) }

    context "when upload does not exist" do
      let(:upload) { Fabricate(:upload, extension: "svg") }

      before { upload.destroy! }

      it { is_expected.to fail_to_find_a_model(:upload) }
    end

    context "when upload has no valid SVG content" do
      let(:upload) do
        u = Fabricate(:upload, extension: "svg", original_filename: "empty.svg")
        write_upload_file(u, "")
        u
      end

      it { is_expected.to fail_to_find_a_model(:svg) }
    end

    context "when upload content raises when read" do
      let(:upload) { Fabricate(:upload, extension: "svg") }

      it { is_expected.to fail_to_find_a_model(:svg) }
    end

    context "when upload has valid SVG content" do
      let(:svg_with_animate) { <<~SVG }
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="100" height="100">
          <rect x="0" y="0" width="100" height="100" fill="white"/>
          <animate attributeName="opacity" from="1" to="0" dur="1s"/>
        </svg>
      SVG

      context "when cleaned SVG differs from upload content" do
        let(:upload) do
          u = Fabricate(:upload, extension: "svg", original_filename: "splash.svg")
          write_upload_file(u, svg_with_animate)
          u
        end

        it { is_expected.to run_successfully }

        it "updates the upload with new sha1 and url" do
          original_sha1 = upload.sha1
          original_url = upload.url
          result
          upload.reload
          expect(upload.sha1).not_to eq(original_sha1)
          expect(upload.url).not_to eq(original_url)
        end

        it "cleans the SVG (removes animate and width/height when viewBox present)" do
          result
          upload.reload
          doc = Nokogiri.XML(upload.content)
          svg = doc.at_css("svg")
          expect(upload.content).not_to include("animate")
          expect(svg["width"]).to be_nil
          expect(svg["height"]).to be_nil
        end

        it "clears the splash screen SVG cache" do
          Discourse
            .cache
            .expects(:delete)
            .with { |key| key.match?(/\Asplash_screen_svg_#{upload.id}_[a-f0-9]{40}\z/) }
          result
        end
      end

      context "when another upload with the same cleaned sha1 exists" do
        let(:cleaned_svg_content) do
          doc = Nokogiri.XML(svg_with_animate)
          svg = doc.at_css("svg")
          svg.xpath(
            ".//*[local-name()='animate' or local-name()='animateTransform' or local-name()='animateMotion' or local-name()='set']",
          ).each(&:remove)
          svg.remove_attribute("width") if svg["viewBox"].present?
          svg.remove_attribute("height") if svg["viewBox"].present?
          svg.to_xml
        end

        let!(:existing_upload) do
          u = Fabricate(:upload, extension: "svg", original_filename: "existing.svg")
          write_upload_file(u, cleaned_svg_content)
          path = Discourse.store.path_for(u)
          u.update!(sha1: Upload.generate_digest(path))
          u
        end

        let(:upload) do
          u = Fabricate(:upload, extension: "svg", original_filename: "splash.svg")
          write_upload_file(u, svg_with_animate)
          u
        end

        it { is_expected.to run_successfully }

        it "sets splash_screen_image to the existing upload" do
          result
          expect(SiteSetting.splash_screen_image).to eq(existing_upload)
        end

        it "does not update the current upload" do
          original_sha1 = upload.sha1
          result
          expect(upload.reload.sha1).to eq(original_sha1)
        end
      end

      context "when cleaned SVG equals upload content" do
        let(:idempotent_svg) do
          doc = Nokogiri.XML(<<~SVG)
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">
              <rect x="0" y="0" width="10" height="10"/>
            </svg>
          SVG
          svg = doc.at_css("svg")
          svg.remove_attribute("width") if svg["viewBox"].present?
          svg.remove_attribute("height") if svg["viewBox"].present?
          svg.to_xml
        end

        let(:upload) do
          u = Fabricate(:upload, extension: "svg", original_filename: "minimal.svg")
          write_upload_file(u, idempotent_svg)
          u
        end

        it { is_expected.to run_successfully }

        it "does not change the upload sha1 or url" do
          original_sha1 = upload.sha1
          original_url = upload.url
          result
          upload.reload
          expect(upload.sha1).to eq(original_sha1)
          expect(upload.url).to eq(original_url)
        end

        it "still clears the cache" do
          allow(Discourse.cache).to receive(:delete)
          result
          expect(Discourse.cache).to have_received(:delete).with(
            "splash_screen_svg_#{upload.id}_#{upload.sha1}",
          )
        end
      end
    end
  end
end
