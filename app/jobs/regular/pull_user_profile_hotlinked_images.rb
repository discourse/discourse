# frozen_string_literal: true

module Jobs
  class PullUserProfileHotlinkedImages < ::Jobs::PullHotlinkedImages
    def execute(args)
      @user_id = args[:user_id]
      raise Discourse::InvalidParameters.new(:user_id) if @user_id.blank?

      user_profile = UserProfile.find_by(user_id: @user_id)
      return if user_profile.blank? || user_profile.bio_cooked.nil?

      large_image_urls = []
      broken_image_urls = []
      downloaded_images = {}

      extract_images_from(user_profile.bio_cooked).each do |node|
        download_src = original_src = node["src"] || node["href"]
        download_src =
          "#{SiteSetting.force_https ? "https" : "http"}:#{original_src}" if original_src.start_with?(
          "//",
        )
        normalized_src = normalize_src(download_src)

        next if !should_download_image?(download_src)

        begin
          already_attempted_download =
            downloaded_images.include?(normalized_src) ||
              large_image_urls.include?(normalized_src) ||
              broken_image_urls.include?(normalized_src)
          if !already_attempted_download
            downloaded_images[normalized_src] = attempt_download(download_src, @user_id)
          end
        rescue ImageTooLargeError
          large_image_urls << normalized_src
        rescue ImageBrokenError
          broken_image_urls << normalized_src
        end
      rescue => e
        raise e if Rails.env.test?
        log(
          :error,
          "Failed to pull hotlinked image (#{download_src}) user: #{@user_id}\n" + e.message +
            "\n" + e.backtrace.join("\n"),
        )
      end

      user_profile.bio_raw =
        InlineUploads.replace_hotlinked_image_urls(raw: user_profile.bio_raw) do |match_src|
          normalized_match_src = PostHotlinkedMedia.normalize_src(match_src)
          downloaded_images[normalized_match_src]
        end

      user_profile.skip_pull_hotlinked_image = true
      user_profile.save!
    end
  end
end
