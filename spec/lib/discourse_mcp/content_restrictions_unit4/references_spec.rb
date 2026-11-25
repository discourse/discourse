# frozen_string_literal: true

require_relative "support"

# Each matrix cell needs an independent baseline receipt.
# rubocop:disable Discourse/NoIterationOverRSpecDefinitions

describe DiscourseMcp::Server, "#call" do
  include_context "with unit four MCP writes"

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
          :raw => McpContentRestrictionsUnit4::PROSE + " More observations follow.",
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
          :raw => McpContentRestrictionsUnit4::PROSE,
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
          :reply => McpContentRestrictionsUnit4::PROSE,
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
    it "[cr-u4] rejects authored internal references in #{field}, preserving the no-rule write" do
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
      it "[cr-u4] rejects authored #{field} references under a PM-only rule" do
        name, args = write_case(field, "#{Discourse.base_url}/t/#{post.topic_id}")
        isolated { expect_success(rpc(name, args)) }
        activate!(:pm)
        assert_reference_write(name, args)
      end
    end

  fields.each do |field|
    it "[cr-u4] permits ordinary text in #{field} under an active rule" do
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
    it "[cr-u4] rejects #{label} with the same generic answer and preserves its no-rule write" do
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
      it "[cr-u4] rejects #{url} when #{setting} despite future rebake settings" do
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
    it "[cr-u4] allows prose, labeled external links and non-link code under #{kind} rules" do
      values = [
        McpContentRestrictionsUnit4::PROSE,
        McpContentRestrictionsUnit4::LABELLED_LINK,
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

  it "[cr-u4] rejects references under a PM-only rule even when the target is a public topic" do
    args = topic_arguments(raw: "Please read [the garden discussion](/t/garden/#{post.topic_id}).")
    isolated { expect_success(rpc("discourse_create_topic", args)) }
    activate!(:pm)
    assert_reference_write("discourse_create_topic", args)
  end

  it "[cr-u4] gives allowed, restricted and missing reference targets the identical generic refusal" do
    restricted = Fabricate(:post, topic: Fabricate(:topic, category: restricted_category))
    args =
      [post.topic_id, restricted.topic_id, McpContentRestrictionsUnit4::MISSING_ID].map do |id|
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
    it "[cr-u4] refuses edits to #{cook_method} posts while preserving the no-rule edit" do
      post.update_columns(cook_method: Post.cook_methods.fetch(cook_method))
      args = {
        post_id: post.id,
        raw: McpContentRestrictionsUnit4::PROSE + " This is a revised observation.",
      }
      isolated { expect_success(rpc("discourse_update_post", args)) }
      activate!
      assert_reference_write("discourse_update_post", args)
    end
  end
end

# rubocop:enable Discourse/NoIterationOverRSpecDefinitions
