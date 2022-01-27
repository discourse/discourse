# frozen_string_literal: true

require 'faker'
require 'net/http'
require 'json'

module Faker
  class DiscourseMarkdown < Markdown
    class << self
      attr_writer(:user_id)

      def user_id
        @user_id || ::Discourse::SYSTEM_USER_ID
      end

      def with_user(user_id)
        current_user_id = self.user_id
        self.user_id = user_id
        begin
          yield
        ensure
          self.user_id = current_user_id
        end
      end

      def image
        image = next_image
        image_file = load_image(image)

        upload = ::UploadCreator.new(
          image_file,
          image[:filename],
          origin: image[:url]
        ).create_for(user_id)

        ::UploadMarkdown.new(upload).to_markdown if upload.present? && upload.persisted?
      rescue => e
        STDERR.puts e
        STDERR.puts e.backtrace.join("\n")
      end

      private

      def next_image
        if @images.blank?
          if @stop_loading_images
            @images = @all_images.dup
          else
            @next_page = (@next_page || 0) + 1
            url = URI("https://picsum.photos/v2/list?page=#{@next_page}&limit=50")
            response = Net::HTTP.get(url)
            json = JSON.parse(response)

            if json.blank?
              @stop_loading_images = true
              @images = @all_images.dup
            else
              @images = json.sort_by { |image| image["id"] }
              @all_images = (@all_images || []).concat(@images)
            end
          end
        end

        image = @images.pop
        { filename: "#{image['id']}.jpg", url: "#{image['download_url']}.jpg" }
      end

      def image_cache_dir
        @image_cache_dir ||= ::File.join(Rails.root, "tmp", "discourse_dev", "images")
      end

      def load_image(image)
        cache_path = ::File.join(image_cache_dir, image[:filename])

        if !::File.exist?(cache_path)
          FileUtils.mkdir_p(image_cache_dir)
          temp_file = ::FileHelper.download(
            image[:url],
            max_file_size: [SiteSetting.max_image_size_kb.kilobytes, 10.megabytes].max,
            tmp_file_name: "image",
            follow_redirect: true
          )
          FileUtils.cp(temp_file, cache_path)
        end

        ::File.open(cache_path)
      end

      def available_methods
        methods = super
        methods << :image if ::DiscourseDev.config.post[:include_images]
        methods
      end
    end
  end
end
