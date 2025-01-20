# frozen_string_literal: true

RSpec.describe Wizard::StepUpdater do
  before { SiteSetting.wizard_enabled = true }

  fab!(:user) { Fabricate(:admin) }
  let(:wizard) { Wizard::Builder.new(user).build }

  describe "introduction" do
    it "updates the introduction step" do
      locale = SiteSettings::DefaultsProvider::DEFAULT_LOCALE
      updater =
        wizard.create_updater(
          "introduction",
          title: "new forum title",
          site_description: "neat place",
          default_locale: locale,
        )
      updater.update

      expect(updater.success?).to eq(true)
      expect(SiteSetting.title).to eq("new forum title")
      expect(SiteSetting.site_description).to eq("neat place")
      expect(updater.refresh_required?).to eq(false)
      expect(wizard.completed_steps?("introduction")).to eq(true)
    end

    it "updates the locale and requires refresh when it does change" do
      updater = wizard.create_updater("introduction", default_locale: "ru")
      updater.update
      expect(SiteSetting.default_locale).to eq("ru")
      expect(updater.refresh_required?).to eq(true)
      expect(wizard.completed_steps?("introduction")).to eq(true)
    end

    it "won't allow updates to the default value, when required" do
      updater =
        wizard.create_updater(
          "introduction",
          title: SiteSetting.title,
          site_description: "neat place",
        )
      updater.update

      expect(updater.success?).to eq(false)
    end
  end

  describe "privacy" do
    it "updates to open correctly" do
      updater =
        wizard.create_updater(
          "privacy",
          login_required: "public",
          invite_only: "sign_up",
          must_approve_users: "no",
        )
      updater.update
      expect(updater.success?).to eq(true)
      expect(SiteSetting.login_required?).to eq(false)
      expect(SiteSetting.invite_only?).to eq(false)
      expect(SiteSetting.must_approve_users?).to eq(false)
      expect(wizard.completed_steps?("privacy")).to eq(true)
    end

    it "updates to private correctly" do
      updater =
        wizard.create_updater(
          "privacy",
          login_required: "private",
          invite_only: "invite_only",
          must_approve_users: "yes",
        )
      updater.update
      expect(updater.success?).to eq(true)
      expect(SiteSetting.login_required?).to eq(true)
      expect(SiteSetting.invite_only?).to eq(true)
      expect(SiteSetting.must_approve_users?).to eq(true)
      expect(wizard.completed_steps?("privacy")).to eq(true)
    end
  end

  describe "styling" do
    it "updates fonts" do
      updater =
        wizard.create_updater(
          "styling",
          body_font: "open_sans",
          heading_font: "oswald",
          homepage_style: "latest",
        )
      updater.update
      expect(updater.success?).to eq(true)
      expect(wizard.completed_steps?("styling")).to eq(true)
      expect(SiteSetting.base_font).to eq("open_sans")
      expect(SiteSetting.heading_font).to eq("oswald")
    end

    it "updates both fonts if site_font is used" do
      updater = wizard.create_updater("styling", site_font: "open_sans", homepage_style: "latest")
      updater.update
      expect(updater.success?).to eq(true)
      expect(wizard.completed_steps?("styling")).to eq(true)
      expect(SiteSetting.base_font).to eq("open_sans")
      expect(SiteSetting.heading_font).to eq("open_sans")
    end

    context "with colors" do
      context "with an existing color scheme" do
        fab!(:color_scheme) { Fabricate(:color_scheme, name: "existing", via_wizard: true) }

        it "updates the scheme" do
          updater =
            wizard.create_updater(
              "styling",
              color_scheme: "Dark",
              body_font: "arial",
              heading_font: "arial",
              homepage_style: "latest",
            )
          updater.update
          expect(updater.success?).to eq(true)
          expect(wizard.completed_steps?("styling")).to eq(true)
          expect(updater.refresh_required?).to eq(true)
          theme = Theme.find_by(id: SiteSetting.default_theme_id)
          expect(theme.color_scheme.base_scheme_id).to eq("Dark")
        end
      end

      context "with an existing default theme" do
        fab!(:theme)

        before { theme.set_default! }

        it "should update the color scheme of the default theme" do
          updater =
            wizard.create_updater(
              "styling",
              color_scheme: "Neutral",
              body_font: "arial",
              heading_font: "arial",
              homepage_style: "latest",
            )
          expect { updater.update }.not_to change { Theme.count }
          expect(updater.refresh_required?).to eq(true)
          theme.reload
          expect(theme.color_scheme.base_scheme_id).to eq("Neutral")
        end
      end

      context "without an existing theme" do
        before { Theme.delete_all }

        context "with dark theme" do
          it "creates the theme" do
            updater =
              wizard.create_updater(
                "styling",
                color_scheme: "Dark",
                body_font: "arial",
                heading_font: "arial",
                homepage_style: "latest",
              )

            expect { updater.update }.to change { Theme.count }.by(1)

            theme = Theme.last

            expect(theme.user_id).to eq(wizard.user.id)
            expect(theme.color_scheme.base_scheme_id).to eq("Dark")
          end
        end

        context "with light theme" do
          it "creates the theme" do
            updater =
              wizard.create_updater(
                "styling",
                color_scheme: ColorScheme::LIGHT_THEME_ID,
                body_font: "arial",
                heading_font: "arial",
                homepage_style: "latest",
              )

            expect { updater.update }.to change { Theme.count }.by(1)

            theme = Theme.last

            expect(theme.user_id).to eq(wizard.user.id)

            expect(theme.color_scheme).to eq(ColorScheme.find_by(name: ColorScheme::LIGHT_THEME_ID))
          end
        end
      end

      context "without an existing scheme" do
        it "creates the scheme" do
          ColorScheme.destroy_all
          updater =
            wizard.create_updater(
              "styling",
              color_scheme: "Dark",
              body_font: "arial",
              heading_font: "arial",
              homepage_style: "latest",
            )
          updater.update
          expect(updater.success?).to eq(true)
          expect(wizard.completed_steps?("styling")).to eq(true)

          color_scheme = ColorScheme.where(via_wizard: true).first
          expect(color_scheme).to be_present
          expect(color_scheme.colors).to be_present

          theme = Theme.find_by(id: SiteSetting.default_theme_id)
          expect(theme.color_scheme_id).to eq(color_scheme.id)
        end
      end

      context "with auto dark mode" do
        before do
          dark_scheme = ColorScheme.where(name: "Dark").first
          SiteSetting.default_dark_mode_color_scheme_id = dark_scheme.id
        end

        it "does nothing when selected scheme is light" do
          updater =
            wizard.create_updater(
              "styling",
              color_scheme: "Neutral",
              body_font: "arial",
              heading_font: "arial",
              homepage_style: "latest",
            )

          expect { updater.update }.not_to change { SiteSetting.default_dark_mode_color_scheme_id }
        end

        it "unsets auto dark mode site setting when default selected scheme is also dark" do
          updater =
            wizard.create_updater(
              "styling",
              color_scheme: "Latte",
              body_font: "arial",
              heading_font: "arial",
              homepage_style: "latest",
            )

          expect { updater.update }.to change { SiteSetting.default_dark_mode_color_scheme_id }.to(
            -1,
          )
        end
      end
    end

    context "with homepage style" do
      it "updates the fields correctly" do
        SiteSetting.top_menu = "latest|categories|unread|top"
        updater =
          wizard.create_updater(
            "styling",
            body_font: "arial",
            heading_font: "arial",
            homepage_style: "categories_and_top_topics",
          )
        updater.update

        expect(updater).to be_success
        expect(wizard.completed_steps?("styling")).to eq(true)
        expect(SiteSetting.top_menu).to eq("categories|latest|unread|top")
        expect(SiteSetting.desktop_category_page_style).to eq("categories_and_top_topics")

        SiteSetting.top_menu = "categories|latest|new|top"
        updater =
          wizard.create_updater(
            "styling",
            body_font: "arial",
            heading_font: "arial",
            homepage_style: "latest",
          )
        updater.update
        expect(updater).to be_success
        expect(SiteSetting.top_menu).to eq("latest|categories|new|top")
      end

      it "updates style even when categories is first in top menu" do
        SiteSetting.top_menu = "categories|new|latest"
        updater =
          wizard.create_updater(
            "styling",
            body_font: "arial",
            heading_font: "arial",
            homepage_style: "categories_with_featured_topics",
          )
        updater.update
        expect(updater).to be_success
        expect(SiteSetting.desktop_category_page_style).to eq("categories_with_featured_topics")

        updater =
          wizard.create_updater(
            "styling",
            body_font: "arial",
            heading_font: "arial",
            homepage_style: "subcategories_with_featured_topics",
          )
        updater.update
        expect(updater).to be_success
        expect(SiteSetting.desktop_category_page_style).to eq("subcategories_with_featured_topics")
      end

      it "updates top_menu if it doesn't match the new homepage_style and does nothing if it matches" do
        SiteSetting.top_menu = "categories|new|latest"

        updater =
          wizard.create_updater(
            "styling",
            body_font: "arial",
            heading_font: "arial",
            homepage_style: "hot",
          )
        updater.update
        expect(updater).to be_success
        expect(SiteSetting.top_menu).to eq("hot|categories|new|latest")

        updater =
          wizard.create_updater(
            "styling",
            body_font: "arial",
            heading_font: "arial",
            homepage_style: "hot",
          )
        updater.update
        expect(updater).to be_success
        expect(SiteSetting.top_menu).to eq("hot|categories|new|latest")

        updater =
          wizard.create_updater(
            "styling",
            body_font: "arial",
            heading_font: "arial",
            homepage_style: "latest",
          )
        updater.update
        expect(updater).to be_success
        expect(SiteSetting.top_menu).to eq("latest|hot|categories|new")
      end

      it "does not overwrite top_menu site setting" do
        SiteSetting.top_menu = "latest|unread|unseen|categories"
        updater =
          wizard.create_updater(
            "styling",
            body_font: "arial",
            heading_font: "arial",
            homepage_style: "latest",
          )
        updater.update
        expect(updater).to be_success
        expect(SiteSetting.top_menu).to eq("latest|unread|unseen|categories")

        SiteSetting.top_menu = "categories|new|latest"
        updater =
          wizard.create_updater(
            "styling",
            body_font: "arial",
            heading_font: "arial",
            homepage_style: "categories_and_top_topics",
          )
        updater.update
        expect(updater).to be_success
        expect(SiteSetting.top_menu).to eq("categories|new|latest")
      end
    end
  end

  describe "branding" do
    it "updates the fields correctly" do
      upload = Fabricate(:upload)
      upload2 = Fabricate(:upload)

      updater = wizard.create_updater("branding", logo: upload.url, logo_small: upload2.url)

      updater.update

      expect(updater).to be_success
      expect(wizard.completed_steps?("branding")).to eq(true)
      expect(SiteSetting.logo).to eq(upload)
      expect(SiteSetting.logo_small).to eq(upload2)
    end
  end

  describe "corporate" do
    it "updates the fields properly" do
      p = Fabricate(:post, raw: "company_name - governing_law - city_for_disputes template")
      SiteSetting.tos_topic_id = p.topic_id

      updater =
        wizard.create_updater(
          "corporate",
          company_name: "ACME, Inc.",
          governing_law: "New Jersey law",
          contact_url: "http://example.com/custom-contact-url",
          city_for_disputes: "Fairfield, New Jersey",
          contact_email: "eviltrout@example.com",
        )
      updater.update
      expect(updater).to be_success
      expect(SiteSetting.company_name).to eq("ACME, Inc.")
      expect(SiteSetting.governing_law).to eq("New Jersey law")
      expect(SiteSetting.contact_url).to eq("http://example.com/custom-contact-url")
      expect(SiteSetting.city_for_disputes).to eq("Fairfield, New Jersey")
      expect(SiteSetting.contact_email).to eq("eviltrout@example.com")

      # Should update the TOS topic
      raw = Post.where(topic_id: SiteSetting.tos_topic_id, post_number: 1).pick(:raw)
      expect(raw).to eq("ACME, Inc. - New Jersey law - Fairfield, New Jersey template")

      # Can update the TOS topic again
      updater =
        wizard.create_updater(
          "corporate",
          company_name: "Pied Piper Inc",
          governing_law: "California law",
          city_for_disputes: "San Francisco, California",
        )
      updater.update
      raw = Post.where(topic_id: SiteSetting.tos_topic_id, post_number: 1).pick(:raw)
      expect(raw).to eq("Pied Piper Inc - California law - San Francisco, California template")

      # Can update the TOS to nothing
      updater = wizard.create_updater("corporate", {})
      updater.update
      raw = Post.where(topic_id: SiteSetting.tos_topic_id, post_number: 1).pick(:raw)
      expect(raw).to eq("company_name - governing_law - city_for_disputes template")

      expect(wizard.completed_steps?("corporate")).to eq(true)
    end
  end
end
