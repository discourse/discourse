# frozen_string_literal: true

require_relative "support"

# Each matrix cell needs an independent baseline receipt.
# rubocop:disable Discourse/NoIterationOverRSpecDefinitions

describe DiscourseMcp::Server, "#call" do
  include_context "with unit four MCP writes"

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

  it "[cr-u4] permits a fresh authorization upload and repeated references from its own written posts" do
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

  it "[cr-u4] preserves an upload grant across access tokens for the same authorization" do
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

  it "[cr-u4] refuses another authorization's fresh active-rule upload even for the same user" do
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
    it "[cr-u4] refuses text referencing #{origin} upload, preserving no-rule use" do
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
    it "[cr-u4] accepts this authorization's granted #{field}, preserving no-rule use" do
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
      it "[cr-u4] generically refuses #{origin} #{field} while retaining the no-rule profile update" do
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

  it "[cr-u4] accepts a granted avatar upload when creating another user" do
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

  it "[cr-u4] refuses an ungranted avatar id on user creation without creating the user" do
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
    it "[cr-u4] revokes granted #{use} use after a human references it in an unwritten record" do
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

  it "[cr-u4] rechecks a grant issued under active rules after a human's later reference" do
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
    it "[cr-u4] checks every srcset member when the #{position} member is granted" do
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

  it "[cr-u4] still refuses an internal anchor wrapped around a granted image" do
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
    it "[cr-u4] refuses #{host} URL upload before downloading, preserving the no-rule upload" do
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

  it "[cr-u4] refuses deduplicated bytes without exposing existing filename or ownership" do
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
end

# rubocop:enable Discourse/NoIterationOverRSpecDefinitions
