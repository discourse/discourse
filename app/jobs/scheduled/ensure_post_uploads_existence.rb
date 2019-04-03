# frozen_string_literal: true

module Jobs

  class EnsurePostUploadsExistence < Jobs::Scheduled
    every 1.hour

    MISSING_UPLOADS ||= "missing_uploads"

    def execute(args)
      PostCustomField
        .where(name: MISSING_UPLOADS)
        .where("created_at < ?", 1.month.ago)
        .destroy_all

      Post
        .joins("LEFT JOIN post_custom_fields cf ON posts.id = cf.post_id AND cf.name = 'missing_uploads'")
        .where("(posts.cooked LIKE '%<a %' OR posts.cooked LIKE '%<img %') AND cf.id IS NULL")
        .find_in_batches(batch_size: 100) do |posts|

          Post.preload_custom_fields(posts, [MISSING_UPLOADS])

          posts.each do |post|
            fragments ||= Nokogiri::HTML::fragment(post.cooked)
            missing = []

            fragments.css("a/@href", "img/@src").each do |media|
              src = media.value
              next if src.blank? || (src =~ /\/uploads\//).blank?

              src = "#{SiteSetting.force_https ? "https" : "http"}:#{src}" if src.start_with?("//")
              next unless Discourse.store.has_been_uploaded?(src) || src =~ /\A\/[^\/]/i

              missing << src unless Upload.get_from_url(src) || OptimizedImage.get_from_url(src)
            end

            if missing.present?
              post.preloaded_custom_fields = nil
              post.custom_fields[MISSING_UPLOADS] = missing
              post.save_custom_fields
            elsif post.custom_fields[MISSING_UPLOADS].present?
              PostCustomField.find_by(post_id: post.id, name: MISSING_UPLOADS).destroy!
            end
          end
      end
    end
  end
end
