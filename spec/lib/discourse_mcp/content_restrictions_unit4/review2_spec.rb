# frozen_string_literal: true

require_relative "support"

# rubocop:disable Discourse/NoIterationOverRSpecDefinitions

describe DiscourseMcp::Server, "#call" do
  include_context "with unit four MCP writes"

  def review2_upload
    data =
      expect_success(
        rpc(
          "discourse_upload_file",
          {
            upload_type: "composer",
            filename: "review-two-garden.txt",
            image_data: Base64.strict_encode64("Seasonal garden attachment"),
          },
        ),
      )
    Upload.find(data.fetch("id"))
  end

  def review2_queued_topic(tags)
    Fabricate(
      :reviewable_queued_post_topic,
      category: allowed_category,
      target_created_by: admin,
      payload: {
        raw: McpContentRestrictionsUnit4::PROSE,
        title: "Queued observations about seasonal gardens",
        tags: tags,
        archetype: "regular",
      },
    )
  end

  def review2_approve(reviewable)
    rpc(
      "discourse_perform_reviewable_action",
      { reviewable_id: reviewable.id, action_id: "approve_post", confirm: true },
    )
  end

  %w[mention mention-group].each do |css_class|
    it "[cr-u4] refuses #{css_class} names containing browser path traversal" do
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
      anchor = Nokogiri::HTML5.fragment(Post.find(data.fetch("id")).cooked).at_css("a.#{css_class}")
      expect(anchor["href"]).to eq("/#{prefix}/#{control_name.downcase}")
      assert_reference_write("discourse_create_topic", args)
    end
  end

  %w[../.. %2e%2e/%2e%2e].each do |traversal|
    it "[cr-u4] refuses emoji path traversal #{traversal}" do
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
    it "[cr-u4] keeps rendered configured emoji on an overlapping #{host} host" do
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

  it "[cr-u4] keeps genuine granted attachments rendered from upload short URLs" do
    activate!
    upload = review2_upload
    raw = "Please read [garden notes|attachment](#{upload.short_url})."
    args = { topic_id: post.topic_id, raw: raw }
    isolated do
      McpContentRule.delete_all
      data = expect_success(rpc("discourse_create_post", args))
      anchor = Nokogiri::HTML5.fragment(Post.find(data.fetch("id")).cooked).at_css("a.attachment")
      expect(anchor["href"]).to eq(upload.short_path)
      expect(Upload.sha1_from_short_path(anchor["href"])).to eq(upload.sha1)
    end
    data = expect_success(rpc("discourse_create_post", args))
    anchor = Nokogiri::HTML5.fragment(Post.find(data.fetch("id")).cooked).at_css("a.attachment")
    expect(anchor["href"]).to eq(upload.short_path)
  end

  %i[topic other_upload].each do |destination|
    it "[cr-u4] refuses a granted attachment decoy whose href names #{destination}" do
      activate!
      upload = review2_upload
      genuine = "Please read [garden notes|attachment](#{upload.url})."
      data = expect_success(rpc("discourse_create_post", { topic_id: post.topic_id, raw: genuine }))
      anchor = Nokogiri::HTML5.fragment(Post.find(data.fetch("id")).cooked).at_css("a.attachment")
      expect(anchor["href"]).to eq(upload.url)
      expect(anchor["data-orig-href"]).to be_nil
      href = destination == :topic ? "/t/#{post.topic_id}" : Fabricate(:upload, user: recipient).url
      raw =
        "Please read <a class=\"attachment\" href=\"#{href}\" data-orig-href=\"#{upload.short_url}\">garden notes</a>."
      args = topic_arguments(raw: raw)
      isolated do
        McpContentRule.delete_all
        data = expect_success(rpc("discourse_create_topic", args))
        anchor = Nokogiri::HTML5.fragment(Post.find(data.fetch("id")).cooked).at_css("a.attachment")
        expect(anchor["href"]).to eq(href)
        expect(anchor["data-orig-href"]).to eq(upload.short_url)
      end
      assert_reference_write("discourse_create_topic", args)
    end
  end

  %i[case whitespace truncation].each do |shape|
    it "[cr-u4] judges #{shape} tag names by the tags saving stores and answers like a missing category" do
      SiteSetting.max_tag_length = 60
      long = Fabricate(:tag, name: "reviewtwogardenextended")
      limit = shape == :truncation ? 8 : 15
      denied_tag.update!(name: long.name.first(limit))
      SiteSetting.max_tag_length = limit
      name = shape == :whitespace ? " #{long.name} " : long.name.upcase
      args = topic_arguments(tags: [name])
      isolated do
        data = expect_success(rpc("discourse_create_topic", args))
        stored = Post.find(data.fetch("id")).topic.tags
        expected = shape == :whitespace ? [denied_tag] : [long, denied_tag]
        expect(stored).to match_array(expected)
      end
      activate!
      missing_response = nil
      isolated do
        missing_response =
          rpc(
            "discourse_create_topic",
            args.except(:tags).merge(category_id: McpContentRestrictionsUnit4::MISSING_ID),
          )
        expect_refusal(missing_response)
      end
      before_state = content_state
      response = rpc("discourse_create_topic", args)
      aggregate_failures do
        expect_refusal(response)
        expect(response).to eq(missing_response),
        "PROSPECTIVE TAGS: effective denied tags must answer like a missing category"
        expect(content_state).to eq(before_state),
        "WRITE ATOMICITY: refused reference persisted content"
      end
    end
  end

  %i[without_id with_id].each do |shape|
    it "[cr-u4] judges queued hash tags #{shape} by saving and keeps allowed hash tags" do
      SiteSetting.max_tag_length = 60
      long = Fabricate(:tag, name: "reviewtwoqueuedextended")
      allowed = Fabricate(:tag, name: "review-two-allowed")
      denied_tag.update!(name: long.name.first(12))
      SiteSetting.max_tag_length = 12
      entry = { "name" => long.name.upcase }
      entry["id"] = long.id if shape == :with_id
      reviewable = review2_queued_topic([entry])
      isolated do
        expect_success(review2_approve(reviewable))
        expect(reviewable.reload.target.topic.tags).to contain_exactly(long, denied_tag)
      end
      reviewable.reload
      activate!
      allowed_entry = { "name" => allowed.name }
      allowed_entry["id"] = allowed.id if shape == :with_id
      control = review2_queued_topic([allowed_entry])
      expect_success(review2_approve(control))
      expect(control.reload.status).to eq("approved")
      expect(control.target.topic.tags).to contain_exactly(allowed)
      assert_reference_write(
        "discourse_perform_reviewable_action",
        { reviewable_id: reviewable.id, action_id: "approve_post", confirm: true },
      )
    end
  end
end

# rubocop:enable Discourse/NoIterationOverRSpecDefinitions
