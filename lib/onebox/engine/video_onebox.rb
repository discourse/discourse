# frozen_string_literal: true

module Onebox
  module Engine
    class VideoOnebox
      include Engine
      # 添加对m3u8文件的匹配
      matches_regexp(%r{^(https?:)?//.*\.(mov|mp4|webm|ogv|m3u8)(\?.*)?$}i)
      def always_https?
        AllowlistedGenericOnebox.host_matches(uri, AllowlistedGenericOnebox.https_hosts)
      end
      def to_html
        # 判断是否是m3u8文件，如果是，则使用适用于Video.js的HTML模板
        if @url.match(%r{\.m3u8$})
          # 获取时间戳，并添加一段八位随机数
          randomId = Time.now.to_i.to_s + rand(100000000).to_s
          video_tag_html = <<-HTML
          <div class="videoWrap evan-hls-video">
            <video id='#{randomId}' class="video-js vjs-default-skin vjs-16-9" controls preload="auto" width="100%" data-setup='{"fluid": true}'>
              <source src="#{@url}" type="application/x-mpegURL">
            </video>
          </div>
          HTML
        else
          # 原有处理非m3u8文件的代码保持不变
          escaped_url = ::Onebox::Helpers.normalize_url_for_output(@url)
          video_tag_html = <<-HTML
            <div class="onebox video-onebox">
              <video width='100%' height='100%' controls #{@options[:disable_media_download_controls] ? 'controlslist="nodownload"' : ""}>
                <source src='#{escaped_url}'>
                <a href='#{escaped_url}'>#{@url}</a>
              </video>
            </div>
          HTML
        end
        video_tag_html
      end

      def placeholder_html
        SiteSetting.enable_diffhtml_preview ? to_html : ::Onebox::Helpers.video_placeholder_html
      end
    end
  end
end
