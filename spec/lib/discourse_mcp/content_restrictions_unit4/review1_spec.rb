# frozen_string_literal: true

require_relative "support"

# Each variant needs its own failing receipt and unrestricted calibration.
# rubocop:disable Discourse/NoIterationOverRSpecDefinitions

describe DiscourseMcp::Server, "#call" do
  include_context "with unit four MCP writes"

  def review_upload
    data =
      expect_success(
        rpc(
          "discourse_upload_file",
          {
            upload_type: "composer",
            filename: "review-one-garden.png",
            image_data: Base64.strict_encode64(file_from_fixtures("logo.png").read),
          },
        ),
      )
    Upload.find(data.fetch("id"))
  end

  def queued_topic(payload = {}, **attributes)
    Fabricate(
      :reviewable_queued_post_topic,
      category: allowed_category,
      target_created_by: recipient,
      payload: {
        raw: McpContentRestrictionsUnit4::PROSE,
        title: "Queued observations about seasonal gardens",
        tags: [],
        archetype: "regular",
      }.merge(payload),
      **attributes,
    )
  end

  def approve_arguments(reviewable, action = "approve_post")
    { reviewable_id: reviewable.id, action_id: action, confirm: true }
  end

  %w[mention mention-group]
    .product(%i[allowed restricted missing])
    .each do |css_class, destination|
      it "[cr-u4] refuses forged #{css_class} anchors to #{destination} internal destinations" do
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

  %i[video blocked_src blocked_srcset].each do |carrier|
    it "[cr-u4] refuses ungranted media carried by #{carrier} attributes before a later rebake" do
      url = "https://external.example/review-one.mp4"
      SiteSetting.block_hotlinked_media = carrier != :video
      raw, selector, attribute, value =
        case carrier
        when :video
          [
            "<div class=\"video-placeholder-container\" data-video-src=\"#{url}\"></div>",
            "div[data-video-src]",
            "data-video-src",
            url,
          ]
        when :blocked_src
          [
            "<img src=\"#{url}\">",
            "img[data-blocked-hotlinked-src]",
            "data-blocked-hotlinked-src",
            url,
          ]
        else
          srcset = "#{review_upload.url} 1x,#{url} 2x"
          [
            "<video controls><source srcset=\"#{srcset}\"></video>",
            "source[data-blocked-hotlinked-srcset]",
            "data-blocked-hotlinked-srcset",
            srcset,
          ]
        end
      args = topic_arguments(raw: "A seasonal illustration follows.\n\n#{raw}")
      isolated do
        data = expect_success(rpc("discourse_create_topic", args))
        written = Post.find(data.fetch("id"))
        expect(Nokogiri::HTML5.fragment(written.cooked).at_css(selector)[attribute]).to eq(value)
        if carrier != :video
          SiteSetting.block_hotlinked_media = false
          written.rebake!
          exposed = carrier == :blocked_src ? "img[src]" : "source[srcset]"
          source_attribute = carrier == :blocked_src ? "src" : "srcset"
          expect(
            Nokogiri::HTML5.fragment(written.reload.cooked).at_css(exposed)[source_attribute],
          ).to eq(value)
        end
      end
      SiteSetting.block_hotlinked_media = carrier != :video
      activate!
      assert_reference_write("discourse_create_topic", args)
    end
  end

  it "[cr-u4] refuses an external emoji-class image even with a site emoji path" do
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

  %i[external ungranted_upload].each do |source|
    it "[cr-u4] refuses a granted data-orig-src decoy hiding an #{source} real source" do
      upload = review_upload
      real_src =
        (
          if source == :external
            "https://external.example/garden.png"
          else
            Fabricate(:upload, user: recipient).url
          end
        )
      raw = "A garden <img src=\"#{real_src}\" data-orig-src=\"#{upload.short_url}\"> grows."
      args = topic_arguments(raw: raw)
      isolated do
        data = expect_success(rpc("discourse_create_topic", args))
        image = Nokogiri::HTML5.fragment(Post.find(data.fetch("id")).cooked).at_css("img")
        expect(image["src"]).to eq(real_src)
        expect(image["data-orig-src"]).to eq(upload.short_url)
      end
      activate!
      assert_reference_write("discourse_create_topic", args)
    end
  end

  it "[cr-u4] permits genuine user and group mentions and real site emoji" do
    group =
      Fabricate(:group, name: "u4reviewwriters", mentionable_level: Group::ALIAS_LEVELS[:everyone])
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

  it "[cr-u4] permits granted upload images and renderer placeholders through repeated MCP writes" do
    activate!
    upload = review_upload
    image = "An illustration follows.\n\n![Garden](#{upload.short_url})"
    placeholder =
      "A garden <img src=\"/images/transparent.png\" data-orig-src=\"#{upload.short_url}\"> grows."
    [image, placeholder, image].each do |raw|
      data = expect_success(rpc("discourse_create_post", { topic_id: post.topic_id, raw: raw }))
      written = Post.find(data.fetch("id"))
      expect(written.raw).to eq(raw)
      expected_src = raw == placeholder ? "/images/transparent.png" : upload.url
      expect(Nokogiri::HTML5.fragment(written.cooked).at_css("img")["src"]).to eq(expected_src)
      expect(UploadReference.exists?(upload: upload, target: written)).to eq(true)
    end
  end

  it "[cr-u4] checks stored raw before approve_post_closed publishes a queued reply" do
    post.topic.update!(closed: true)
    raw = "Please read [the earlier discussion](/t/garden/99620001) before replying."
    reviewable = queued_topic({ raw: raw }, topic: post.topic)
    args = approve_arguments(reviewable, "approve_post_closed")
    isolated do
      expect_success(rpc("discourse_perform_reviewable_action", args))
      expect(reviewable.reload.status).to eq("approved")
      expect(reviewable.target.raw).to eq(raw)
      expect(reviewable.target.topic_id).to eq(post.topic_id)
    end
    activate!
    assert_reference_write("discourse_perform_reviewable_action", args)
  end

  it "[cr-u4] permits approve_post_closed with ordinary stored prose" do
    post.topic.update!(closed: true)
    reviewable = queued_topic({}, topic: post.topic)
    activate!
    expect_success(
      rpc(
        "discourse_perform_reviewable_action",
        approve_arguments(reviewable, "approve_post_closed"),
      ),
    )
    expect(reviewable.reload.status).to eq("approved")
    expect(reviewable.target.raw).to eq(McpContentRestrictionsUnit4::PROSE)
    expect(reviewable.target.topic_id).to eq(post.topic_id)
  end

  it "[cr-u4] refuses a new PM whose watched words add a denied tag" do
    SiteSetting.pm_tags_allowed_for_groups = Group::AUTO_GROUPS[:everyone].to_s
    Fabricate(
      :watched_word,
      action: WatchedWord.actions[:tag],
      word: "u4reviewgarden",
      replacement: denied_tag.name,
    )
    args = {
      title: "An exchange about seasonal gardens",
      raw: "These are u4reviewgarden observations about changing seasons.",
      usernames: [recipient.username],
    }
    isolated do
      data = expect_success(rpc("discourse_create_private_message", args))
      topic = Topic.find(data.fetch("topic_id"))
      expect(topic.private_message?).to eq(true)
      expect(topic.tags).to include(denied_tag)
    end
    activate!
    assert_reference_write("discourse_create_private_message", args)
  end

  %i[payload_category hash_tags parent watched_word].each do |restriction|
    it "[cr-u4] refuses queued topic approval made restricted by #{restriction}" do
      payload = {}
      attributes = {}
      case restriction
      when :payload_category
        payload[:category] = restricted_category.id
        attributes[:category] = nil
      when :hash_tags
        payload[:tags] = [{ "name" => denied_tag.name }]
      when :parent
        child = Fabricate(:tag, name: "u4-review-child")
        Fabricate(:tag_group, parent_tag_id: denied_tag.id, tags: [child])
        payload[:tags] = [child.name]
      else
        Fabricate(
          :watched_word,
          action: WatchedWord.actions[:tag],
          word: "u4reviewgarden",
          replacement: denied_tag.name,
        )
        payload[:raw] = "These are u4reviewgarden observations about changing seasons."
      end
      reviewable = queued_topic(payload, **attributes)
      args = approve_arguments(reviewable)
      isolated do
        expect_success(rpc("discourse_perform_reviewable_action", args))
        expect(reviewable.reload.status).to eq("approved")
        topic = reviewable.target.topic
        if restriction == :payload_category
          expect(topic.category_id).to eq(restricted_category.id)
        else
          expect(topic.tags).to include(denied_tag)
        end
      end
      activate!
      assert_reference_write("discourse_perform_reviewable_action", args)
    end
  end

  it "[cr-u4] permits a PM and queued new topic whose effective tags stay allowed" do
    allowed_tag = Fabricate(:tag, name: "u4-review-flowers")
    child = Fabricate(:tag, name: "u4-review-flower-child")
    Fabricate(:tag_group, parent_tag_id: allowed_tag.id, tags: [child])
    Fabricate(
      :watched_word,
      action: WatchedWord.actions[:tag],
      word: "u4reviewgarden",
      replacement: child.name,
    )
    SiteSetting.pm_tags_allowed_for_groups = Group::AUTO_GROUPS[:everyone].to_s
    raw = "These are u4reviewgarden observations about changing seasons."
    reviewable = queued_topic({ raw: raw })
    activate!
    data =
      expect_success(
        rpc(
          "discourse_create_private_message",
          {
            title: "An exchange about seasonal gardens",
            raw: raw,
            usernames: [recipient.username],
          },
        ),
      )
    message = Topic.find(data.fetch("topic_id"))
    expect(message.private_message?).to eq(true)
    expect(message.tags).to contain_exactly(child, allowed_tag)
    expect_success(rpc("discourse_perform_reviewable_action", approve_arguments(reviewable)))
    expect(reviewable.reload.status).to eq("approved")
    expect(reviewable.target.topic.category_id).to eq(allowed_category.id)
    expect(reviewable.target.topic.tags).to contain_exactly(child, allowed_tag)
  end

  %i[different_user same_user].each do |author|
    it "[cr-u4] revokes a grant after a synchronous #{author} callback writes an unrelated reference" do
      activate!
      upload = review_upload
      raw = "An agent illustration follows.\n\n![Garden](#{upload.short_url})"
      human = author == :same_user ? admin : recipient
      human_post = nil
      callback =
        lambda do |created_post, _options, _user|
          if created_post.raw == raw
            human_post =
              PostCreator.create!(
                human,
                topic_id: post.topic_id,
                raw: "A separate human illustration.\n\n![Garden](#{upload.short_url})",
                skip_events: true,
              )
          end
        end
      begin
        DiscourseEvent.on(:post_created, &callback)
        data = expect_success(rpc("discourse_create_post", { topic_id: post.topic_id, raw: raw }))
      ensure
        DiscourseEvent.off(:post_created, &callback)
      end
      expect(human_post).to be_present
      expect(human_post.user_id).to eq(human.id)
      expect(human_post.id).not_to eq(data.fetch("id"))
      expect(
        UploadReference.where(upload: upload, target_type: "Post").pluck(:target_id),
      ).to contain_exactly(data.fetch("id"), human_post.id)
      args = topic_arguments(raw: raw)
      isolated do
        McpContentRule.delete_all
        expect_success(rpc("discourse_create_topic", args))
      end
      assert_reference_write("discourse_create_topic", args)
    end
  end

  %i[create update].each do |operation|
    it "[cr-u4] refuses authored references in #{operation} tag-group display names under a PM-only rule" do
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

    it "[cr-u4] permits a plain #{operation} tag-group display name under a PM-only rule" do
      group = Fabricate(:tag_group, name: "Original review garden tags") if operation == :update
      args = { name: "Plain review garden tags" }
      args[:tag_group_id] = group.id if group
      activate!(:pm)
      data = expect_success(rpc("discourse_#{operation}_tag_group", args))
      expect(TagGroup.find(data.fetch("tag_group").fetch("id")).name).to eq(args[:name])
    end
  end
end

# rubocop:enable Discourse/NoIterationOverRSpecDefinitions
