# frozen_string_literal: true

#
# A helper class to send an email. It will also handle a nil message, which it considers
# to be "do nothing". This is because some Mailers will decide not to do work for some
# reason. For example, emailing a user too frequently. A nil to address is also considered
# "do nothing"
#
# It also adds an HTML part for the plain text body
#
require 'uri'
require 'net/smtp'

SMTP_CLIENT_ERRORS = [Net::SMTPFatalError, Net::SMTPSyntaxError]
BYPASS_DISABLE_TYPES = %w(
  admin_login
  test_message
  new_version
  group_smtp
  invite_password_instructions
  download_backup_message
  admin_confirmation_message
)

module Email
  class Sender

    def initialize(message, email_type, user = nil)
      @message = message
      @message_attachments_index = {}
      @email_type = email_type
      @user = user
    end

    def send
      bypass_disable = BYPASS_DISABLE_TYPES.include?(@email_type.to_s)

      if SiteSetting.disable_emails == "yes" && !bypass_disable
        return
      end

      return if ActionMailer::Base::NullMail === @message
      return if ActionMailer::Base::NullMail === (@message.message rescue nil)

      return skip(SkippedEmailLog.reason_types[:sender_message_blank])    if @message.blank?
      return skip(SkippedEmailLog.reason_types[:sender_message_to_blank]) if @message.to.blank?

      if SiteSetting.disable_emails == "non-staff" && !bypass_disable
        return unless find_user&.staff?
      end

      return skip(SkippedEmailLog.reason_types[:sender_message_to_invalid]) if to_address.end_with?(".invalid")

      if @message.text_part
        if @message.text_part.body.to_s.blank?
          return skip(SkippedEmailLog.reason_types[:sender_text_part_body_blank])
        end
      else
        if @message.body.to_s.blank?
          return skip(SkippedEmailLog.reason_types[:sender_body_blank])
        end
      end

      @message.charset = 'UTF-8'

      opts = {}

      renderer = Email::Renderer.new(@message, opts)

      if @message.html_part
        @message.html_part.body = renderer.html
      else
        @message.html_part = Mail::Part.new do
          content_type 'text/html; charset=UTF-8'
          body renderer.html
        end
      end

      # Fix relative (ie upload) HTML links in markdown which do not work well in plain text emails.
      # These are the links we add when a user uploads a file or image.
      # Ideally we would parse general markdown into plain text, but that is almost an intractable problem.
      url_prefix = Discourse.base_url
      @message.parts[0].body = @message.parts[0].body.to_s.gsub(/<a class="attachment" href="(\/uploads\/default\/[^"]+)">([^<]*)<\/a>/, '[\2|attachment](' + url_prefix + '\1)')
      @message.parts[0].body = @message.parts[0].body.to_s.gsub(/<img src="(\/uploads\/default\/[^"]+)"([^>]*)>/, '![](' + url_prefix + '\1)')

      @message.text_part.content_type = 'text/plain; charset=UTF-8'
      user_id = @user&.id

      # Set up the email log
      email_log = EmailLog.new(
        email_type: @email_type,
        to_address: to_address,
        user_id: user_id
      )

      if cc_addresses.any?
        email_log.cc_addresses = cc_addresses.join(";")
        email_log.cc_user_ids = User.with_email(cc_addresses).pluck(:id)
      end

      host = Email::Sender.host_for(Discourse.base_url)

      post_id   = header_value('X-Discourse-Post-Id')
      topic_id  = header_value('X-Discourse-Topic-Id')
      reply_key = get_reply_key(post_id, user_id)
      from_address = @message.from&.first
      smtp_group_id = from_address.blank? ? nil : Group.where(
        email_username: from_address, smtp_enabled: true
      ).pluck_first(:id)

      # always set a default Message ID from the host
      @message.header['Message-ID'] = Email::MessageIdService.generate_default

      if topic_id.present? && post_id.present?
        post = Post.find_by(id: post_id, topic_id: topic_id)

        # guards against deleted posts and topics
        return skip(SkippedEmailLog.reason_types[:sender_post_deleted]) if post.blank?

        topic = post.topic
        return skip(SkippedEmailLog.reason_types[:sender_topic_deleted]) if topic.blank?

        add_attachments(post)

        # If the topic was created from an incoming email, then the Message-ID from
        # that email will be the canonical reference, otherwise the canonical reference
        # will be <topic/TOPIC_ID@host>. The canonical reference is used in the
        # References header.
        #
        # This is so the sender of the original email still gets their nice threading
        # maintained (because their mail client will initiate threading based on
        # the Message-ID it generated) in the case where there is an incoming email.
        #
        # In the latter case, everyone will start their thread with the canonical reference,
        # because we send it in the References header for all emails.
        topic_canonical_reference_id = Email::MessageIdService.generate_for_topic(
          topic, canonical: true, use_incoming_email_if_present: true
        )

        referenced_posts = Post.includes(:incoming_email)
          .joins("INNER JOIN post_replies ON post_replies.post_id = posts.id ")
          .where("post_replies.reply_post_id = ?", post_id)
          .order(id: :desc)

        referenced_post_message_ids = referenced_posts.map do |referenced_post|
          if referenced_post.incoming_email&.message_id.present?
            "<#{referenced_post.incoming_email.message_id}>"
          else
            if referenced_post.post_number == 1
              topic_canonical_reference_id
            else
              Email::MessageIdService.generate_for_post(referenced_post)
            end
          end
        end

        # See https://www.ietf.org/rfc/rfc2822.txt for the message format
        # specification, more useful information can be found in Email::MessageIdService
        #
        # The References header is how mail clients handle threading. The Message-ID
        # must always be unique.
        if post.post_number == 1
          @message.header['Message-ID']  = Email::MessageIdService.generate_for_topic(topic)
          @message.header['References']  = [topic_canonical_reference_id]
        else
          @message.header['Message-ID']  = Email::MessageIdService.generate_for_post(post)
          @message.header['In-Reply-To'] = referenced_post_message_ids[0] || topic_canonical_reference_id
          @message.header['References']  = [topic_canonical_reference_id, referenced_post_message_ids].flatten.compact.uniq
        end

        # See https://www.ietf.org/rfc/rfc2919.txt for the List-ID
        # specification.
        if topic&.category && !topic.category.uncategorized?
          list_id = "#{SiteSetting.title} | #{topic.category.name} <#{topic.category.name.downcase.tr(' ', '-')}.#{host}>"

          # subcategory case
          if !topic.category.parent_category_id.nil?
            parent_category_name = Category.find_by(id: topic.category.parent_category_id).name
            list_id = "#{SiteSetting.title} | #{parent_category_name} #{topic.category.name} <#{topic.category.name.downcase.tr(' ', '-')}.#{parent_category_name.downcase.tr(' ', '-')}.#{host}>"
          end
        else
          list_id = "#{SiteSetting.title} <#{host}>"
        end

        # When we are emailing people from a group inbox, we are having a PM
        # conversation with them, as a support account would. In this case
        # mailing list headers do not make sense. It is not like a forum topic
        # where you may have tens or hundreds of participants -- it is a
        # conversation between the group and a small handful of people
        # directly contacting the group, often just one person.
        if !smtp_group_id

          # https://www.ietf.org/rfc/rfc3834.txt
          @message.header['Precedence'] = 'list'
          @message.header['List-ID']    = list_id

          if topic
            if SiteSetting.private_email?
              @message.header['List-Archive'] = "#{Discourse.base_url}#{topic.slugless_url}"
            else
              @message.header['List-Archive'] = topic.url
            end
          end
        end
      end

      if Email::Sender.bounceable_reply_address?
        email_log.bounce_key = SecureRandom.hex

        # WARNING: RFC claims you can not set the Return Path header, this is 100% correct
        # however Rails has special handling for this header and ends up using this value
        # as the Envelope From address so stuff works as expected
        @message.header[:return_path] = Email::Sender.bounce_address(email_log.bounce_key)
      end

      email_log.post_id = post_id if post_id.present?
      email_log.topic_id = topic_id if topic_id.present?

      # Remove headers we don't need anymore
      @message.header['X-Discourse-Topic-Id'] = nil if topic_id.present?
      @message.header['X-Discourse-Post-Id']  = nil if post_id.present?

      if reply_key.present?
        @message.header['Reply-To'] = header_value('Reply-To').gsub!("%{reply_key}", reply_key)
        @message.header[Email::MessageBuilder::ALLOW_REPLY_BY_EMAIL_HEADER] = nil
      end

      MessageBuilder.custom_headers(SiteSetting.email_custom_headers).each do |key, _|
        value = header_value(key)

        # Remove Auto-Submitted header for group private message emails, it does
        # not make sense there and may hurt deliverability.
        #
        # From https://www.iana.org/assignments/auto-submitted-keywords/auto-submitted-keywords.xhtml:
        #
        # > Indicates that a message was generated by an automatic process, and is not a direct response to another message.
        if key.downcase == "auto-submitted" && smtp_group_id
          @message.header[key] = nil
        end

        # Replace reply_key in custom headers or remove
        if value&.include?('%{reply_key}')
          # Delete old header first or else the same header will be added twice
          @message.header[key] = nil
          if reply_key.present?
            @message.header[key] = value.gsub!('%{reply_key}', reply_key)
          end
        end
      end

      # pass the original message_id when using mailjet/mandrill/sparkpost
      case ActionMailer::Base.smtp_settings[:address]
      when /\.mailjet\.com/
        @message.header['X-MJ-CustomID'] = @message.message_id
      when "smtp.mandrillapp.com"
        merge_json_x_header('X-MC-Metadata', message_id: @message.message_id)
      when "smtp.sparkpostmail.com"
        merge_json_x_header('X-MSYS-API', metadata: { message_id: @message.message_id })
      end

      # Parse the HTML again so we can make any final changes before
      # sending
      style = Email::Styles.new(@message.html_part.body.to_s)

      # Suppress images from short emails
      if SiteSetting.strip_images_from_short_emails &&
        @message.html_part.body.to_s.bytesize <= SiteSetting.short_email_length &&
        @message.html_part.body =~ /<img[^>]+>/
        style.strip_avatars_and_emojis
      end

      # Embeds any of the secure images that have been attached inline,
      # removing the redaction notice.
      if SiteSetting.secure_media_allow_embed_images_in_emails
        style.inline_secure_images(@message.attachments, @message_attachments_index)
      end

      @message.html_part.body = style.to_s

      email_log.message_id = @message.message_id

      # Log when a message is being sent from a group SMTP address, so we
      # can debug deliverability issues.
      if smtp_group_id
        email_log.smtp_group_id = smtp_group_id

        # Store contents of all outgoing emails using group SMTP
        # for greater visibility and debugging. If the size of this
        # gets out of hand, we should look into a group-level setting
        # to enable this; size should be kept in check by regular purging
        # of EmailLog though.
        email_log.raw = Email::Cleaner.new(@message).execute
      end

      DiscourseEvent.trigger(:before_email_send, @message, @email_type)

      begin
        @message.deliver_now
      rescue *SMTP_CLIENT_ERRORS => e
        return skip(SkippedEmailLog.reason_types[:custom], custom_reason: e.message)
      end

      email_log.save!
      email_log
    end

    def find_user
      return @user if @user
      User.find_by_email(to_address)
    end

    def to_address
      @to_address ||= begin
        to = @message.try(:to)
        to = to.first if Array === to
        to.presence || "no_email_found"
      end
    end

    def cc_addresses
      @cc_addresses ||= begin
        @message.try(:cc) || []
      end
    end

    def self.host_for(base_url)
      host = "localhost"
      if base_url.present?
        begin
          uri = URI.parse(base_url)
          host = uri.host.downcase if uri.host.present?
        rescue URI::Error
        end
      end
      host
    end

    private

    def add_attachments(post)
      max_email_size = SiteSetting.email_total_attachment_size_limit_kb.kilobytes
      return if max_email_size == 0

      email_size = 0
      post.uploads.each do |original_upload|
        optimized_1X = original_upload.optimized_images.first

        if FileHelper.is_supported_image?(original_upload.original_filename) &&
            !should_attach_image?(original_upload, optimized_1X)
          next
        end

        attached_upload = optimized_1X || original_upload
        next if email_size + attached_upload.filesize > max_email_size

        begin
          path = if attached_upload.local?
            Discourse.store.path_for(attached_upload)
          else
            Discourse.store.download(attached_upload).path
          end

          @message_attachments_index[original_upload.sha1] = @message.attachments.size
          @message.attachments[original_upload.original_filename] = File.read(path)
          email_size += File.size(path)
        rescue => e
          Discourse.warn_exception(
            e,
            message: "Failed to attach file to email",
            env: {
              post_id: post.id,
              upload_id: original_upload.id,
              filename: original_upload.original_filename
            }
          )
        end
      end

      fix_parts_after_attachments!
    end

    def should_attach_image?(upload, optimized_1X = nil)
      return if !SiteSetting.secure_media_allow_embed_images_in_emails || !upload.secure?
      return if (optimized_1X&.filesize || upload.filesize) > SiteSetting.secure_media_max_email_embed_image_size_kb.kilobytes
      true
    end

    #
    # Two behaviors in the mail gem collide:
    #
    #  1. Attachments are added as extra parts at the top level,
    #  2. When there are both text and html parts, the content type is set
    #     to 'multipart/alternative'.
    #
    # Since attachments aren't alternative renderings, for emails that contain
    # attachments and both html and text parts, some coercing is necessary.
    #
    # When there are alternative rendering and attachments, this method causes
    # the top level to be 'multipart/mixed' and puts the html and text parts
    # into a nested 'multipart/alternative' part.
    #
    # Due to mail gem magic, @message.text_part and @message.html_part still
    # refer to the same objects.
    #
    def fix_parts_after_attachments!
      has_attachments = @message.attachments.present?
      has_alternative_renderings =
        @message.html_part.present? && @message.text_part.present?

      if has_attachments && has_alternative_renderings
        @message.content_type = "multipart/mixed"

        html_part = @message.html_part
        @message.html_part = nil

        text_part = @message.text_part
        @message.text_part = nil

        content = Mail::Part.new do
          content_type "multipart/alternative"

          # we have to re-specify the charset and give the part the decoded body
          # here otherwise the parts will get encoded with US-ASCII which makes
          # a bunch of characters not render correctly in the email
          part content_type: "text/html; charset=utf-8", body: html_part.body.decoded
          part content_type: "text/plain; charset=utf-8", body: text_part.body.decoded
        end

        @message.parts.unshift(content)
      end
    end

    def header_value(name)
      header = @message.header[name]
      return nil unless header
      header.value
    end

    def skip(reason_type, custom_reason: nil)
      attributes = {
        email_type: @email_type,
        to_address: to_address,
        user_id: @user&.id,
        reason_type: reason_type
      }

      attributes[:custom_reason] = custom_reason if custom_reason
      SkippedEmailLog.create!(attributes)
    end

    def merge_json_x_header(name, value)
      data   = JSON.parse(@message.header[name].to_s) rescue nil
      data ||= {}
      data.merge!(value)
      # /!\ @message.header is not a standard ruby hash.
      # It can have multiple values attached to the same key...
      # In order to remove all the previous keys, we have to "nil" it.
      # But for "nil" to work, there must already be a key...
      @message.header[name] = ""
      @message.header[name] = nil
      @message.header[name] = data.to_json
    end

    def get_reply_key(post_id, user_id)
      # ALLOW_REPLY_BY_EMAIL_HEADER is only added if we are _not_ sending
      # via group SMTP and if reply by email site settings are configured
      return if !user_id || !post_id || !header_value(Email::MessageBuilder::ALLOW_REPLY_BY_EMAIL_HEADER).present?

      # use safe variant here cause we tend to see concurrency issue
      reply_key = PostReplyKey.find_or_create_by_safe!(
        post_id: post_id,
        user_id: user_id
      ).reply_key
    end

    def self.bounceable_reply_address?
      SiteSetting.reply_by_email_address.present? && SiteSetting.reply_by_email_address["+"]
    end

    def self.bounce_address(bounce_key)
      SiteSetting.reply_by_email_address.sub("%{reply_key}", "verp-#{bounce_key}")
    end
  end
end
