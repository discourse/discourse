# frozen_string_literal: true

class SiteSetting::SplashScreenImageChanged
  include Service::Base

  params { attribute :upload_id, :integer }

  model :upload
  model :svg
  model :cleaned_svg
  step :save_cleaned_svg_upload
  step :clear_cache

  private

  def fetch_upload(params:)
    Upload.find_by(id: params.upload_id)
  end

  def fetch_svg(upload:)
    content =
      begin
        upload.content
      rescue StandardError
        nil
      end

    return nil if content.blank?

    Nokogiri.XML(content).at_css("svg")
  end

  def fetch_cleaned_svg(svg:)
    # Disables SMIL animations which can cause performance issues,
    # CSS animations are preferred.
    svg.xpath(
      ".//*[local-name()='animate' or local-name()='animateTransform' or local-name()='animateMotion' or local-name()='set']",
    ).each(&:remove)

    # Remove explicit dimensions so the SVG scales via viewBox
    if svg["viewBox"].present?
      svg.remove_attribute("width")
      svg.remove_attribute("height")
    end

    svg.to_xml
  end

  def save_cleaned_svg_upload(cleaned_svg:, upload:)
    return if cleaned_svg == upload.content

    Tempfile.open(%w[splash_screen .svg]) do |tmp|
      tmp.write(cleaned_svg)
      tmp.rewind

      new_sha1 = Upload.generate_digest(tmp.path)
      existing = Upload.find_by(sha1: new_sha1)

      if existing && existing.id != upload.id
        SiteSetting.splash_screen_image = existing.id
      else
        old_path = Discourse.store.get_path_for_upload(upload)
        old_url = upload.url
        upload.tap do |u|
          u.sha1 = new_sha1
          u.filesize = tmp.size
          u.url = Discourse.store.store_upload(tmp, u)
          u.save!(validate: false)
        end

        Discourse.store.remove_file(old_url, old_path) if upload.url != old_url
      end
    end
  end

  def clear_cache(upload:)
    Discourse.cache.delete("splash_screen_svg_#{upload.id}_#{upload.sha1}")
  end
end
