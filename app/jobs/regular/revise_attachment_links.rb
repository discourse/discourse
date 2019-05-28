# frozen_string_literal: true

module Jobs
  class ReviseAttachmentLinks < Jobs::Base
    def execute(args)
      post = Post.find_by(id: args[:post_id])
      raise Discourse::InvalidParameter.new(:post_id) unless post

      raw_fragments = Nokogiri::HTML::fragment(post.raw)
      attachments = raw_fragments.css("a[href]")
      changed = false

      attachments.each do |attachment|
        link = attachment.attributes["href"].value

        begin
          uri = URI(link)
        rescue URI::Error
        end

        next if uri.host && uri.host != Discourse.current_hostname

        upload = Upload.get_from_url(link)

        if upload
          attachment_postfix =
            if attachment.attributes["class"]&.value&.split(" ")&.include?("attachment")
              "|attachment"
            else
              ""
            end

          text = attachment.children.text.strip

          attachment.replace("[#{text}#{attachment_postfix}](#{upload.short_url})")
          changed ||= true
        end
      end

      if changed
        post.revise(
          Discourse.system_user,
          {
            raw: raw_fragments.to_s,
            edit_reason: I18n.t("upload.attachments.edit_reason")
          },
          skip_validations: true,
          force_new_version: true,
          bypass_bump: true
        )
      end
    end
  end
end
