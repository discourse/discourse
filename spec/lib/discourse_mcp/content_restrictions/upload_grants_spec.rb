# frozen_string_literal: true

require_relative "write_support"

# Each variant is calibrated against its own unrestricted baseline.
# rubocop:disable Discourse/NoIterationOverRSpecDefinitions

describe DiscourseMcp::Server, "#call" do
  include_context "with MCP content write rules"

  def upload_arguments
    {
      upload_type: "composer",
      filename: "unit-four-garden.png",
      image_data: Base64.strict_encode64(file_from_fixtures("logo.png").read),
    }
  end

  def upload_through_mcp(access_token: token)
    data =
      expect_success(rpc("discourse_upload_file", upload_arguments, access_token: access_token))
    Upload.find(data.fetch("id"))
  end

  def upload_text(upload)
    "A seasonal illustration follows.\n\n![Garden](#{upload.short_url})"
  end

  it "permits a fresh authorization upload and repeated references from its own written posts" do
    isolated do
      upload = upload_through_mcp
      expect_success(rpc("discourse_create_topic", topic_arguments(raw: upload_text(upload))))
    end
    activate!
    upload = upload_through_mcp
    first = expect_success(rpc("discourse_create_topic", topic_arguments(raw: upload_text(upload))))
    second =
      expect_success(
        rpc("discourse_create_post", { topic_id: post.topic_id, raw: upload_text(upload) }),
      )
    expect(Post.find(first.fetch("id")).raw).to include(upload.short_url)
    expect(Post.find(second.fetch("id")).raw).to include(upload.short_url)
    expect(
      UploadReference.where(upload: upload, target_type: "Post").pluck(:target_id),
    ).to contain_exactly(first.fetch("id"), second.fetch("id"))
  end

  it "preserves an upload grant across access tokens for the same authorization" do
    raw_token = McpOauthAccessToken.issue!(authorization: token.authorization)
    renewed = McpOauthAccessToken.find_by!(token_hash: McpOauthAccessToken.digest(raw_token))
    isolated do
      upload = upload_through_mcp
      expect_success(
        rpc(
          "discourse_create_topic",
          topic_arguments(raw: upload_text(upload)),
          access_token: renewed,
        ),
      )
    end
    activate!
    upload = upload_through_mcp
    data =
      expect_success(
        rpc(
          "discourse_create_topic",
          topic_arguments(raw: upload_text(upload)),
          access_token: renewed,
        ),
      )
    expect(Post.find(data.fetch("id")).raw).to include(upload.short_url)
  end

  it "refuses another authorization's fresh active-rule upload even for the same user" do
    other_token = issue_token
    isolated do
      upload = upload_through_mcp(access_token: other_token)
      expect_success(rpc("discourse_create_topic", topic_arguments(raw: upload_text(upload))))
    end
    activate!
    upload = upload_through_mcp(access_token: other_token)
    assert_reference_write("discourse_create_topic", topic_arguments(raw: upload_text(upload)))
  end

  %i[outside_mcp other_authorization another_user].each do |origin|
    it "refuses text referencing #{origin} upload, preserving no-rule use" do
      upload =
        case origin
        when :outside_mcp
          Fabricate(:upload, user: admin)
        when :other_authorization
          upload_through_mcp(access_token: issue_token)
        else
          Fabricate(:upload, user: recipient)
        end
      args = topic_arguments(raw: upload_text(upload))
      isolated { expect_success(rpc("discourse_create_topic", args)) }
      activate!
      assert_reference_write("discourse_create_topic", args)
    end
  end

  %w[upload_id profile_background_upload_url card_background_upload_url].each do |field|
    it "accepts this authorization's granted #{field}, preserving no-rule use" do
      isolated do
        upload = upload_through_mcp
        value = field == "upload_id" ? upload.id : upload.url
        expect_success(
          rpc("discourse_update_user", { :username => admin.username, field => value }),
        )
      end
      activate!
      upload = upload_through_mcp
      value = field == "upload_id" ? upload.id : upload.url
      data =
        expect_success(
          rpc("discourse_update_user", { :username => admin.username, field => value }),
        )
      expect(data.fetch("success")).to eq(true)
      if field == "upload_id"
        expect(admin.reload.uploaded_avatar_id).to eq(upload.id)
      else
        column = field.sub(/_url\z/, "_id")
        expect(admin.user_profile.reload.public_send(column)).to eq(upload.id)
      end
    end

    %i[outside_mcp other_authorization].each do |origin|
      it "generically refuses #{origin} #{field} while retaining the no-rule profile update" do
        upload =
          (
            if origin == :outside_mcp
              Fabricate(:upload, user: admin)
            else
              upload_through_mcp(access_token: issue_token)
            end
          )
        value = field == "upload_id" ? upload.id : upload.url
        args = { :username => admin.username, field => value }
        isolated { expect_success(rpc("discourse_update_user", args)) }
        activate!
        before_state = content_state
        response = rpc("discourse_update_user", args)
        expect_reference_refusal(response)
        expect(content_state).to eq(before_state)
        expect(response.to_json).not_to include(upload.original_filename, upload.sha1)
      end
    end
  end

  it "accepts a granted avatar upload when creating another user" do
    args = {
      username: "u4avatar",
      email: "u4avatar@example.com",
      name: "Garden avatar",
      password: "averylongpassword723!",
    }
    isolated do
      upload = upload_through_mcp
      expect_success(rpc("discourse_create_user", args.merge(upload_id: upload.id)))
    end
    activate!
    upload = upload_through_mcp
    data = expect_success(rpc("discourse_create_user", args.merge(upload_id: upload.id)))
    expect(User.find(data.fetch("user_id")).uploaded_avatar_id).to eq(upload.id)
  end

  it "refuses an ungranted avatar id on user creation without creating the user" do
    upload = Fabricate(:upload, user: admin)
    args = {
      username: "u4avatar",
      email: "u4avatar@example.com",
      name: "Garden avatar",
      password: "averylongpassword723!",
      upload_id: upload.id,
    }
    isolated { expect_success(rpc("discourse_create_user", args)) }
    activate!
    expect_reference_refusal(rpc("discourse_create_user", args))
    expect(User.find_by(username: args[:username])).to be_nil
  end

  %i[text avatar profile_background card_background].each do |use|
    it "revokes granted #{use} use after a human references it in an unwritten record" do
      upload = upload_through_mcp
      human_post = PostCreator.create!(recipient, raw: upload_text(upload), topic_id: post.topic_id)
      expect(UploadReference.exists?(upload: upload, target: human_post)).to eq(true)
      name, args =
        if use == :text
          ["discourse_create_topic", topic_arguments(raw: upload_text(upload))]
        else
          field = use == :avatar ? "upload_id" : "#{use}_upload_url"
          [
            "discourse_update_user",
            { :username => admin.username, field => use == :avatar ? upload.id : upload.url },
          ]
        end
      isolated { expect_success(rpc(name, args)) }
      activate!
      before_state = content_state
      response = rpc(name, args)
      aggregate_failures do
        expect_reference_refusal(response)
        expect(content_state).to eq(before_state)
      end
    end
  end

  it "rechecks a grant issued under active rules after a human's later reference" do
    activate!
    upload = upload_through_mcp
    expect_success(rpc("discourse_create_topic", topic_arguments(raw: upload_text(upload))))
    human_post = PostCreator.create!(admin, raw: upload_text(upload), topic_id: post.topic_id)
    expect(UploadReference.exists?(upload: upload, target: human_post)).to eq(true)
    assert_reference_write(
      "discourse_create_post",
      { topic_id: post.topic_id, raw: upload_text(upload) },
    )
  end

  %i[first second].each do |position|
    it "checks every srcset member when the #{position} member is granted" do
      SiteSetting.allowed_href_schemes = "upload"
      isolated do
        upload = upload_through_mcp
        urls = [upload.short_url, "https://external.example/garden.mp4"]
        urls.reverse! if position == :second
        raw =
          "A seasonal illustration follows.\n\n<video controls><source srcset=\"#{urls[0]} 1x,#{urls[1]} 2x\"></video>"
        expect_success(rpc("discourse_create_topic", topic_arguments(raw: raw)))
      end
      activate!
      upload = upload_through_mcp
      urls = [upload.short_url, "https://external.example/garden.mp4"]
      urls.reverse! if position == :second
      raw =
        "A seasonal illustration follows.\n\n<video controls><source srcset=\"#{urls[0]} 1x,#{urls[1]} 2x\"></video>"
      expect(
        Nokogiri::HTML5.fragment(PrettyText.cook(raw)).at_css("source[srcset]")["srcset"],
      ).to include(*urls)
      assert_reference_write("discourse_create_topic", topic_arguments(raw: raw))
    end
  end

  it "still refuses an internal anchor wrapped around a granted image" do
    isolated do
      upload = upload_through_mcp
      raw = "A seasonal illustration. [![Garden](#{upload.short_url})](/t/garden/#{post.topic_id})"
      expect_success(rpc("discourse_create_topic", topic_arguments(raw: raw)))
    end
    activate!
    upload = upload_through_mcp
    raw = "A seasonal illustration. [![Garden](#{upload.short_url})](/t/garden/#{post.topic_id})"
    assert_reference_write("discourse_create_topic", topic_arguments(raw: raw))
  end

  %i[external same_site].each do |host|
    it "refuses #{host} URL upload before downloading, preserving the no-rule upload" do
      url =
        (
          if host == :same_site
            "#{Discourse.base_url}/uploads/garden.png"
          else
            "https://external.example/garden.png"
          end
        )
      request =
        stub_request(:get, url).to_return(
          status: 200,
          body: file_from_fixtures("logo.png").read,
          headers: {
            "Content-Type" => "image/png",
          },
        )
      args = { upload_type: "composer", url: url }
      isolated { expect_success(rpc("discourse_upload_file", args)) }
      WebMock.reset_executed_requests!
      activate!
      before_count = Upload.count
      expect_reference_refusal(rpc("discourse_upload_file", args))
      expect(Upload.count).to eq(before_count)
      expect(request).not_to have_been_requested
    end
  end

  it "refuses deduplicated bytes without exposing existing filename or ownership" do
    original = upload_through_mcp(access_token: issue_token(recipient))
    original.update!(original_filename: "human-confidential-filename.png")
    args = upload_arguments.merge(filename: "different-filename.png")
    isolated do
      data = expect_success(rpc("discourse_upload_file", args))
      expect(data.fetch("id")).to eq(original.id)
    end
    activate!
    before_count = Upload.count
    owners = UserUpload.where(upload: original).order(:user_id).pluck(:user_id)
    response = rpc("discourse_upload_file", args)
    expect_refusal(response)
    expect(Upload.count).to eq(before_count)
    expect(UserUpload.where(upload: original).order(:user_id).pluck(:user_id)).to eq(owners)
    expect(response.to_json).not_to include(
      original.original_filename,
      original.sha1,
      recipient.username,
    )
    expect(response.to_json).not_to match(/(?<!\d)#{original.id}(?!\d)/)
  end

  describe "with upload-host URLs" do
    include UploadsHelpers

    %i[s3 cdn local_cdn].each do |host|
      it "rejects labeled #{host} upload-host URLs without resolving existence" do
        base =
          if host == :local_cdn
            set_cdn_url "https://u4-local-cdn.example"
            GlobalSetting.cdn_url
          else
            setup_s3
            SiteSetting.s3_cdn_url = "https://u4-upload-cdn.example"
            host == :s3 ? Discourse.store.absolute_base_url : SiteSetting.s3_cdn_url
          end
        raw = "Please inspect [this file](#{base}/original/1X/#{"a" * 40}.png) before replying."
        args = topic_arguments(raw: raw)
        isolated { expect_success(rpc("discourse_create_topic", args)) }
        activate!
        assert_reference_write("discourse_create_topic", args)
      end
    end
  end

  describe "with cooked image and media sources" do
    def upload_image
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

    %i[video blocked_src blocked_srcset].each do |carrier|
      it "refuses ungranted media carried by #{carrier} attributes before a later rebake" do
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
            srcset = "#{upload_image.url} 1x,#{url} 2x"
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

    %i[external ungranted_upload].each do |source|
      it "refuses a granted data-orig-src decoy hiding an #{source} real source" do
        upload = upload_image
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

    it "permits granted upload images and renderer placeholders through repeated MCP writes" do
      activate!
      upload = upload_image
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
  end

  describe "when a callback references the granted upload" do
    def upload_image
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

    %i[different_user same_user].each do |author|
      it "revokes a grant after a synchronous #{author} callback writes an unrelated reference" do
        activate!
        upload = upload_image
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
  end

  describe "with attachment and short-url links" do
    def attachment_upload
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

    def notes_upload
      data =
        expect_success(
          rpc(
            "discourse_upload_file",
            {
              upload_type: "composer",
              filename: "review-three-garden.txt",
              image_data: Base64.strict_encode64("Notes about seasonal gardens"),
            },
          ),
        )
      Upload.find(data.fetch("id"))
    end

    it "keeps genuine granted attachments rendered from upload short URLs" do
      activate!
      upload = attachment_upload
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
      it "refuses a granted attachment decoy whose href names #{destination}" do
        activate!
        upload = attachment_upload
        genuine = "Please read [garden notes|attachment](#{upload.url})."
        data =
          expect_success(rpc("discourse_create_post", { topic_id: post.topic_id, raw: genuine }))
        anchor = Nokogiri::HTML5.fragment(Post.find(data.fetch("id")).cooked).at_css("a.attachment")
        expect(anchor["href"]).to eq(upload.url)
        expect(anchor["data-orig-href"]).to be_nil
        href =
          destination == :topic ? "/t/#{post.topic_id}" : Fabricate(:upload, user: recipient).url
        raw =
          "Please read <a class=\"attachment\" href=\"#{href}\" data-orig-href=\"#{upload.short_url}\">garden notes</a>."
        args = topic_arguments(raw: raw)
        isolated do
          McpContentRule.delete_all
          data = expect_success(rpc("discourse_create_topic", args))
          anchor =
            Nokogiri::HTML5.fragment(Post.find(data.fetch("id")).cooked).at_css("a.attachment")
          expect(anchor["href"]).to eq(href)
          expect(anchor["data-orig-href"]).to eq(upload.short_url)
        end
        assert_reference_write("discourse_create_topic", args)
      end
    end

    %w[../../../ %2e%2e/%2e%2e/%2e%2e/].each do |traversal|
      %i[href pair original matching_pair].each do |shape|
        it "refuses short-url trailing traversal #{traversal} in #{shape}" do
          activate!
          upload = notes_upload
          destination = Fabricate(:topic, id: 111_730_001, category: restricted_category)
          traversing_path = "#{upload.short_path}/#{traversal}t/#{destination.id}"
          href = shape == :original ? upload.short_path : traversing_path
          original =
            case shape
            when :pair
              upload.short_url
            when :original, :matching_pair
              traversing_path
            end
          attribute = original ? " data-orig-href=\"#{original}\"" : ""
          raw = "Read <a class=\"attachment\" href=\"#{href}\"#{attribute}>garden notes</a>."
          args = topic_arguments(raw:)
          isolated do
            McpContentRule.delete_all
            data = expect_success(rpc("discourse_create_topic", args))
            anchor = Nokogiri::HTML5.fragment(Post.find(data.fetch("id")).cooked).at_css("a")
            expect(anchor["href"]).to eq(href)
            expect(anchor["data-orig-href"]).to eq(original)
            expect(
              URI.join(Discourse.base_url, CGI.unescape(traversing_path)).normalize.path,
            ).to eq("/t/#{destination.id}")
          end
          assert_reference_write("discourse_create_topic", args)
        end
      end
    end

    %w[mention mention-group].each do |css_class|
      it "refuses #{css_class} anchors carrying an ungranted upload in data-orig-href" do
        group = Fabricate(:group, name: "reviewthreegardeners")
        name = css_class == "mention" ? recipient.username.downcase : group.name
        prefix = css_class == "mention" ? "u" : "groups"
        upload = Fabricate(:upload, id: 111_730_002, user: recipient)
        raw =
          "Ask <a class=\"#{css_class}\" href=\"/#{prefix}/#{name}\" data-orig-href=\"#{upload.url}\">@#{name}</a> about gardens."
        args = topic_arguments(raw:)
        isolated do
          data = expect_success(rpc("discourse_create_topic", args))
          anchor = Nokogiri::HTML5.fragment(Post.find(data.fetch("id")).cooked).at_css("a")
          expect(anchor["data-orig-href"]).to eq(upload.url)
          expect(anchor["href"]).to eq("/#{prefix}/#{name}")
        end
        activate!
        assert_reference_write("discourse_create_topic", args)
      end
    end

    it "keeps genuine short-url attachments and genuine user and group mentions" do
      activate!
      upload = notes_upload
      group =
        Fabricate(
          :group,
          name: "reviewthreeallowed",
          mentionable_level: Group::ALIAS_LEVELS[:everyone],
        )
      raw =
        "Read [garden notes|attachment](#{upload.short_url}) with @#{recipient.username} and @#{group.name}."
      data = expect_success(rpc("discourse_create_post", { topic_id: post.topic_id, raw: }))
      cooked = Nokogiri::HTML5.fragment(Post.find(data.fetch("id")).cooked)
      expect(cooked.at_css("a.attachment")["href"]).to eq(upload.short_path)
      expect(cooked.at_css("a.mention")["href"]).to eq("/u/#{recipient.username.downcase}")
      expect(cooked.at_css("a.mention-group")["href"]).to eq("/groups/#{group.name}")
    end
  end
end

# rubocop:enable Discourse/NoIterationOverRSpecDefinitions
