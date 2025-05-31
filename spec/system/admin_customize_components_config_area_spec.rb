# frozen_string_literal: true

describe "Admin Customize Themes Config Area Page", type: :system do
  fab!(:admin)
  fab!(:parent_theme) { Fabricate(:theme, name: "A theme") }
  fab!(:parent_theme_2) { Fabricate(:theme, name: "B theme") }
  fab!(:parent_theme_3) { Fabricate(:theme, name: "C theme") }
  fab!(:parent_theme_4) { Fabricate(:theme, name: "D theme") }

  let(:config_area) { PageObjects::Pages::AdminCustomizeComponentsConfigArea.new }
  let(:toasts) { PageObjects::Components::Toasts.new }
  let(:dialog) { PageObjects::Components::Dialog.new }

  before { sign_in(admin) }

  context "when there are components installed" do
    fab!(:enabled_component) do
      Fabricate(
        :theme,
        name: "Glorious component",
        component: true,
        enabled: true,
        parent_themes: [parent_theme, parent_theme_2, parent_theme_3, parent_theme_4],
      )
    end
    fab!(:disabled_component) do
      Fabricate(:theme, name: "Glossy component", component: true, enabled: false)
    end
    fab!(:remote_component) do
      Fabricate(
        :theme,
        component: true,
        enabled: false,
        parent_themes: [parent_theme_3],
        remote_theme:
          RemoteTheme.create!(
            remote_url: "https://github.com/discourse/tc-1.git",
            authors: "CDCK Inc.",
          ),
        theme_fields: [
          ThemeField.new(
            name: "en",
            type_id: ThemeField.types[:yaml],
            target_id: Theme.targets[:translations],
            value: <<~YAML,
            en:
              theme_metadata:
                description: "Description of my remote component"
          YAML
          ),
        ],
      )
    end
    fab!(:remote_component_with_update) do
      Fabricate(
        :theme,
        component: true,
        enabled: false,
        remote_theme:
          RemoteTheme.create!(
            remote_url: "https://github.com/discourse/discourse-kanban-theme.git",
            commits_behind: 4,
          ),
      )
    end

    it "can enable/disable components" do
      config_area.visit

      expect(config_area.component(enabled_component.id).enabled_toggle).to be_checked
      expect(config_area.component(disabled_component.id).enabled_toggle).to be_unchecked

      config_area.component(enabled_component.id).enabled_toggle.toggle
      config_area.component(disabled_component.id).enabled_toggle.toggle

      expect(config_area.component(enabled_component.id).enabled_toggle).to be_unchecked
      expect(config_area.component(disabled_component.id).enabled_toggle).to be_checked

      expect(enabled_component.reload.enabled).to eq(false)
      expect(disabled_component.reload.enabled).to eq(true)
    end

    it "can filter components by status" do
      config_area.visit
      config_area.status_selector.select("used")

      expect(config_area).to have_exact_components(enabled_component.id, remote_component.id)

      config_area.status_selector.select("unused")

      expect(config_area).to have_exact_components(
        disabled_component.id,
        remote_component_with_update.id,
      )

      config_area.status_selector.select("updates_available")

      expect(config_area).to have_exact_components(remote_component_with_update.id)
    end

    it "can filter components by name" do
      config_area.visit

      config_area.name_filter_input.fill_in(with: "glo")

      expect(config_area).to have_exact_components(enabled_component.id, disabled_component.id)
    end

    it "keeps the filters shown when there are no components matching the filters" do
      config_area.visit

      config_area.name_filter_input.fill_in(with: "stringthatshouldnotmatchanything")
      expect(config_area).to have_no_components_found_text
      expect(config_area).to have_no_components
      expect(config_area).to have_name_filter_input
      expect(config_area).to have_status_selector
    end

    it "navigates to the component page when clicking the Edit button" do
      config_area.visit

      config_area.component(enabled_component.id).edit_button.click
      expect(page).to have_current_path("/admin/customize/themes/#{enabled_component.id}")
    end

    it "displays various metadata for components" do
      disabled_component.update!(parent_themes: [parent_theme])
      remote_component.update!(parent_themes: [parent_theme, parent_theme_2])
      remote_component_with_update.update!(
        parent_themes: [parent_theme, parent_theme_2, parent_theme_3],
      )

      config_area.visit

      expect(config_area.component(remote_component.id)).to have_author("CDCK Inc.")
      expect(config_area.component(remote_component.id)).to have_description(
        "Description of my remote component",
      )
      expect(config_area.component(remote_component_with_update.id)).to have_description(
        "Display and organize topics using a Kanban board interface.",
      )
      expect(config_area.component(remote_component.id)).to be_not_pending_update

      expect(config_area.component(remote_component_with_update.id)).to be_pending_update

      expect(config_area.component(disabled_component.id)).to have_one_parent_theme("A theme")
      expect(config_area.component(remote_component.id)).to have_two_parent_themes(
        "A theme",
        "B theme",
      )
      expect(config_area.component(remote_component_with_update.id)).to have_three_parent_themes(
        "A theme",
        "B theme",
        "C theme",
      )
      expect(config_area.component(enabled_component.id)).to have_three_and_more_parent_themes(
        "A theme",
        "B theme",
        "C theme",
        1,
      )
    end

    it "shows actions that make sense for each component" do
      config_area.visit

      config_area.component(enabled_component.id).more_actions_menu.expand
      expect(config_area.component(enabled_component.id)).to have_no_check_for_updates_button
      expect(config_area.component(enabled_component.id)).to have_no_update_button
      expect(config_area.component(enabled_component.id).preview_button["href"]).to end_with(
        "/admin/themes/#{enabled_component.id}/preview",
      )
      expect(config_area.component(enabled_component.id).export_button["href"]).to end_with(
        "/admin/customize/themes/#{enabled_component.id}/export",
      )
      config_area.component(enabled_component.id).more_actions_menu.collapse

      config_area.component(disabled_component.id).more_actions_menu.expand
      expect(config_area.component(disabled_component.id)).to have_no_check_for_updates_button
      expect(config_area.component(disabled_component.id)).to have_no_update_button
      expect(config_area.component(disabled_component.id).preview_button["href"]).to end_with(
        "/admin/themes/#{disabled_component.id}/preview",
      )
      expect(config_area.component(disabled_component.id).export_button["href"]).to end_with(
        "/admin/customize/themes/#{disabled_component.id}/export",
      )
      config_area.component(disabled_component.id).more_actions_menu.collapse

      config_area.component(remote_component.id).more_actions_menu.expand
      expect(config_area.component(remote_component.id)).to have_check_for_updates_button
      expect(config_area.component(remote_component.id)).to have_no_update_button
      expect(config_area.component(remote_component.id).preview_button["href"]).to end_with(
        "/admin/themes/#{remote_component.id}/preview",
      )
      expect(config_area.component(remote_component.id).export_button["href"]).to end_with(
        "/admin/customize/themes/#{remote_component.id}/export",
      )
      config_area.component(remote_component.id).more_actions_menu.collapse

      config_area.component(remote_component_with_update.id).more_actions_menu.expand
      expect(
        config_area.component(remote_component_with_update.id),
      ).to have_no_check_for_updates_button
      expect(config_area.component(remote_component_with_update.id)).to have_update_button
      expect(
        config_area.component(remote_component_with_update.id).preview_button["href"],
      ).to end_with("/admin/themes/#{remote_component_with_update.id}/preview")
      expect(
        config_area.component(remote_component_with_update.id).export_button["href"],
      ).to end_with("/admin/customize/themes/#{remote_component_with_update.id}/export")
      config_area.component(remote_component_with_update.id).more_actions_menu.collapse
    end

    it "can delete a component" do
      config_area.visit

      config_area.component(disabled_component.id).more_actions_menu.expand
      config_area.component(disabled_component.id).delete_button.click

      dialog.click_danger

      expect(toasts).to have_success(
        I18n.t(
          "admin_js.admin.config_areas.themes_and_components.components.deleted_successfully",
          name: disabled_component.name,
        ),
      )
      expect(Theme.find_by(id: disabled_component.id)).to eq(nil)
      expect(config_area).to have_no_component(disabled_component.id)
    end

    describe "checking for updates" do
      let(:repo) do
        setup_git_repo("about.json" => { name: "discourse-component-tt1", component: true }.to_json)
      end

      let(:url) do
        MockGitImporter.register("https://example.com/discourse-component-tt1.git", repo)
      end

      before do
        remote_component.remote_theme.update!(remote_url: url)
        remote_component.remote_theme.update_from_remote
      end

      after { `rm -fr #{repo}` }

      around(:each) { |group| MockGitImporter.with_mock { group.run } }

      it 'shows an "Update to latest" button if there is a new update' do
        config_area.visit
        config_area.component(remote_component.id).more_actions_menu.expand

        add_to_git_repo(repo, "about.json" => { name: "updated-name", component: true }.to_json)

        config_area.component(remote_component.id).check_for_updates_button.click

        expect(toasts).to have_default(
          I18n.t(
            "admin_js.admin.config_areas.themes_and_components.components.new_update_for_component",
            name: remote_component.name,
          ),
        )
        expect(config_area.component(remote_component.id)).to have_update_button
        expect(config_area.component(remote_component.id)).to be_pending_update
      end

      it 'keeps the "Check for updates" button if there is no new update' do
        config_area.visit
        config_area.component(remote_component.id).more_actions_menu.expand

        config_area.component(remote_component.id).check_for_updates_button.click

        expect(toasts).to have_default(
          I18n.t(
            "admin_js.admin.config_areas.themes_and_components.components.component_up_to_date",
            name: remote_component.name,
          ),
        )
        expect(config_area.component(remote_component.id)).to have_check_for_updates_button
        expect(config_area.component(remote_component.id)).to be_not_pending_update
      end
    end

    describe "performing an update" do
      let(:repo) do
        setup_git_repo("about.json" => { name: "discourse-component-tt2", component: true }.to_json)
      end

      let(:url) do
        MockGitImporter.register("https://example.com/discourse-component-tt2.git", repo)
      end

      before do
        remote_component_with_update.remote_theme.update!(remote_url: url)
        remote_component_with_update.remote_theme.update_from_remote

        add_to_git_repo(repo, "about.json" => { name: "updated-name-tt2", component: true }.to_json)
        remote_component_with_update.remote_theme.update_remote_version
      end

      after { `rm -fr #{repo}` }

      around(:each) { |group| MockGitImporter.with_mock { group.run } }

      it 'shows the "Check for updates" button after updating' do
        config_area.visit

        config_area.component(remote_component_with_update.id).more_actions_menu.expand
        config_area.component(remote_component_with_update.id).update_button.click

        expect(toasts).to have_success(
          I18n.t(
            "admin_js.admin.config_areas.themes_and_components.components.updated_successfully",
            name: remote_component_with_update.name,
          ),
        )
        expect(
          config_area.component(remote_component_with_update.id),
        ).to have_check_for_updates_button
        expect(config_area.component(remote_component_with_update.id)).to be_not_pending_update
      end
    end

    it "loads more components when scrolling to the bottom" do
      Fabricate.times(4, :theme, component: true)

      stub_const(Admin::Config::CustomizeController, "PAGE_SIZE", 4) do
        resize_window(height: 800) do
          config_area.visit

          expect(config_area).to have_exactly_n_components(4)

          page.execute_script("window.scrollTo(0, document.body.scrollHeight)")

          expect(config_area).to have_component(enabled_component.id)

          expect(config_area).to have_exactly_n_components(8)
        end
      end
    end
  end

  context "when there are no components installed" do
    it "doesn't display filters when there are no components installed" do
      config_area.visit

      expect(config_area).to have_no_components_installed_text
      expect(config_area).to have_no_components
      expect(config_area).to have_no_status_selector
      expect(config_area).to have_no_name_filter_input
    end
  end
end
