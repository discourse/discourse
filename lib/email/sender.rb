# frozen_string_literal: true

#
# A helper class to send an email. It will also handle a nil message, which it considers
# to be "do nothing". This is because some Mailers will decide not to do work for some
# reason. For example, emailing a user too frequently. A nil to address is also considered
# "do nothing"
#
# It also adds an HTML part for the plain text body
#
require "uri"
require "net/smtp"

SMTP_CLIENT_ERRORS = [Net::SMTPFatalError, Net::SMTPSyntaxError]
BYPASS_DISABLE_TYPES = %w[
  admin_login
  test_message
  new_version
  group_smtp
  invite_password_instructions
  download_backup_message
  admin_confirmation_message
]

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

      return if SiteSetting.disable_emails == "yes" && !bypass_disable

      return if ActionMailer::Base::NullMail === @message
      if ActionMailer::Base::NullMail ===
           (
             begin
               @message.message
             rescue StandardError
               nil
             end
           )
        return
      end

      return skip(SkippedEmailLog.reason_types[:sender_message_blank]) if @message.blank?
      return skip(SkippedEmailLog.reason_types[:sender_message_to_blank]) if @message.to.blank?

      if SiteSetting.disable_emails == "non-staff" && !bypass_disable
        return unless find_user&.staff?
      end

      if to_address.end_with?(".invalid")
        return skip(SkippedEmailLog.reason_types[:sender_message_to_invalid])
      end

      if @message.text_part
        if @message.text_part.body.to_s.blank?
          return skip(SkippedEmailLog.reason_types[:sender_text_part_body_blank])
        end
      else
        return skip(SkippedEmailLog.reason_types[:sender_body_blank]) if @message.body.to_s.blank?
      end

      @message.charset = "UTF-8"

      opts = {}

      renderer = Email::Renderer.new(@message, opts)

      if @message.html_part
        @message.html_part.body = renderer.html
      else
        @message.html_part =
          Mail::Part.new do
            content_type "text/html; charset=UTF-8"
            body renderer.html
          end
      end

      # Fix relative (ie upload) HTML links in markdown which do not work well in plain text emails.
      # These are the links we add when a user uploads a file or image.
      # Ideally we would parse general markdown into plain text, but that is almost an intractable problem.
      url_prefix = Discourse.base_url
      @message.parts[0].body =
        @message.parts[0].body.to_s.gsub(
          %r{<a class="attachment" href="(/uploads/default/[^"]+)">([^<]*)</a>},
          '[\2|attachment](' + url_prefix + '\1)',
        )
      @message.parts[0].body =
        @message.parts[0].body.to_s.gsub(
          %r{<img src="(/uploads/default/[^"]+)"([^>]*)>},
          "![](" + url_prefix + '\1)',
        )

      @message.text_part.content_type = "text/plain; charset=UTF-8"
      user_id = @user&.id

      # Set up the email log
      email_log = EmailLog.new(email_type: @email_type, to_address: to_address, user_id: user_id)

      if cc_addresses.any?
        email_log.cc_addresses = cc_addresses.join(";")
        email_log.cc_user_ids = User.with_email(cc_addresses).pluck(:id)
      end

      email_log.bcc_addresses = bcc_addresses.join(";") if bcc_addresses.any?

      host = Email::Sender.host_for(Discourse.base_url)

      post_id = header_value("X-Discourse-Post-Id")
      topic_id = header_value("X-Discourse-Topic-Id")
      reply_key = get_reply_key(post_id, user_id)
      from_address = @message.from&.first
      smtp_group_id =
        (
          if from_address.blank?
            nil
          else
            Group.where(email_username: from_address, smtp_enabled: true).pick(:id)
          end
        )

      # always set a default Message ID from the host
      @message.header["Message-ID"] = Email::MessageIdService.generate_default

      post = nil
      topic = nil
      if topic_id.present? && post_id.present?
        post = Post.find_by(id: post_id, topic_id: topic_id)

        # guards against deleted posts and topics
        return skip(SkippedEmailLog.reason_types[:sender_post_deleted]) if post.blank?

        topic = post.topic
        return skip(SkippedEmailLog.reason_types[:sender_topic_deleted]) if topic.blank?

        add_identification_field_headers(topic, post)

        # See https://www.ietf.org/rfc/rfc2919.txt for the List-ID
        # specification.
        if topic&.category && !topic.category.uncategorized?
          list_id =
            "#{SiteSetting.title} | #{topic.category.name} <#{topic.category.name.downcase.tr(" ", "-")}.#{host}>"

          # subcategory case
          if !topic.category.parent_category_id.nil?
            parent_category_name = Category.find_by(id: topic.category.parent_category_id).name
            list_id =
              "#{SiteSetting.title} | #{parent_category_name} #{topic.category.name} <#{topic.category.name.downcase.tr(" ", "-")}.#{parent_category_name.downcase.tr(" ", "-")}.#{host}>"
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
          @message.header["Precedence"] = "list"
          @message.header["List-ID"] = list_id

          if topic
            if SiteSetting.private_email?
              @message.header[
                "List-Archive"
              ] = "#{Discourse.base_url_no_prefix}#{topic.slugless_url}"
            else
              @message.header["List-Archive"] = topic.url
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

      if reply_key.present?
        @message.header["Reply-To"] = header_value("Reply-To").gsub!("%{reply_key}", reply_key)
        @message.header[Email::MessageBuilder::ALLOW_REPLY_BY_EMAIL_HEADER] = nil
      end

      MessageBuilder
        .custom_headers(SiteSetting.email_custom_headers)
        .each do |key, _|
          # Any custom headers added via MessageBuilder that are doubled up here
          # with values that we determine should be set to the last value, which is
          # the one we determined. Our header values should always override the email_custom_headers.
          #
          # While it is valid via RFC5322 to have more than one value for certain headers,
          # we just want to keep it to one, especially in cases where the custom value
          # would conflict with our own.
          #
          # See https://datatracker.ietf.org/doc/html/rfc5322#section-3.6 and
          # https://github.com/mikel/mail/blob/8ef377d6a2ca78aa5bd7f739813f5a0648482087/lib/mail/header.rb#L109-L132
          custom_header = @message.header[key]
          if custom_header.is_a?(Array)
            our_value = custom_header.last.value

            # Must be set to nil first otherwise another value is just added
            # to the array of values for the header.
            @message.header[key] = nil
            @message.header[key] = our_value
          end

          value = header_value(key)

          # Remove Auto-Submitted header for group private message emails, it does
          # not make sense there and may hurt deliverability.
          #
          # From https://www.iana.org/assignments/auto-submitted-keywords/auto-submitted-keywords.xhtml:
          #
          # > Indicates that a message was generated by an automatic process, and is not a direct response to another message.
          @message.header[key] = nil if key.downcase == "auto-submitted" && smtp_group_id

          # Replace reply_key in custom headers or remove
          if value&.include?("%{reply_key}")
            # Delete old header first or else the same header will be added twice
            @message.header[key] = nil
            @message.header[key] = value.gsub!("%{reply_key}", reply_key) if reply_key.present?
          end
        end

      # pass the original message_id when using mailjet/mandrill/sparkpost
      case ActionMailer::Base.smtp_settings[:address]
      when /\.mailjet\.com/
        @message.header["X-MJ-CustomID"] = @message.message_id
      when "smtp.mandrillapp.com"
        merge_json_x_header("X-MC-Metadata", message_id: @message.message_id)
      when "smtp.sparkpostmail.com"
        merge_json_x_header("X-MSYS-API", metadata: { message_id: @message.message_id })
      end

      # Parse the HTML again so we can make any final changes before
      # sending
      style = Email::Styles.new(@message.html_part.body.to_s)
      if post.present?
        @stripped_secure_upload_shas = style.stripped_upload_sha_map.values
        add_attachments(post)
      elsif @email_type.to_s == "digest"
        @stripped_secure_upload_shas = style.stripped_upload_sha_map.values
        add_attachments(*digest_posts, is_digest: true)
      end

      # Suppress images from short emails
      if SiteSetting.strip_images_from_short_emails &&
           @message.html_part.body.to_s.bytesize <= SiteSetting.short_email_length &&
           @message.html_part.body =~ /<img[^>]+>/
        style.strip_avatars_and_emojis
      end

      # Embeds any of the secure images that have been attached inline,
      # removing the redaction notice.
      if SiteSetting.secure_uploads_allow_embed_images_in_emails
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
        message_response = @message.deliver!

        # TestMailer from the Mail gem does not return a real response, it
        # returns an array containing @message, so we have to have this workaround.
        if message_response.kind_of?(Net::SMTP::Response)
          email_log.smtp_transaction_response = message_response.message&.chomp
        end
      rescue *SMTP_CLIENT_ERRORS => e
        return skip(SkippedEmailLog.reason_types[:custom], custom_reason: e.message)
      end

      DiscourseEvent.trigger(:after_email_send, @message, @email_type)

      email_log.save!
      email_log
    end

    def find_user
      return @user if @user
      User.find_by_email(to_address)
    end

    def to_address
      @to_address ||=
        begin
          to = @message.try(:to)
          to = to.first if Array === to
          to.presence || "no_email_found"
        end
    end

    def cc_addresses
      @cc_addresses ||=
        begin
          @message.try(:cc) || []
        end
    end

    def bcc_addresses
      @bcc_addresses ||=
        begin
          @message.try(:bcc) || []
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

    def digest_posts
      Post.where(id: header_value("X-Discourse-Post-Ids")&.split(","))
    end

    def add_attachments(*posts, is_digest: false)
      max_email_size = SiteSetting.email_total_attachment_size_limit_kb.kilobytes
      return if max_email_size == 0

      email_size = 0
      posts.each do |post|
        next unless DiscoursePluginRegistry.apply_modifier(:should_add_email_attachments, post)

        post.uploads.each do |original_upload|
          optimized_1X = original_upload.optimized_images.first

          # only attach images in digests
          next if is_digest && !FileHelper.is_supported_image?(original_upload.original_filename)

          if FileHelper.is_supported_image?(original_upload.original_filename) &&
               !should_attach_image?(original_upload, optimized_1X)
            next
          end

          attached_upload = optimized_1X || original_upload
          next if email_size + attached_upload.filesize > max_email_size

          begin
            path =
              if attached_upload.local?
                Discourse.store.path_for(attached_upload)
              else
                Discourse.store.download!(attached_upload).path
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
                filename: original_upload.original_filename,
              },
            )
          end
        end
      end

      fix_parts_after_attachments!
    end

    def should_attach_image?(upload, optimized_1X = nil)
      if !SiteSetting.secure_uploads_allow_embed_images_in_emails ||
           # Sometimes images in a post have a secure URL but are not secure uploads,
           # for example if a user uploads an image to a public post then copies the markdown
           # into a PM which sends an email, so we have to make sure we attached those
           # stripped images here as well.
           (
             !upload.secure? && !@stripped_secure_upload_shas.include?(upload.sha1) &&
               !@stripped_secure_upload_shas.include?(optimized_1X&.sha1)
           )
        return
      end
      if (optimized_1X&.filesize || upload.filesize) >
           SiteSetting.secure_uploads_max_email_embed_image_size_kb.kilobytes
        return
      end
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
    # Most imporantly, we need to specify the boundary for the multipart/mixed
    # part of the email, otherwise we can end up with an email that appears to
    # be empty with the entire body attached as a single attachment, and some
    # mail parsers consider the entire email as a preamble/epilogue.
    #
    # c.f. https://www.w3.org/Protocols/rfc1341/7_2_Multipart.html
    def fix_parts_after_attachments!
      has_attachments = @message.attachments.present?
      has_alternative_renderings = @message.html_part.present? && @message.text_part.present?

      if has_attachments && has_alternative_renderings
        @message.content_type = "multipart/mixed; boundary=\"#{@message.body.boundary}\""

        html_part = @message.html_part
        @message.html_part = nil
        @message.parts.reject! { |p| p.content_type.start_with?("text/html") }

        text_part = @message.text_part
        @message.text_part = nil
        @message.parts.reject! { |p| p.content_type.start_with?("text/plain") }

        content =
          Mail::Part.new do
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

      # NOTE: In most cases this is not a problem, but if a header has
      # doubled up the header[] method will return an array. So we always
      # get the last value of the array and assume that is the correct
      # value.
      #
      # See https://github.com/mikel/mail/blob/8ef377d6a2ca78aa5bd7f739813f5a0648482087/lib/mail/header.rb#L109-L132
      return header.last.value if header.is_a?(Array)

      header.value
    end

    def skip(reason_type, custom_reason: nil)
      attributes = {
        email_type: @email_type,
        to_address: to_address,
        user_id: @user&.id,
        reason_type: reason_type,
      }

      attributes[:custom_reason] = custom_reason if custom_reason
      SkippedEmailLog.create!(attributes)
    end

    def merge_json_x_header(name, value)
      data =
        begin
          JSON.parse(@message.header[name].to_s)
        rescue StandardError
          nil
        end
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
      if !user_id || !post_id ||
           !header_value(Email::MessageBuilder::ALLOW_REPLY_BY_EMAIL_HEADER).present?
        return
      end

      PostReplyKey.create_or_find_by!(post_id: post_id, user_id: user_id).reply_key
    end

    def self.bounceable_reply_address?
      SiteSetting.reply_by_email_address.present? && SiteSetting.reply_by_email_address["+"]
    end

    def self.bounce_address(bounce_key)
      SiteSetting.reply_by_email_address.sub("%{reply_key}", "verp-#{bounce_key}")
    end

    ##
    # When sending an email for the first post (OP) of the topic, we do not
    # set References or In-Reply-To headers, since there is nothing yet
    # to reference. This counts as the first email in the thread.
    #
    # Once set, the post's `outbound_message_id` should _always_ be used
    # when sending emails relating to a particular post to maintain threading.
    # This will either be:
    #
    # a) A Message-ID generated in an external main client or service which
    #    is recorded when creating a post from an IncomingEmail via Email::Receiver
    # b) A Message-ID generated by Discourse and recorded when sending an email
    #    for a newly created post, which is created and saved here to the
    #    outbound_message_id column on the Post.
    #
    # The RFC that covers using "Identification Fields", which are References,
    # In-Reply-To, Message-ID, et. al. can be in the RFC link below. It's a good idea to read
    # this beginning in the area immediately after these quotes, at least to understand
    # the 3 main headers:
    #
    # > The "Message-ID:" field provides a unique message identifier that
    # > refers to a particular version of a particular message.  The
    # > uniqueness of the message identifier is guaranteed by the host that
    # > generates it.
    #
    # > ...
    #
    # > The "In-Reply-To:" field may be used to identify the message (or
    # > messages) to which the new message is a reply, while the "References:"
    # > field may be used to identify a "thread" of conversation.
    #
    # https://www.rfc-editor.org/rfc/rfc5322.html#section-3.6.4
    #
    # It is a long read, but to understand the decision making process for this
    # threading logic you can take a look at:
    #
    # https://meta.discourse.org/t/discourse-email-messages-are-incorrectly-threaded/233499
    def add_identification_field_headers(topic, post)
      @message.header["Message-ID"] = Email::MessageIdService.generate_or_use_existing(
        post.id,
      ).first

      if post.post_number > 1
        op_message_id = Email::MessageIdService.generate_or_use_existing(topic.first_post.id).first

        ##
        # Whenever we reply to a post directly _or_ quote a post, a PostReply
        # record is made, with the reply_post_id referencing the newly created
        # post, and the post_id referencing the post that was quoted or replied to.
        referenced_posts =
          Post
            .joins("INNER JOIN post_replies ON post_replies.post_id = posts.id ")
            .where("post_replies.reply_post_id = ?", post.id)
            .order(id: :desc)
            .to_a

        ##
        # No referenced posts means that we are just creating a new post not
        # referring to anything, and as such we should just fall back to using
        # the OP.
        if referenced_posts.empty?
          @message.header["In-Reply-To"] = op_message_id
          @message.header["References"] = op_message_id
        else
          ##
          # When referencing _multiple_ posts then we just choose the most recent one
          # to use for References so we have a single parent to work with, but
          # every directly replied to post can go into In-Reply-To.
          #
          # We want to make sure all of the outbound_message_ids are already filled here.
          in_reply_to_message_ids =
            MessageIdService.generate_or_use_existing(referenced_posts.map(&:id))
          @message.header["In-Reply-To"] = in_reply_to_message_ids
          most_recent_post_message_id = in_reply_to_message_ids.last

          ##
          # The RFC specifically states that the content of the parent's References
          # field (in our case a tree of replies based on the PostReply table in
          # addition to the OP post's Message-ID) first, _then_ the parent's
          # Message-ID (in our case the outbound_message_id of the post we are replying to).
          #
          # This creates a thread from the OP all the way down to the most recent post we
          # are replying to.
          reply_tree = referenced_post_reply_tree(referenced_posts.first)
          parent_message_ids = MessageIdService.generate_or_use_existing(reply_tree.values.flatten)

          @message.header["References"] = [
            op_message_id,
            parent_message_ids,
            most_recent_post_message_id,
          ].flatten.uniq
        end
      end
    end

    def referenced_post_reply_tree(post)
      results = DB.query(<<~SQL, start_post_id: post.id)
        WITH RECURSIVE cte AS (
          SELECT reply_post_id, post_id FROM post_replies
          WHERE reply_post_id = :start_post_id
          UNION
          SELECT pr.reply_post_id, pr.post_id
          FROM post_replies pr
          INNER JOIN cte
          ON cte.post_id = pr.reply_post_id
        )
        SELECT DISTINCT cte.*, posts.created_at, posts.outbound_message_id
        FROM cte
        INNER JOIN posts ON posts.id = cte.reply_post_id
        ORDER BY posts.created_at DESC, post_id DESC;
      SQL
      results.inject({}) do |hash, value|
        # We only want to get a single replied-to post, which is the most recently
        # created post, since we cannot deal with multiple parents for References
        hash[value.reply_post_id] ||= [value.post_id]
        hash
      end
    end
  end
end
