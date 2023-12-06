# frozen_string_literal: true

RSpec.describe UploadSecurity do
  subject(:security) { described_class.new(upload, opts) }

  fab!(:private_category) { Fabricate(:private_category, group: Fabricate(:group)) }
  fab!(:post_in_secure_context) do
    Fabricate(:post, topic: Fabricate(:topic, category: private_category))
  end
  fab!(:upload)

  let(:type) { nil }
  let(:opts) { { type: type, creating: creating } }

  context "when secure uploads is enabled" do
    before do
      setup_s3
      SiteSetting.secure_uploads = true
    end

    context "when creating the upload" do
      let(:creating) { true }

      context "when login_required (everything should be secure except public context items)" do
        before { SiteSetting.login_required = true }

        it "returns true" do
          expect(security.should_be_secure?).to eq(true)
        end

        context "if secure_uploads_pm_only" do
          before { SiteSetting.secure_uploads_pm_only = true }

          it "returns false" do
            expect(security.should_be_secure?).to eq(false)
          end
        end

        context "when uploading in public context" do
          describe "for a public type badge_image" do
            let(:type) { "badge_image" }
            it "returns false" do
              expect(security.should_be_secure?).to eq(false)
            end
          end

          describe "for a public type group_flair" do
            let(:type) { "group_flair" }
            it "returns false" do
              expect(security.should_be_secure?).to eq(false)
            end
          end

          describe "for a public type avatar" do
            let(:type) { "avatar" }
            it "returns false" do
              expect(security.should_be_secure?).to eq(false)
            end
          end

          describe "for a public type custom_emoji" do
            let(:type) { "custom_emoji" }
            it "returns false" do
              expect(security.should_be_secure?).to eq(false)
            end
          end

          describe "for a public type profile_background" do
            let(:type) { "profile_background" }
            it "returns false" do
              expect(security.should_be_secure?).to eq(false)
            end
          end

          describe "for a public type category_logo" do
            let(:type) { "category_logo" }
            it "returns false" do
              expect(security.should_be_secure?).to eq(false)
            end
          end

          describe "for a public type category_background" do
            let(:type) { "category_background" }
            it "returns false" do
              expect(security.should_be_secure?).to eq(false)
            end
          end

          describe "for a custom public type" do
            let(:type) { "my_custom_type" }

            it "returns true if the custom type has not been added" do
              expect(security.should_be_secure?).to eq(true)
            end

            it "returns false if the custom type has been added" do
              UploadSecurity.register_custom_public_type(type)
              expect(security.should_be_secure?).to eq(false)
              UploadSecurity.reset_custom_public_types
            end
          end

          describe "for_theme" do
            before { upload.stubs(:for_theme).returns(true) }

            it "returns false" do
              expect(security.should_be_secure?).to eq(false)
            end
          end

          describe "for_site_setting" do
            before { upload.stubs(:for_site_setting).returns(true) }

            it "returns false" do
              expect(security.should_be_secure?).to eq(false)
            end
          end

          describe "for_gravatar" do
            before { upload.stubs(:for_gravatar).returns(true) }

            it "returns false" do
              expect(security.should_be_secure?).to eq(false)
            end
          end

          describe "when it is based on a regular emoji" do
            it "returns false" do
              falafel =
                Emoji.all.find do |e|
                  e.url == "/images/emoji/twitter/falafel.png?v=#{Emoji::EMOJI_VERSION}"
                end
              upload.update!(origin: "http://localhost:3000#{falafel.url}")
              expect(security.should_be_secure?).to eq(false)
            end
          end
        end
      end

      context "when the access control post has_secure_uploads?" do
        before { upload.update(access_control_post_id: post_in_secure_context.id) }

        it "returns true" do
          expect(security.should_be_secure?).to eq(true)
        end

        context "when the post is deleted" do
          before { post_in_secure_context.trash! }

          it "still determines whether the post has secure uploads; returns true" do
            expect(security.should_be_secure?).to eq(true)
          end
        end
      end

      context "when uploading in the composer" do
        let(:type) { "composer" }
        it "returns true" do
          expect(security.should_be_secure?).to eq(true)
        end
      end

      context "when uploading for a group message" do
        before { upload.stubs(:for_group_message).returns(true) }
        it "returns true" do
          expect(security.should_be_secure?).to eq(true)
        end
      end

      context "when uploading for a PM" do
        before { upload.stubs(:for_private_message).returns(true) }
        it "returns true" do
          expect(security.should_be_secure?).to eq(true)
        end
      end

      context "when upload is already secure" do
        before { upload.update(secure: true) }
        it "returns true" do
          expect(security.should_be_secure?).to eq(true)
        end
      end

      context "for attachments" do
        before { upload.update(original_filename: "test.pdf") }

        context "when the access control post has_secure_uploads?" do
          before { upload.update(access_control_post: post_in_secure_context) }
          it "returns true" do
            expect(security.should_be_secure?).to eq(true)
          end
        end
      end
    end

    context "when checking an existing upload" do
      let(:creating) { false }

      before do
        # this is done so the after_save callbacks for site settings to make
        # UploadReference records works
        @original_provider = SiteSetting.provider
        SiteSetting.provider = SiteSettings::DbProvider.new(SiteSetting)
        setup_s3
        SiteSetting.secure_uploads = true
      end

      after { SiteSetting.provider = @original_provider }

      def create_secure_post_reference
        UploadReference.ensure_exist!(upload_ids: [upload.id], target: post_in_secure_context)
        upload.update!(access_control_post: post_in_secure_context)
      end

      describe "when the upload is first used for a post in a secure context" do
        it "returns true" do
          create_secure_post_reference
          expect(security.should_be_secure?).to eq(true)
        end
      end

      describe "when the upload is first used for a post in a secure context that is later deleted" do
        it "returns false" do
          create_secure_post_reference
          post_in_secure_context.trash!
          CustomEmoji.create(name: "meme", upload: upload)

          expect(security.should_be_secure?).to eq(false)
        end
      end

      describe "when the upload is first used for a site setting" do
        it "returns false" do
          SiteSetting.favicon = upload
          create_secure_post_reference
          expect(security.should_be_secure?).to eq(false)
        end
      end

      describe "when the upload is first used for a theme field" do
        it "returns false" do
          Fabricate(:theme_field, type_id: ThemeField.types[:theme_upload_var], upload: upload)
          create_secure_post_reference
          expect(security.should_be_secure?).to eq(false)
        end
      end

      describe "when the upload is first used for a group flair image" do
        it "returns false" do
          Fabricate(:group, flair_upload: upload)
          create_secure_post_reference
          expect(security.should_be_secure?).to eq(false)
        end
      end

      describe "when the upload is first used for a custom emoji" do
        it "returns false" do
          CustomEmoji.create(name: "meme", upload: upload)
          create_secure_post_reference
          expect(security.should_be_secure?).to eq(false)
        end

        context "when the created_at dates for upload references are identical" do
          it "orders by id as well and returns false" do
            now = Time.zone.now
            custom_emoji = CustomEmoji.create(name: "meme", upload: upload)
            create_secure_post_reference

            UploadReference.find_by(target: custom_emoji).update!(created_at: now)
            UploadReference.find_by(target: post_in_secure_context).update!(created_at: now)
            expect(security.should_be_secure?).to eq(false)
          end
        end
      end

      describe "when the upload is first used for a badge" do
        it "returns false" do
          Fabricate(:badge, image_upload: upload)
          create_secure_post_reference
          expect(security.should_be_secure?).to eq(false)
        end
      end

      describe "when the upload is first used for a category image (logo, dark logo, background)" do
        it "returns false" do
          Fabricate(:category, uploaded_logo: upload)
          create_secure_post_reference
          expect(security.should_be_secure?).to eq(false)
        end
      end

      describe "when the upload is first used for a user profile (profile background, card background)" do
        it "returns false" do
          user = Fabricate(:user)
          user.user_profile.update!(card_background_upload: upload)
          create_secure_post_reference
          expect(security.should_be_secure?).to eq(false)
        end
      end

      describe "when the upload is first used for a user uploaded avatar" do
        it "returns false" do
          Fabricate(:user, uploaded_avatar: upload)
          create_secure_post_reference
          expect(security.should_be_secure?).to eq(false)
        end
      end

      describe "when the upload is first used for a UserAvatar" do
        it "returns false" do
          Fabricate(:user_avatar, custom_upload: upload)
          create_secure_post_reference
          expect(security.should_be_secure?).to eq(false)
        end
      end
    end
  end

  context "when secure uploads is disabled" do
    let(:creating) { true }

    before { SiteSetting.secure_uploads = false }

    it "returns false" do
      expect(security.should_be_secure?).to eq(false)
    end

    context "for attachments" do
      before { upload.update(original_filename: "test.pdf") }

      it "returns false" do
        expect(security.should_be_secure?).to eq(false)
      end
    end
  end
end
