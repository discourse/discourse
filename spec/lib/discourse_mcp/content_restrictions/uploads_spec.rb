# frozen_string_literal: true

require "base64"

describe DiscourseMcp::Server do
  describe "upload references and upload_file" do
    fab!(:admin) { Fabricate(:admin, refresh_auto_groups: true) }
    let(:image_bytes) { File.binread(file_from_fixtures("logo.png").path) }
    let(:client) do
      McpOauthClient.create!(
        client_id: SecureRandom.hex,
        name: "Upload reference client",
        registration_type: "pre_registered",
        trust_state: "approved",
        redirect_uris: ["http://127.0.0.1/callback"],
      )
    end
    let(:authorization) do
      DiscourseMcp::OAuth::AuthorizationGrant.create!(
        user: admin,
        client:,
        redirect_uri: client.redirect_uris.first,
        requested_scopes: DiscourseMcp.registry.scopes,
      )
    end
    let(:raw_token) { McpOauthAccessToken.issue!(authorization:) }
    let(:token) { McpOauthAccessToken.find_by!(token_hash: McpOauthAccessToken.digest(raw_token)) }

    before do
      DiscourseMcp.reset_registry!
      SiteSetting.mcp_server_enabled = true
      SiteSetting.secure_uploads = false
      SiteSetting.uploaded_avatars_allowed_groups = Group::AUTO_GROUPS[:everyone]
    end

    around do |example|
      original_registry = DiscourseMcp.registry
      example.run
    ensure
      DiscourseMcp.instance_variable_set(:@registry, original_registry)
    end

    def activate_rule(kind)
      return McpContentRule.create!(rule_kind: "private_messages", config: {}) if kind == "PM-off"

      DiscourseMcp.registry.register_content_data_kind("oracle:metadata", provider: "oracle")
      DiscourseMcp.registry.register_content_rule_kind(
        "oracle:metadata",
        provider: "oracle",
        affected_data_kinds: ["oracle:metadata"],
        config_contract: {
          type: "object",
          additionalProperties: false,
        },
        compile: ->(_config) { DiscourseMcp::ContentPolicy::Evaluator.new },
      )
      McpContentRule.create!(rule_kind: "oracle:metadata", config: {})
      expect(DiscourseMcp::ContentPolicy.load).to be_active
      expect(DiscourseMcp::ContentPolicy.load.denies_all?("private_messages")).to eq(false)
    end

    def tool(name, arguments = {})
      McpPrimitive.find_or_create_by!(kind: "tool", identifier: name).update!(enabled: true)
      expect(DiscourseMcp.registry.find(:tool, name)).to be_present
      request = ActionDispatch::TestRequest.create
      request.headers["MCP-Protocol-Version"] = DiscourseMcp::LEGACY_PROTOCOL_VERSION
      DiscourseMcp::Server.new(
        request:,
        request_context: DiscourseMcp::RequestContext.new(token),
      ).call(
        {
          "jsonrpc" => "2.0",
          "id" => 1,
          "method" => "tools/call",
          "params" => {
            "name" => name,
            "arguments" => arguments.deep_stringify_keys,
          },
        },
      )
    end

    def content(response)
      expect(response.http_status).to eq(200)
      expect(response.body[:error]).to be_nil
      expect(response.body.dig(:result, :isError)).to eq(false)
      structured = response.body.fetch(:result).fetch(:structuredContent).deep_symbolize_keys
      text = response.body.fetch(:result).fetch(:content).sole.fetch(:text)
      expect(JSON.parse(text, symbolize_names: true)).to eq(structured)
      structured
    end

    def expect_blocked(response)
      expect(response.http_status).to eq(200)
      expect(response.body[:error]).to be_nil
      expect(response.body.dig(:result, :isError)).to eq(true)
      expect(response.body.dig(:result, :content)).to eq(
        [{ type: "text", text: I18n.t("mcp.errors.content_policy_blocked") }],
      )
      expect(response.body.dig(:result, :structuredContent)).to be_nil
      expect(response.headers.keys.map(&:downcase)).not_to include("www-authenticate")
    end

    def pm_upload(owner)
      Group.refresh_automatic_groups_for_user!(owner)
      upload =
        UploadCreator.new(
          file_from_fixtures("logo.png"),
          "pm-attachment.png",
          type: "composer",
          for_private_message: true,
        ).create_for(owner.id)
      expect(upload).to be_persisted
      post =
        Fabricate(
          :private_message_post,
          user: owner,
          raw: "![#{upload.original_filename}](#{upload.short_url})",
        )
      post.link_post_uploads
      expect(UploadReference.where(target: post, upload:)).to exist
      upload
    end

    def signup_arguments
      suffix = SecureRandom.hex(6)
      {
        username: "mcp_#{suffix}",
        email: "mcp_#{suffix}@example.com",
        name: "MCP regression user",
        password: "Strong-password-#{suffix}!",
      }
    end

    def seed_profile_uploads
      upload = Fabricate(:upload, user: admin)
      admin.pick_avatar!(upload.id, type: :custom)
      admin.user_profile.update!(
        profile_background_upload_id: upload.id,
        card_background_upload_id: upload.id,
      )
    end

    def profile_state
      admin.reload
      {
        name: admin.name,
        uploaded_avatar_id: admin.uploaded_avatar_id,
        custom_upload_id: admin.user_avatar.reload.custom_upload_id,
        profile_background_upload_id: admin.user_profile.reload.profile_background_upload_id,
        card_background_upload_id: admin.user_profile.card_background_upload_id,
      }
    end

    shared_examples "restricted existing upload references" do |kind|
      it "refuses create_user upload_id with #{kind} active and creates no user" do
        uploads = [pm_upload(admin), Fabricate(:upload, user: admin)]
        activate_rule(kind)

        uploads.each do |upload|
          aggregate_failures("upload #{upload.id}") do
            response = nil
            arguments = signup_arguments.merge(upload_id: upload.id)
            expect { response = tool("discourse_create_user", arguments) }.not_to change {
              User.count
            }
            expect_blocked(response)
            expect(User.exists?(username: arguments.fetch(:username))).to eq(false)
          end
        end
      end
    end

    shared_examples "restricted profile upload references" do |kind, field|
      it "refuses update_user #{field} with #{kind} active and preserves the profile" do
        seed_profile_uploads
        original = profile_state
        uploads = [pm_upload(admin), Fabricate(:upload, user: admin)]
        activate_rule(kind)

        uploads.each do |upload|
          aggregate_failures("upload #{upload.id}") do
            value = field == :upload_id ? upload.id : upload.url
            response =
              tool(
                "discourse_update_user",
                :username => admin.username,
                :name => "Attempted profile change",
                field => value,
              )

            expect_blocked(response)
            expect(profile_state).to eq(original)
          end
        end
      end
    end

    include_examples "restricted existing upload references", "PM-off"
    include_examples "restricted existing upload references", "an unrelated rule"
    include_examples "restricted profile upload references", "PM-off", :upload_id
    include_examples "restricted profile upload references",
                     "PM-off",
                     :profile_background_upload_url
    include_examples "restricted profile upload references", "PM-off", :card_background_upload_url
    include_examples "restricted profile upload references", "an unrelated rule", :upload_id
    include_examples "restricted profile upload references",
                     "an unrelated rule",
                     :profile_background_upload_url
    include_examples "restricted profile upload references",
                     "an unrelated rule",
                     :card_background_upload_url

    it "permits create_user with a PM attachment upload_id without rule rows" do
      upload = pm_upload(admin)
      response = nil

      expect do
        response = tool("discourse_create_user", signup_arguments.merge(upload_id: upload.id))
      end.to change { User.count }.by(1)

      result = content(response)
      expect(result).to include(created: true, avatar_updated: true)
      user = User.find(result.fetch(:user_id))
      expect(user.uploaded_avatar_id).to eq(upload.id)
      expect(user.user_avatar.custom_upload_id).to eq(upload.id)
    end

    shared_examples "unrestricted profile upload references" do |field|
      it "permits update_user #{field} using a PM attachment without rule rows" do
        seed_profile_uploads
        upload = pm_upload(admin)
        value = field == :upload_id ? upload.id : upload.url

        result =
          content(tool("discourse_update_user", { :username => admin.username, field => value }))

        expect(result).to include(success: true, updated_fields: [field.to_s])
        if field == :upload_id
          expect(profile_state).to include(
            uploaded_avatar_id: upload.id,
            custom_upload_id: upload.id,
          )
        else
          expect(profile_state.fetch(field.to_s.sub("_url", "_id").to_sym)).to eq(upload.id)
        end
      end
    end

    include_examples "unrestricted profile upload references", :upload_id
    include_examples "unrestricted profile upload references", :profile_background_upload_url
    include_examples "unrestricted profile upload references", :card_background_upload_url

    def upload_urls(upload)
      same_site = "#{Discourse.base_url}#{upload.url}"
      redirect = "https://example.com/redirected-attachment.png"
      fresh = "https://example.com/fresh-image.jpg"
      stub_request(:get, same_site).to_return(status: 200, body: image_bytes)
      stub_request(:get, redirect).to_return(status: 302, headers: { "Location" => same_site })
      stub_request(:get, fresh).to_return(
        status: 200,
        body: File.binread(file_from_fixtures("logo.jpg").path),
      )
      [same_site, redirect, fresh]
    end

    shared_examples "restricted file uploads" do |kind|
      it "refuses upload_file URLs including same-site URLs and redirects with #{kind} active" do
        upload = pm_upload(Fabricate(:user))
        urls = upload_urls(upload)
        activate_rule(kind)

        urls.each do |url|
          aggregate_failures(url) do
            response = nil
            expect do
              response = tool("discourse_upload_file", upload_type: "composer", url:)
            end.not_to change { [Upload.count, UserUpload.where(user: admin).count] }

            expect_blocked(response)
            expect(WebMock).not_to have_requested(:get, url)
          end
        end
      end

      it "refuses duplicate upload_file bytes without metadata or an ownership grant with #{kind} active" do
        upload = pm_upload(Fabricate(:user))
        expect(UserUpload.where(user: admin, upload:)).not_to exist
        activate_rule(kind)
        response = nil

        aggregate_failures do
          expect do
            response =
              tool(
                "discourse_upload_file",
                upload_type: "composer",
                image_data: Base64.strict_encode64(image_bytes),
                filename: "renamed-attachment.png",
              )
          end.not_to change { [Upload.count, UserUpload.where(user: admin, upload:).count] }

          expect_blocked(response)
          expect(response.body.fetch(:result).keys).not_to include(
            :id,
            :url,
            :short_url,
            :original_filename,
          )
          expect(JSON.generate(response.body)).not_to include(
            upload.url,
            upload.short_url,
            upload.original_filename,
          )
          expect(UserUpload.where(user: admin, upload:)).not_to exist
        end
      end

      it "permits fresh upload_file bytes with #{kind} active" do
        expect(Upload.where(sha1: Digest::SHA1.hexdigest(image_bytes))).not_to exist
        activate_rule(kind)
        response = nil

        expect do
          response =
            tool(
              "discourse_upload_file",
              upload_type: "composer",
              image_data: Base64.strict_encode64(image_bytes),
              filename: "fresh-image.png",
            )
        end.to change { Upload.count }.by(1)

        result = content(response)
        upload = Upload.find(result.fetch(:id))
        expect(upload).to have_attributes(user_id: admin.id, original_filename: "fresh-image.png")
        expect(UserUpload.where(user: admin, upload:)).to exist
      end
    end

    include_examples "restricted file uploads", "PM-off"
    include_examples "restricted file uploads", "an unrelated rule"

    it "permits upload_file URLs including same-site URLs and redirects without rule rows" do
      upload = pm_upload(Fabricate(:user))

      upload_urls(upload).each do |url|
        aggregate_failures(url) do
          result = content(tool("discourse_upload_file", upload_type: "composer", url:))

          if url.end_with?("fresh-image.jpg")
            expect(result.fetch(:id)).not_to eq(upload.id)
            expect(result.fetch(:original_filename)).to eq("fresh-image.jpg")
            expect(UserUpload.where(user: admin, upload_id: result.fetch(:id))).to exist
          else
            expect(result).to include(
              id: upload.id,
              url: UrlHelper.cook_url(upload.url),
              short_url: upload.short_url,
              original_filename: upload.original_filename,
            )
          end
          expect(WebMock).to have_requested(:get, url)
        end
      end
      expect(UserUpload.where(user: admin, upload:)).to exist
    end

    it "returns duplicate upload_file metadata and grants ownership without rule rows" do
      upload = pm_upload(Fabricate(:user))
      expect(UserUpload.where(user: admin, upload:)).not_to exist
      response = nil

      expect do
        response =
          tool(
            "discourse_upload_file",
            upload_type: "composer",
            image_data: Base64.strict_encode64(image_bytes),
            filename: "renamed-attachment.png",
          )
      end.to change { UserUpload.where(user: admin, upload:).count }.by(1)

      expect(content(response)).to include(
        id: upload.id,
        url: UrlHelper.cook_url(upload.url),
        short_url: upload.short_url,
        original_filename: upload.original_filename,
      )
    end

    it "permits fresh upload_file bytes without rule rows" do
      expect(Upload.where(sha1: Digest::SHA1.hexdigest(image_bytes))).not_to exist
      response = nil

      expect do
        response =
          tool(
            "discourse_upload_file",
            upload_type: "composer",
            image_data: Base64.strict_encode64(image_bytes),
            filename: "fresh-image.png",
          )
      end.to change { Upload.count }.by(1)

      upload = Upload.find(content(response).fetch(:id))
      expect(upload.user_id).to eq(admin.id)
      expect(UserUpload.where(user: admin, upload:)).to exist
    end
  end

  describe "upload_file racing another user's upload" do
    fab!(:admin) { Fabricate(:admin, refresh_auto_groups: true) }
    let(:image_bytes) { File.binread(file_from_fixtures("logo.png").path) }
    let(:client) do
      McpOauthClient.create!(
        client_id: SecureRandom.hex,
        name: "Upload race client",
        registration_type: "pre_registered",
        trust_state: "approved",
        redirect_uris: ["http://127.0.0.1/callback"],
      )
    end
    let(:authorization) do
      DiscourseMcp::OAuth::AuthorizationGrant.create!(
        user: admin,
        client:,
        redirect_uri: client.redirect_uris.first,
        requested_scopes: DiscourseMcp.registry.scopes,
      )
    end
    let(:raw_token) { McpOauthAccessToken.issue!(authorization:) }
    let(:token) { McpOauthAccessToken.find_by!(token_hash: McpOauthAccessToken.digest(raw_token)) }

    before do
      DiscourseMcp.reset_registry!
      SiteSetting.mcp_server_enabled = true
      SiteSetting.secure_uploads = false
      SiteSetting.enable_badges = false
    end

    around do |example|
      original_registry = DiscourseMcp.registry
      example.run
    ensure
      DiscourseMcp.instance_variable_set(:@registry, original_registry)
    end

    def activate_rule(kind)
      if kind == "without rule rows"
        expect(McpContentRule.count).to eq(0)
        return
      end
      return McpContentRule.create!(rule_kind: "private_messages", config: {}) if kind == "PM-off"

      DiscourseMcp.registry.register_content_data_kind("oracle:metadata", provider: "oracle")
      DiscourseMcp.registry.register_content_rule_kind(
        "oracle:metadata",
        provider: "oracle",
        affected_data_kinds: ["oracle:metadata"],
        config_contract: {
          type: "object",
          additionalProperties: false,
        },
        compile: ->(_config) { DiscourseMcp::ContentPolicy::Evaluator.new },
      )
      McpContentRule.create!(rule_kind: "oracle:metadata", config: {})
      expect(DiscourseMcp::ContentPolicy.load).to be_active
      expect(DiscourseMcp::ContentPolicy.load.denies_all?("private_messages")).to eq(false)
    end

    def tool(name, arguments = {})
      McpPrimitive.find_or_create_by!(kind: "tool", identifier: name).update!(enabled: true)
      expect(DiscourseMcp.registry.find(:tool, name)).to be_present
      request = ActionDispatch::TestRequest.create
      request.headers["MCP-Protocol-Version"] = DiscourseMcp::LEGACY_PROTOCOL_VERSION
      DiscourseMcp::Server.new(
        request:,
        request_context: DiscourseMcp::RequestContext.new(token),
      ).call(
        {
          "jsonrpc" => "2.0",
          "id" => 1,
          "method" => "tools/call",
          "params" => {
            "name" => name,
            "arguments" => arguments.deep_stringify_keys,
          },
        },
      )
    end

    def content(response)
      expect(response.http_status).to eq(200)
      expect(response.body[:error]).to be_nil
      expect(response.body.dig(:result, :isError)).to eq(false)
      structured = response.body.fetch(:result).fetch(:structuredContent).deep_symbolize_keys
      text = response.body.fetch(:result).fetch(:content).sole.fetch(:text)
      expect(JSON.parse(text, symbolize_names: true)).to eq(
        JSON.parse(JSON.generate(structured), symbolize_names: true),
      )
      structured
    end

    def expect_blocked(response)
      expect(response.http_status).to eq(200)
      expect(response.body[:error]).to be_nil
      expect(response.body.dig(:result, :isError)).to eq(true)
      expect(response.body.dig(:result, :content)).to eq(
        [{ type: "text", text: I18n.t("mcp.errors.content_policy_blocked") }],
      )
      expect(response.body.dig(:result, :structuredContent)).to be_nil
      expect(response.headers.keys.map(&:downcase)).not_to include("www-authenticate")
    end

    def upload_arguments
      {
        upload_type: "composer",
        image_data: Base64.strict_encode64(image_bytes),
        filename: "caller-image.png",
      }
    end

    shared_examples "upload race" do |kind|
      it "handles another user's upload created during upload_file #{kind}" do
        freeze_time
        owner = Fabricate(:user)
        call_started_at = Time.zone.now
        raced_upload = nil
        activate_rule(kind)

        # Model the deduplication winner and its ownership grant inside the creation path.
        allow(UploadsController).to receive(:create_upload) do |**options|
          freeze_time(call_started_at + 1.second)
          raced_upload =
            Fabricate(
              :upload,
              user: owner,
              sha1: Digest::SHA1.hexdigest(image_bytes),
              original_filename: "other-users-image.png",
            )
          UserUpload.create!(user: options.fetch(:current_user), upload: raced_upload)
          raced_upload
        end

        response = tool("discourse_upload_file", upload_arguments)

        expect(raced_upload.created_at).to be > call_started_at
        expect(raced_upload.user_id).to eq(owner.id)
        if kind == "without rule rows"
          expect(content(response)).to include(
            id: raced_upload.id,
            url: UrlHelper.cook_url(raced_upload.url),
            short_url: raced_upload.short_url,
            original_filename: raced_upload.original_filename,
          )
          expect(UserUpload.where(user: admin, upload: raced_upload)).to exist
        else
          aggregate_failures do
            expect_blocked(response)
            expect(JSON.generate(response.body)).not_to include(
              UrlHelper.cook_url(raced_upload.url),
              raced_upload.short_url,
              raced_upload.original_filename,
            )
            expect(UserUpload.where(user: admin, upload: raced_upload)).not_to exist
          end
        end
      end

      it "permits the caller's own fresh upload_file #{kind}" do
        expect(Upload.where(sha1: Digest::SHA1.hexdigest(image_bytes))).not_to exist
        activate_rule(kind)
        response = nil

        expect { response = tool("discourse_upload_file", upload_arguments) }.to change {
          Upload.count
        }.by(1)

        result = content(response)
        upload = Upload.find(result.fetch(:id))
        expect(upload).to have_attributes(user_id: admin.id, original_filename: "caller-image.png")
        expect(UserUpload.where(user: admin, upload:)).to exist
      end
    end

    include_examples "upload race", "PM-off"
    include_examples "upload race", "an unrelated rule"
    include_examples "upload race", "without rule rows"
  end

  describe "upload_file deduplicating a concurrent same-user upload" do
    fab!(:admin) { Fabricate(:admin, refresh_auto_groups: true) }
    let(:image_bytes) { File.binread(file_from_fixtures("logo.png").path) }
    let(:client) do
      McpOauthClient.create!(
        client_id: SecureRandom.hex,
        name: "Upload deduplication client",
        registration_type: "pre_registered",
        trust_state: "approved",
        redirect_uris: ["http://127.0.0.1/callback"],
      )
    end
    let(:authorization) do
      DiscourseMcp::OAuth::AuthorizationGrant.create!(
        user: admin,
        client:,
        redirect_uri: client.redirect_uris.first,
        requested_scopes: DiscourseMcp.registry.scopes,
      )
    end
    let(:raw_token) { McpOauthAccessToken.issue!(authorization:) }
    let(:token) { McpOauthAccessToken.find_by!(token_hash: McpOauthAccessToken.digest(raw_token)) }

    before do
      DiscourseMcp.reset_registry!
      SiteSetting.mcp_server_enabled = true
      SiteSetting.secure_uploads = false
      SiteSetting.enable_badges = false
    end

    around do |example|
      original_registry = DiscourseMcp.registry
      example.run
    ensure
      DiscourseMcp.instance_variable_set(:@registry, original_registry)
    end

    def activate_rule(kind)
      if kind == "without rule rows"
        expect(McpContentRule.count).to eq(0)
        return
      end
      return McpContentRule.create!(rule_kind: "private_messages", config: {}) if kind == "PM-off"

      DiscourseMcp.registry.register_content_data_kind("oracle:metadata", provider: "oracle")
      DiscourseMcp.registry.register_content_rule_kind(
        "oracle:metadata",
        provider: "oracle",
        affected_data_kinds: ["oracle:metadata"],
        config_contract: {
          type: "object",
          additionalProperties: false,
        },
        compile: ->(_config) { DiscourseMcp::ContentPolicy::Evaluator.new },
      )
      McpContentRule.create!(rule_kind: "oracle:metadata", config: {})
      expect(DiscourseMcp::ContentPolicy.load).to be_active
      expect(DiscourseMcp::ContentPolicy.load.denies_all?("private_messages")).to eq(false)
    end

    def tool(name, arguments = {})
      McpPrimitive.find_or_create_by!(kind: "tool", identifier: name).update!(enabled: true)
      expect(DiscourseMcp.registry.find(:tool, name)).to be_present
      request = ActionDispatch::TestRequest.create
      request.headers["MCP-Protocol-Version"] = DiscourseMcp::LEGACY_PROTOCOL_VERSION
      DiscourseMcp::Server.new(
        request:,
        request_context: DiscourseMcp::RequestContext.new(token),
      ).call(
        {
          "jsonrpc" => "2.0",
          "id" => 1,
          "method" => "tools/call",
          "params" => {
            "name" => name,
            "arguments" => arguments.deep_stringify_keys,
          },
        },
      )
    end

    def content(response)
      expect(response.http_status).to eq(200)
      expect(response.body[:error]).to be_nil
      expect(response.body.dig(:result, :isError)).to eq(false)
      structured = response.body.fetch(:result).fetch(:structuredContent).deep_symbolize_keys
      text = response.body.fetch(:result).fetch(:content).sole.fetch(:text)
      serialized = JSON.parse(JSON.generate(structured), symbolize_names: true)
      expect(JSON.parse(text, symbolize_names: true)).to eq(serialized)
      serialized
    end

    def expect_blocked(response)
      expect(response.http_status).to eq(200)
      expect(response.body[:error]).to be_nil
      expect(response.body.dig(:result, :isError)).to eq(true)
      expect(response.body.dig(:result, :content)).to eq(
        [{ type: "text", text: I18n.t("mcp.errors.content_policy_blocked") }],
      )
      expect(response.body.dig(:result, :structuredContent)).to be_nil
      expect(response.headers.keys.map(&:downcase)).not_to include("www-authenticate")
    end

    def upload_arguments
      {
        upload_type: "composer",
        image_data: Base64.strict_encode64(image_bytes),
        filename: "caller-image.png",
      }
    end

    shared_examples "same-user concurrent upload" do |kind|
      it "rejects a newer same-user upload returned by the real deduplication path #{kind}" do
        freeze_time
        call_started_at = Time.zone.now
        raced_upload = nil
        raced_upload_id = nil
        deduplicated_upload = nil
        expect(Upload.where(sha1: Digest::SHA1.hexdigest(image_bytes))).not_to exist
        activate_rule(kind)
        original_user_upload_ids = UserUpload.order(:id).pluck(:id)

        allow(UploadsController).to receive(
          :create_upload,
        ).and_wrap_original do |create_upload, **options|
          freeze_time(call_started_at + 1.second)
          # Pause a competing request after its Upload insert, before its ownership grant.
          raced_upload =
            Fabricate.build(
              :upload,
              user: admin,
              sha1: Digest::SHA1.hexdigest(image_bytes),
              original_filename: "concurrent-request-image.png",
            )
          raced_upload.save!
          # Refusal rolls back this simulated insert and clears the model's ID.
          raced_upload_id = raced_upload.id
          expect(UserUpload.where(user: admin, upload: raced_upload)).not_to exist

          deduplicated_upload = create_upload.call(**options)
        end

        response = tool("discourse_upload_file", upload_arguments)

        expect(raced_upload.created_at).to be > call_started_at
        expect(raced_upload.user_id).to eq(admin.id)
        expect(deduplicated_upload).to be_a(Upload)
        expect(deduplicated_upload.id).to eq(raced_upload_id)
        expect(deduplicated_upload).not_to equal(raced_upload)
        expect(deduplicated_upload.previously_new_record?).to eq(false)
        if kind == "without rule rows"
          expect(content(response)).to include(
            id: raced_upload.id,
            url: UrlHelper.cook_url(raced_upload.url),
            short_url: raced_upload.short_url,
            original_filename: raced_upload.original_filename,
          )
          expect(UserUpload.where(user: admin, upload: raced_upload)).to exist
          expect(UserUpload.count).to eq(original_user_upload_ids.size + 1)
        else
          aggregate_failures do
            expect_blocked(response)
            expect(JSON.generate(response.body)).not_to include(
              UrlHelper.cook_url(raced_upload.url),
              raced_upload.short_url,
              raced_upload.original_filename,
            )
            expect(UserUpload.order(:id).pluck(:id)).to eq(original_user_upload_ids)
            expect(UserUpload.where(user: admin, upload_id: deduplicated_upload.id)).not_to exist
          end
        end
      end

      it "permits uploads actually created by this call #{kind}" do
        expect(Upload.where(sha1: Digest::SHA1.hexdigest(image_bytes))).not_to exist
        activate_rule(kind)
        response = nil

        expect { response = tool("discourse_upload_file", upload_arguments) }.to change {
          Upload.count
        }.by(1).and change { UserUpload.where(user: admin).count }.by(1)

        result = content(response)
        upload = Upload.find(result.fetch(:id))
        expect(upload).to have_attributes(user_id: admin.id, original_filename: "caller-image.png")
        expect(result.fetch(:url)).to eq(UrlHelper.cook_url(upload.url))
        expect(UserUpload.where(user: admin, upload:)).to exist
      end
    end

    include_examples "same-user concurrent upload", "PM-off"
    include_examples "same-user concurrent upload", "an unrelated rule"
    include_examples "same-user concurrent upload", "without rule rows"
  end
end
