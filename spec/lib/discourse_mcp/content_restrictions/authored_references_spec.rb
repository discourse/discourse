# frozen_string_literal: true

require_relative "write_support"

# Each variant is calibrated against its own unrestricted baseline.
# rubocop:disable Discourse/NoIterationOverRSpecDefinitions

describe DiscourseMcp::Server, "#call" do
  include_context "with MCP content write rules"

  let(:group) do
    group = Fabricate(:group, name: "u4writers")
    group.add_owner(recipient)
    group.update!(allow_membership_requests: true)
    group
  end
  let(:private_post) { Fabricate(:private_message_post, user: admin) }

  def write_case(field, text)
    case field
    when "topic.title", "topic.raw"
      ["discourse_create_topic", topic_arguments(**{ field.split(".").last.to_sym => text })]
    when "reply.raw"
      ["discourse_create_post", { topic_id: post.topic_id, raw: text }]
    when "edit.raw", "edit.edit_reason"
      [
        "discourse_update_post",
        {
          :post_id => post.id,
          :raw => McpContentWriteHelpers::PROSE + " More observations follow.",
          field.split(".").last.to_sym => text,
        },
      ]
    when "update_topic.title", "update_topic.featured_link"
      [
        "discourse_update_topic",
        { :topic_id => post.topic_id, field.split(".").last.to_sym => text },
      ]
    when "pm.title", "pm.raw"
      [
        "discourse_create_private_message",
        {
          :title => "An exchange about our garden plans",
          :raw => McpContentWriteHelpers::PROSE,
          :usernames => [recipient.username],
          field.split(".").last.to_sym => text,
        },
      ]
    when "pm_invite.custom_message"
      [
        "discourse_invite_to_private_message",
        {
          topic_id: private_post.topic_id,
          email_address: "u4invite@example.com",
          custom_message: text,
        },
      ]
    when "pm_reply.raw"
      ["discourse_reply_private_message", { topic_id: private_post.topic_id, raw: text }]
    when "category_create.name"
      ["discourse_create_category", { name: text }]
    when "category_update.name"
      ["discourse_update_category", { category_id: allowed_category.id, name: text }]
    when "category_create.description"
      ["discourse_create_category", { name: "Seasonal writing", description: text }]
    when "category_update.description"
      category = Fabricate(:category_with_definition, user: admin)
      ["discourse_update_category", { category_id: category.id, description: text }]
    when /\Agroup_(create|update)\.(.+)\z/
      action = Regexp.last_match(1)
      attribute = Regexp.last_match(2)
      args = action == "create" ? { name: "u4newwriters" } : { group_id: group.id }
      ["discourse_#{action}_group", args.merge(attribute => text)]
    when "membership.reason"
      ["discourse_manage_group_membership", { group_id: group.id, action: "request", reason: text }]
    when /\Aprofile\.(.+)\z/
      ["discourse_update_user", { :username => admin.username, Regexp.last_match(1) => text }]
    when /\Amoderation_(suspend|silence)\.(.+)\z/
      operation = Regexp.last_match(1)
      attribute = Regexp.last_match(2)
      [
        "discourse_#{operation}_user",
        {
          :username => recipient.username,
          :confirm => true,
          :duration_days => 1,
          :reason => "Garden discussion needs a pause",
          attribute => text,
        },
      ]
    when "draft.title", "draft.reply"
      [
        "discourse_save_draft",
        {
          :draft_key => Draft::NEW_TOPIC,
          :title => "A new seasonal discussion",
          :reply => McpContentWriteHelpers::PROSE,
          :category_id => allowed_category.id,
          field.split(".").last.to_sym => text,
        },
      ]
    when "status.description"
      ["discourse_user_status_set", { emoji: "seedling", description: text }]
    when "create_user.name", "create_user.custom_text", "create_user.custom_array"
      args = {
        username: "u4created",
        email: "u4created@example.com",
        name: "Garden writer",
        password: "verylongvalidpassword729!",
      }
      if field == "create_user.name"
        args[:name] = text
      else
        custom_field = Fabricate(:user_field, name: "Garden interests", field_type: "text")
        args[:user_fields] = { custom_field.id.to_s => field.end_with?("array") ? [text] : text }
      end
      ["discourse_create_user", args]
    else
      raise "Unclassified write field #{field}"
    end
  end

  fields = %w[
    topic.title
    topic.raw
    reply.raw
    edit.raw
    edit.edit_reason
    update_topic.title
    update_topic.featured_link
    pm.title
    pm.raw
    pm_reply.raw
    pm_invite.custom_message
    category_create.name
    category_update.name
    category_create.description
    category_update.description
    group_create.bio_raw
    group_update.bio_raw
    group_create.membership_request_template
    group_update.membership_request_template
    group_create.full_name
    group_update.full_name
    group_create.title
    group_update.title
    membership.reason
    profile.bio_raw
    profile.name
    profile.location
    profile.website
    profile.title
    moderation_suspend.message
    moderation_silence.message
    moderation_suspend.reason
    moderation_silence.reason
    draft.title
    draft.reply
    status.description
    create_user.name
    create_user.custom_text
    create_user.custom_array
  ]

  fields.each do |field|
    it "rejects authored internal references in #{field}, preserving the no-rule write" do
      text = "#{Discourse.base_url}/t/#{post.topic_id}"
      name, args = write_case(field, text)
      isolated { expect_success(rpc(name, args)) }
      activate!
      assert_reference_write(name, args)
    end
  end

  fields
    .reject do |field|
      field.start_with?("pm.", "pm_reply.", "pm_invite.", "membership.", "moderation_")
    end
    .each do |field|
      it "rejects authored #{field} references under a PM-only rule" do
        name, args = write_case(field, "#{Discourse.base_url}/t/#{post.topic_id}")
        isolated { expect_success(rpc(name, args)) }
        activate!(:pm)
        assert_reference_write(name, args)
      end
    end

  fields.each do |field|
    it "permits ordinary text in #{field} under an active rule" do
      text =
        (
          if %w[profile.website update_topic.featured_link].include?(field)
            ""
          else
            "Seasonal garden observations"
          end
        )
      name, args = write_case(field, text)
      isolated { expect_success(rpc(name, args)) }
      activate!
      expect_success(rpc(name, args))
    end
  end

  forms = {
    "same-site absolute topic" => -> do
      "[Read this](#{Discourse.base_url}/t/garden/#{post.topic_id})"
    end,
    "relative topic" => -> { "[Read this](/t/garden/#{post.topic_id})" },
    "protocol-relative topic" => -> do
      "[Read this](//#{Discourse.current_hostname}/t/garden/#{post.topic_id})"
    end,
    "post route" => -> { "[Read this](/p/#{post.id})" },
    "relative category" => -> { "[Read this](/c/gardens/#{allowed_category.id})" },
    "relative user" => -> { "[Read this](/u/#{recipient.username})" },
    "relative upload" => -> { "[Read this](/uploads/default/original/1X/#{"a" * 40}.png)" },
    "ungranted short upload" => -> { "![Garden](#{Fabricate(:upload, user: admin).short_url})" },
    "attributed quote" => -> do
      "[quote=\"#{admin.username}, post:1, topic:#{post.topic_id}\"]\nA seasonal thought.\n[/quote]"
    end,
    "quote topic without post" => -> do
      "[quote=\"#{admin.username}, topic:#{post.topic_id}\"]\nA seasonal thought.\n[/quote]"
    end,
    "resolved hashtag" => -> { "Please consider ##{allowed_category.slug} for this discussion." },
    "unresolved hashtag" => -> { "Please consider #u4unknownhashtag for this discussion." },
    "external bare onebox" => -> { "https://external.example/page" },
    "external inline onebox" => -> do
      "Please consult https://external.example/page for the details."
    end,
    "external autolink" => -> { "Please consult <https://external.example/page> for the details." },
    "scheme-less www link" => -> { "Please consult www.example.com/page for the details." },
    "scheme-less domain link" => -> { "Please consult example.com/page for the details." },
    "external markdown image" => -> { "![Garden](https://external.example/garden.png)" },
    "external html image" => -> { '<img src="https://external.example/garden.png">' },
    "external video source" => -> do
      '<video controls><source src="https://external.example/garden.mp4"></video>'
    end,
    "external audio source" => -> do
      '<audio controls><source src="https://external.example/garden.mp3"></audio>'
    end,
    "external source srcset" => -> do
      '<video controls><source srcset="https://external.example/garden.mp4 1x,https://external.example/other.mp4 2x"></video>'
    end,
    "external video poster" => -> do
      '<video controls poster="https://external.example/garden.png"></video>'
    end,
    "external track source" => -> do
      '<video controls><track src="https://external.example/garden.vtt"></video>'
    end,
    "html same-site anchor" => -> do
      "<a href=\"#{Discourse.base_url}/t/garden/#{post.topic_id}\">Read the discussion</a>"
    end,
    "onebox source attribute" => -> do
      '<aside class="onebox" data-onebox-src="https://external.example/page"><p>A garden discussion</p></aside>'
    end,
    "anchor inside quote" => -> { "[quote]\n[Read this](/t/garden/#{post.topic_id})\n[/quote]" },
  }

  forms.each do |label, raw_builder|
    it "rejects #{label} with the same generic answer and preserves its no-rule write" do
      raw = instance_exec(&raw_builder)
      marker =
        {
          "external source srcset" => "source[srcset]",
          "external video poster" => "video[poster]",
          "external track source" => "track[src]",
          "onebox source attribute" => "aside[data-onebox-src]",
          "quote topic without post" => "aside[data-topic]",
        }[
          label
        ]
      if marker
        cooked = PrettyText.cook(raw)
        expect(Nokogiri::HTML5.fragment(cooked).at_css(marker)).to be_present,
        "RENDERER CALIBRATION #{marker}: #{cooked}"
      end
      args = topic_arguments(raw: "Garden observations follow.\n\n#{raw}")
      isolated { expect_success(rpc("discourse_create_topic", args)) }
      activate!
      assert_reference_write("discourse_create_topic", args)
    end
  end

  %i[linkify_off oneboxes_zero both].each do |setting|
    %w[https://external.example/page www.example.com/page].each do |url|
      it "rejects #{url} when #{setting} despite future rebake settings" do
        SiteSetting.enable_markdown_linkify = false if %i[linkify_off both].include?(setting)
        SiteSetting.max_oneboxes_per_post = 0 if %i[oneboxes_zero both].include?(setting)
        args = topic_arguments(raw: "Garden observations follow.\n\n#{url}")
        isolated { expect_success(rpc("discourse_create_topic", args)) }
        activate!
        assert_reference_write("discourse_create_topic", args)
      end
    end
  end

  %i[pm forum].each do |kind|
    it "allows prose, labeled external links and non-link code under #{kind} rules" do
      values = [
        McpContentWriteHelpers::PROSE,
        McpContentWriteHelpers::LABELLED_LINK,
        "Version 1.2.3 and a filename garden.txt describe these plans.",
        "A literal `https://external.example/page` illustrates source code.",
      ]
      values.each do |raw|
        isolated { expect_success(rpc("discourse_create_topic", topic_arguments(raw: raw))) }
      end
      activate!(kind)
      values.each do |raw|
        isolated do
          data = expect_success(rpc("discourse_create_topic", topic_arguments(raw: raw)))
          expect(Post.find(data.fetch("id")).raw).to eq(raw)
        end
      end
    end
  end

  it "rejects references under a PM-only rule even when the target is a public topic" do
    args = topic_arguments(raw: "Please read [the garden discussion](/t/garden/#{post.topic_id}).")
    isolated { expect_success(rpc("discourse_create_topic", args)) }
    activate!(:pm)
    assert_reference_write("discourse_create_topic", args)
  end

  it "gives allowed, restricted and missing reference targets the identical generic refusal" do
    restricted = Fabricate(:post, topic: Fabricate(:topic, category: restricted_category))
    args =
      [post.topic_id, restricted.topic_id, McpContentWriteHelpers::MISSING_ID].map do |id|
        topic_arguments(raw: "Please read [the discussion](/t/garden/#{id}) before replying.")
      end
    args.each { |arguments| isolated { expect_success(rpc("discourse_create_topic", arguments)) } }
    activate!
    responses =
      args.map do |arguments|
        response = nil
        isolated { response = rpc("discourse_create_topic", arguments) }
        response
      end
    aggregate_failures do
      responses.each { |response| expect_reference_refusal(response) }
      expect(responses.uniq.size).to eq(1)
    end
  end

  %i[raw_html email].each do |cook_method|
    it "refuses edits to #{cook_method} posts while preserving the no-rule edit" do
      post.update_columns(cook_method: Post.cook_methods.fetch(cook_method))
      args = {
        post_id: post.id,
        raw: McpContentWriteHelpers::PROSE + " This is a revised observation.",
      }
      isolated { expect_success(rpc("discourse_update_post", args)) }
      activate!
      assert_reference_write("discourse_update_post", args)
    end
  end

  describe "with cooked mention and emoji markup" do
    %w[mention mention-group]
      .product(%i[allowed restricted missing])
      .each do |css_class, destination|
        it "refuses forged #{css_class} anchors to #{destination} internal destinations" do
          topic_id =
            case destination
            when :allowed
              post.topic_id
            when :restricted
              Fabricate(:topic, category: restricted_category).id
            else
              expect(Topic.exists?(id: 99_620_001)).to eq(false)
              99_620_001
            end
          href = "/t/garden/#{topic_id}"
          raw = "Please ask <a class=\"#{css_class}\" href=\"#{href}\">@#{recipient.username}</a>."
          args = topic_arguments(raw: raw)
          isolated do
            data = expect_success(rpc("discourse_create_topic", args))
            anchor =
              Nokogiri::HTML5.fragment(Post.find(data.fetch("id")).cooked).at_css("a.#{css_class}")
            expect(anchor["href"]).to eq(href)
          end
          activate!
          assert_reference_write("discourse_create_topic", args)
        end
      end

    it "refuses an external emoji-class image even with a site emoji path" do
      url = "https://external.example/images/emoji/twitter/seedling.png"
      args =
        topic_arguments(
          raw: "A garden <img class=\"emoji\" src=\"#{url}\" alt=\":seedling:\"> grows.",
        )
      isolated do
        data = expect_success(rpc("discourse_create_topic", args))
        expect(
          Nokogiri::HTML5.fragment(Post.find(data.fetch("id")).cooked).at_css("img.emoji")["src"],
        ).to eq(url)
      end
      activate!
      assert_reference_write("discourse_create_topic", args)
    end

    it "permits genuine user and group mentions and real site emoji" do
      group =
        Fabricate(
          :group,
          name: "u4reviewwriters",
          mentionable_level: Group::ALIAS_LEVELS[:everyone],
        )
      raw = "Please ask @#{recipient.username} and @#{group.name} about :seedling: gardens."
      args = topic_arguments(raw: raw)
      isolated { expect_success(rpc("discourse_create_topic", args)) }
      activate!
      data = expect_success(rpc("discourse_create_topic", args))
      written = Post.find(data.fetch("id"))
      fragment = Nokogiri::HTML5.fragment(written.cooked)
      expect(written.raw).to eq(raw)
      expect(fragment.at_css("a.mention")["href"]).to eq("/u/#{recipient.username.downcase}")
      expect(fragment.at_css("a.mention-group")["href"]).to eq("/groups/#{group.name}")
      expect(fragment.at_css("img.emoji")["src"]).to start_with("/images/emoji/")
    end

    %w[mention mention-group].each do |css_class|
      it "refuses #{css_class} names containing browser path traversal" do
        topic = Fabricate(:topic, id: 101_620_001, category: restricted_category)
        name = "../t/#{topic.id}"
        prefix = css_class == "mention" ? "u" : "groups"
        href = "/#{prefix}/#{name}"
        raw = "Please ask <a class=\"#{css_class}\" href=\"#{href}\">@#{name}</a>."
        args = topic_arguments(raw: raw)
        isolated do
          data = expect_success(rpc("discourse_create_topic", args))
          anchor = Nokogiri::HTML5.fragment(Post.find(data.fetch("id")).cooked).at_css("a")
          expect(anchor["href"]).to eq(href)
          expect(anchor.text).to eq("@#{name}")
          expect(URI.join(Discourse.base_url, href).normalize.path).to eq("/t/#{topic.id}")
        end
        activate!
        group =
          Fabricate(
            :group,
            name: "reviewtwogardeners",
            mentionable_level: Group::ALIAS_LEVELS[:everyone],
          )
        control_name = css_class == "mention" ? recipient.username : group.name
        control =
          topic_arguments(
            title: "Permitted seasonal garden mentions",
            raw: "Please ask @#{control_name} about seasonal gardens.",
          )
        data = expect_success(rpc("discourse_create_topic", control))
        anchor =
          Nokogiri::HTML5.fragment(Post.find(data.fetch("id")).cooked).at_css("a.#{css_class}")
        expect(anchor["href"]).to eq("/#{prefix}/#{control_name.downcase}")
        assert_reference_write("discourse_create_topic", args)
      end
    end

    %w[../.. %2e%2e/%2e%2e].each do |traversal|
      it "refuses emoji path traversal #{traversal}" do
        src = "/images/emoji/#{traversal}/uploads/review-two.png"
        args = topic_arguments(raw: "A garden <img class=\"emoji\" src=\"#{src}\"> grows.")
        isolated do
          data = expect_success(rpc("discourse_create_topic", args))
          expect(
            Nokogiri::HTML5.fragment(Post.find(data.fetch("id")).cooked).at_css("img")["src"],
          ).to eq(src)
          expect(URI.join(Discourse.base_url, CGI.unescape(src)).normalize.path).to eq(
            "/uploads/review-two.png",
          )
        end
        activate!
        data =
          expect_success(
            rpc(
              "discourse_create_topic",
              topic_arguments(
                title: "Permitted seasonal garden emoji",
                raw: "A :seedling: garden grows.",
              ),
            ),
          )
        expect(
          Nokogiri::HTML5.fragment(Post.find(data.fetch("id")).cooked).at_css("img.emoji")["src"],
        ).to start_with("/images/emoji/")
        assert_reference_write("discourse_create_topic", args)
      end
    end

    %i[internal cdn].each do |host|
      it "keeps rendered configured emoji on an overlapping #{host} host" do
        base = host == :internal ? Discourse.base_url : "https://review-two-cdn.example"
        set_cdn_url(base) if host == :cdn
        SiteSetting.external_emoji_url = "#{base}/custom-emoji"
        args = topic_arguments(raw: "A :seedling: garden grows through the seasons.")
        expected =
          "#{base}/custom-emoji/#{SiteSetting.emoji_set}/seedling.png?v=#{Emoji::EMOJI_VERSION}"
        isolated do
          data = expect_success(rpc("discourse_create_topic", args))
          expect(
            Nokogiri::HTML5.fragment(Post.find(data.fetch("id")).cooked).at_css("img.emoji")["src"],
          ).to eq(expected)
        end
        activate!
        data = expect_success(rpc("discourse_create_topic", args))
        expect(
          Nokogiri::HTML5.fragment(Post.find(data.fetch("id")).cooked).at_css("img.emoji")["src"],
        ).to eq(expected)
      end
    end
  end

  describe "with tag group display names" do
    %i[create update].each do |operation|
      it "refuses authored references in #{operation} tag-group display names under a PM-only rule" do
        group = Fabricate(:tag_group, name: "Plain review garden tags") if operation == :update
        args = { name: "#{Discourse.base_url}/t/garden/99620001" }
        args[:tag_group_id] = group.id if group
        name = "discourse_#{operation}_tag_group"
        isolated do
          data = expect_success(rpc(name, args))
          expect(TagGroup.find(data.fetch("tag_group").fetch("id")).name).to eq(args[:name])
        end
        activate!(:pm)
        state = content_state
        groups = TagGroup.order(:id).pluck(:id, :name)
        response = rpc(name, args)
        aggregate_failures do
          expect_reference_refusal(response)
          expect(content_state).to eq(state)
          expect(TagGroup.order(:id).pluck(:id, :name)).to eq(groups),
          "TAG GROUP ATOMICITY: refused display name persisted"
        end
      end

      it "permits a plain #{operation} tag-group display name under a PM-only rule" do
        group = Fabricate(:tag_group, name: "Original review garden tags") if operation == :update
        args = { name: "Plain review garden tags" }
        args[:tag_group_id] = group.id if group
        activate!(:pm)
        data = expect_success(rpc("discourse_#{operation}_tag_group", args))
        expect(TagGroup.find(data.fetch("tag_group").fetch("id")).name).to eq(args[:name])
      end
    end
  end

  describe "with labelled links to this site" do
    describe "when the host is spelled differently" do
      before { SiteSetting.unique_posts_mins = 0 }

      def persisted_state
        {
          posts: Post.with_deleted.order(:id).pluck(:id, :topic_id, :raw, :cooked, :deleted_at),
          topics: Topic.with_deleted.order(:id).pluck(:id, :title, :category_id, :deleted_at),
          topic_tags: TopicTag.order(:topic_id, :tag_id).pluck(:topic_id, :tag_id),
          tags: Tag.order(:id).pluck(:id, :name),
          reviewables: Reviewable.order(:id).pluck(:id, :status, :topic_id, :target_id, :payload),
        }
      end

      %i[percent_encoded trailing_dot uppercase unicode_site punycode_site].each do |shape|
        it "refuses a labelled #{shape} host link to this site without persisting content" do
          host =
            case shape
            when :unicode_site
              "bücher.example"
            when :punycode_site
              "xn--bcher-kva.example"
            else
              "review-four-site.example"
            end
          Discourse.stubs(:current_hostname).returns(
            shape == :unicode_site ? "review-four-site.example" : host,
          )
          Discourse.stubs(:base_url).returns("https://#{host}")
          destination = Fabricate(:topic, id: 112_840_101, category: restricted_category)
          link_host =
            case shape
            when :percent_encoded
              "review-four-s%69te.example"
            when :trailing_dot
              "#{host}."
            when :uppercase
              host.upcase
            when :unicode_site
              "xn--bcher-kva.example"
            else
              "bücher.example"
            end
          href = "https://#{link_host}/t/secret/#{destination.id}"
          args = topic_arguments(raw: "Read [garden notes](#{href}) for seasonal observations.")
          isolated do
            data = expect_success(rpc("discourse_create_topic", args))
            anchor = Nokogiri::HTML5.fragment(Post.find(data.fetch("id")).cooked).at_css("a")
            expect(anchor.text).to eq("garden notes")
            expected_host = shape == :punycode_site ? host : link_host
            expect(anchor["href"]).to eq("https://#{expected_host}/t/secret/#{destination.id}")
          end
          activate!
          control =
            expect_success(
              rpc(
                "discourse_create_topic",
                topic_arguments(
                  title: "Permitted review four external garden references",
                  raw: McpContentWriteHelpers::LABELLED_LINK,
                ),
              ),
            )
          expect(Post.find(control.fetch("id")).raw).to eq(McpContentWriteHelpers::LABELLED_LINK)
          expected = reference_error
          before_state = persisted_state
          response = rpc("discourse_create_topic", args)
          aggregate_failures do
            expect_refusal(response)
            expect(response).to eq(expected), "INTERNAL HOST: labelled link was accepted"
            expect(persisted_state).to eq(before_state),
            "INTERNAL HOST ATOMICITY: linked content persisted"
          end
        end
      end
    end

    describe "with Unicode full stops and invisible host characters" do
      before do
        SiteSetting.unique_posts_mins = 0
        Discourse.stubs(:current_hostname).returns("review-five-site.example")
        Discourse.stubs(:base_url).returns("https://review-five-site.example")
      end

      {
        ideographic_full_stop: "review-five-site\u3002example",
        fullwidth_full_stop: "review-five-site\uFF0Eexample",
        halfwidth_ideographic_full_stop: "review-five-site\uFF61example",
        percent_encoded_ideographic_full_stop: "review-five-site%E3%80%82example",
        percent_encoded_fullwidth_full_stop: "review-five-site%EF%BC%8Eexample",
        percent_encoded_halfwidth_ideographic_full_stop: "review-five-site%EF%BD%A1example",
        percent_encoded_zero_width_space: "review-five-s%E2%80%8Bite.example",
        percent_encoded_soft_hyphen: "review-five-s%C2%ADite.example",
      }.each do |shape, link_host|
        %i[forum pm].each do |rule|
          it "refuses a labelled #{shape} internal host under #{rule} without persisting content" do
            destination = Fabricate(:topic, id: 112_850_001, category: restricted_category)
            href = "https://#{link_host}/t/secret/#{destination.id}"
            raw = "Read [garden notes](#{href}) for seasonal observations."
            args = topic_arguments(raw:)
            isolated do
              data = expect_success(rpc("discourse_create_topic", args))
              written = Post.find(data.fetch("id"))
              anchor = Nokogiri::HTML5.fragment(written.cooked).at_css("a")
              expect(written.raw).to eq(raw)
              expect(anchor.text).to eq("garden notes")
              expect(anchor["href"]).to include("/t/secret/#{destination.id}")
              expect(anchor["href"]).to eq(href) if link_host.include?("%")
            end

            activate!(rule)
            expected = reference_error
            before_state = content_state
            response = rpc("discourse_create_topic", args)
            aggregate_failures do
              expect_reference_refusal(response)
              expect(response).to eq(expected), "BROWSER HOST: labelled #{shape} link was accepted"
              expect(content_state).to eq(before_state),
              "BROWSER HOST ATOMICITY: labelled #{shape} link persisted content"
            end
          end
        end
      end

      %i[forum pm].each do |rule|
        it "accepts a labelled external ASCII host under #{rule}" do
          activate!(rule)
          raw = McpContentWriteHelpers::LABELLED_LINK
          data = expect_success(rpc("discourse_create_topic", topic_arguments(raw:)))
          written = Post.find(data.fetch("id"))
          anchor = Nokogiri::HTML5.fragment(written.cooked).at_css("a")
          expect(written.raw).to eq(raw)
          expect(anchor["href"]).to eq("https://external.example/page")
        end
      end
    end

    describe "with IP and IDNA host notations" do
      before { SiteSetting.unique_posts_mins = 0 }

      {
        percent_encoded_capital_sharp_s: %w[xn--fa-hia.example fa%E1%BA%9E.example],
        unicode_sharp_s: ["xn--fa-hia.example", "fa\u00DF.example"],
        ipv4_short_dotted: %w[127.0.0.1 127.1],
        ipv4_decimal_integer: %w[127.0.0.1 2130706433],
        ipv4_hex_integer: %w[127.0.0.1 0x7f000001],
        ipv4_octal_dotted: %w[127.0.0.1 0177.0.0.1],
        ipv4_leading_zero_dotted: %w[127.0.0.1 127.000.000.001],
        ipv4_octal_integer: %w[127.0.0.1 017700000001],
        canonical_punycode: %w[xn--fa-hia.example xn--fa-hia.example],
        canonical_ipv4: %w[127.0.0.1 127.0.0.1],
      }.each do |shape, (site_host, link_host)|
        %i[forum pm].each do |rule|
          it "refuses a labelled #{shape} internal host under #{rule} without persisting content" do
            Discourse.stubs(:current_hostname).returns(site_host)
            Discourse.stubs(:base_url).returns("https://#{site_host}")
            destination = Fabricate(:topic, id: 112_860_001, category: restricted_category)
            href = "https://#{link_host}/t/secret/#{destination.id}"
            raw = "Read [garden notes](#{href}) for seasonal observations."
            args = topic_arguments(raw:)
            isolated do
              data = expect_success(rpc("discourse_create_topic", args))
              written = Post.find(data.fetch("id"))
              anchor = Nokogiri::HTML5.fragment(written.cooked).at_css("a")
              expect(written.raw).to eq(raw)
              expect(anchor.text).to eq("garden notes")
              expect(anchor["href"]).to include("/t/secret/#{destination.id}")
              expected_href = link_host.ascii_only? ? href : href.sub(link_host, site_host)
              expect(anchor["href"]).to eq(expected_href)
            end

            activate!(rule)
            expected = reference_error
            before_state = content_state
            response = rpc("discourse_create_topic", args)
            aggregate_failures do
              expect_reference_refusal(response)
              expect(response).to eq(expected), "BROWSER HOST: labelled #{shape} link was accepted"
              expect(content_state).to eq(before_state),
              "BROWSER HOST ATOMICITY: labelled #{shape} link persisted content"
            end
          end
        end
      end

      {
        ipv6_with_userinfo: "https://visitor:password@[2001:db8::6]/page",
        ipv6_with_userinfo_and_port: "https://visitor:password@[2001:db8::6]:8443/page",
        ascii_host: "https://external.example/page",
        canonical_ipv4: "https://192.0.2.6/page",
      }.each do |shape, href|
        %i[forum pm].each do |rule|
          it "accepts a labelled external #{shape} under #{rule}" do
            Discourse.stubs(:current_hostname).returns("127.0.0.1")
            Discourse.stubs(:base_url).returns("https://127.0.0.1")
            raw = "Read [garden notes](#{href}) for seasonal observations."
            args = topic_arguments(raw:)
            isolated do
              data = expect_success(rpc("discourse_create_topic", args))
              anchor = Nokogiri::HTML5.fragment(Post.find(data.fetch("id")).cooked).at_css("a")
              expect(anchor.text).to eq("garden notes")
              expect(anchor["href"]).to eq(href)
            end

            activate!(rule)
            data = expect_success(rpc("discourse_create_topic", args))
            written = Post.find(data.fetch("id"))
            anchor = Nokogiri::HTML5.fragment(written.cooked).at_css("a")
            expect(written.raw).to eq(raw)
            expect(anchor.text).to eq("garden notes")
            expect(anchor["href"]).to eq(href)
          end
        end
      end
    end

    describe "with an invalid UTF-8 host" do
      %i[forum pm].each do |kind|
        it "refuses a labelled invalid UTF-8 decoded host under #{kind} with the normal reference refusal" do
          href = "https://visitor@%FF.example/page"
          raw = "Read [garden notes](#{href}) for seasonal observations."
          args = topic_arguments(raw:)
          isolated do
            data = expect_success(rpc("discourse_create_topic", args))
            written = Post.find(data.fetch("id"))
            expect(written.raw).to eq(raw)
            anchor = Nokogiri::HTML5.fragment(written.cooked).at_css("a")
            expect(anchor["href"]).to eq(href)
          end

          activate!(kind)
          expected = reference_error
          before_state = content_state
          response = rpc("discourse_create_topic", args)
          aggregate_failures do
            expect(response).to eq(expected),
            "INVALID UTF-8 HOST: expected the normal reference refusal, not an internal error"
            expect(content_state).to eq(before_state)
          end
        end
      end
    end
  end
end

# rubocop:enable Discourse/NoIterationOverRSpecDefinitions
