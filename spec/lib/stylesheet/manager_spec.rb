# frozen_string_literal: true

require "stylesheet/compiler"

RSpec.describe Stylesheet::Manager do
  def manager(theme_id = nil)
    Stylesheet::Manager.new(theme_id: theme_id)
  end

  it "does not crash for missing theme" do
    Theme.clear_default!
    link = manager.stylesheet_link_tag(:embedded_theme)
    expect(link).to eq("")
  end

  it "still returns something for no themes" do
    link = manager.stylesheet_link_tag(:desktop, "all")
    expect(link).not_to eq("")
  end

  describe "themes with components" do
    let(:child_theme) do
      Fabricate(:theme, component: true, name: "a component").tap do |c|
        c.set_field(target: :common, name: "scss", value: ".child_common{.scss{color: red;}}")
        c.set_field(target: :desktop, name: "scss", value: ".child_desktop{.scss{color: red;}}")
        c.set_field(target: :mobile, name: "scss", value: ".child_mobile{.scss{color: red;}}")
        c.set_field(
          target: :common,
          name: "embedded_scss",
          value: ".child_embedded{.scss{color: red;}}",
        )
        c.save!
      end
    end

    let(:theme) do
      Fabricate(:theme).tap do |t|
        t.set_field(target: :common, name: "scss", value: ".common{.scss{color: red;}}")
        t.set_field(target: :desktop, name: "scss", value: ".desktop{.scss{color: red;}}")
        t.set_field(target: :mobile, name: "scss", value: ".mobile{.scss{color: red;}}")
        t.set_field(target: :common, name: "embedded_scss", value: ".embedded{.scss{color: red;}}")
        t.save!

        t.add_relative_theme!(:child, child_theme)
      end
    end

    it "generates the right links for non-theme targets" do
      manager = manager(nil)

      hrefs = manager.stylesheet_details(:desktop, "all")

      expect(hrefs.length).to eq(1)
    end

    it "can correctly compile theme css" do
      manager = manager(theme.id)
      old_links = manager.stylesheet_link_tag(:desktop_theme, "all")

      builder =
        Stylesheet::Manager::Builder.new(target: :desktop_theme, theme: theme, manager: manager)

      builder.compile(force: true)

      css = File.read(builder.stylesheet_fullpath)
      _source_map = File.read(builder.source_map_fullpath)

      expect(css).to match(/\.common/)
      expect(css).to match(/\.desktop/)

      # child theme CSS is no longer bundled with main theme
      expect(css).not_to match(/child_common/)
      expect(css).not_to match(/child_desktop/)

      child_theme_builder =
        Stylesheet::Manager::Builder.new(
          target: :desktop_theme,
          theme: child_theme,
          manager: manager,
        )

      child_theme_builder.compile(force: true)

      child_css = File.read(child_theme_builder.stylesheet_fullpath)
      _child_source_map = File.read(child_theme_builder.source_map_fullpath)

      expect(child_css).to match(/child_common/)
      expect(child_css).to match(/child_desktop/)

      child_theme.set_field(target: :desktop, name: :scss, value: ".nothing{color: green;}")
      child_theme.save!

      new_links = manager(theme.id).stylesheet_link_tag(:desktop_theme, "all")

      expect(new_links).not_to eq(old_links)

      # our theme better have a name with the theme_id as part of it
      expect(new_links).to include("/stylesheets/desktop_theme_#{theme.id}_")
      expect(new_links).to include("/stylesheets/desktop_theme_#{child_theme.id}_")
    end

    it "can correctly compile embedded theme css" do
      manager = manager(theme.id)

      builder =
        Stylesheet::Manager::Builder.new(target: :embedded_theme, theme: theme, manager: manager)

      builder.compile(force: true)

      css = File.read(builder.stylesheet_fullpath)
      expect(css).to match(/\.embedded/)
      expect(css).not_to match(/\.child_embedded/)

      child_theme_builder =
        Stylesheet::Manager::Builder.new(
          target: :embedded_theme,
          theme: child_theme,
          manager: manager,
        )

      child_theme_builder.compile(force: true)

      css = File.read(child_theme_builder.stylesheet_fullpath)
      expect(css).to match(/\.child_embedded/)
    end

    it "includes both parent and child theme assets" do
      manager = manager(theme.id)

      hrefs = manager.stylesheet_details(:desktop_theme, "all")

      expect(hrefs.count).to eq(2)

      expect(hrefs.map { |href| href[:theme_id] }).to contain_exactly(theme.id, child_theme.id)

      hrefs = manager.stylesheet_details(:embedded_theme, "all")

      expect(hrefs.count).to eq(2)

      expect(hrefs.map { |href| href[:theme_id] }).to contain_exactly(theme.id, child_theme.id)
    end

    it "includes the escaped theme name" do
      manager = manager(theme.id)

      theme.update(name: "a strange name\"with a quote in it")

      tag = manager.stylesheet_link_tag(:desktop_theme)
      expect(tag).to have_tag("link", with: { "data-theme-name" => theme.name.downcase })
      expect(tag).to have_tag("link", with: { "data-theme-name" => child_theme.name.downcase })
    end

    it "stylesheet_link_tag calls the preload callback when set" do
      preload_list = []
      preload_callback = ->(href, type) { preload_list << [href, type] }

      manager = manager(theme.id)
      expect { manager.stylesheet_link_tag(:desktop_theme, "all", preload_callback) }.to change(
        preload_list,
        :size,
      )
    end

    context "with stylesheet order" do
      let(:z_child_theme) do
        Fabricate(:theme, component: true, name: "ze component").tap do |z|
          z.set_field(target: :desktop, name: "scss", value: ".child_desktop{.scss{color: red;}}")
          z.save!
        end
      end

      let(:remote) { RemoteTheme.create!(remote_url: "https://github.com/org/remote-theme1") }

      let(:child_remote) do
        Fabricate(:theme, remote_theme: remote, component: true).tap do |t|
          t.set_field(target: :desktop, name: "scss", value: ".child_desktop{.scss{color: red;}}")
          t.save!
        end
      end

      it "output remote child, then sort children alphabetically, then local parent" do
        theme.add_relative_theme!(:child, z_child_theme)
        theme.add_relative_theme!(:child, child_remote)

        manager = manager(theme.id)
        hrefs = manager.stylesheet_details(:desktop_theme, "all")

        parent = hrefs.select { |href| href[:theme_id] == theme.id }.first
        child_a = hrefs.select { |href| href[:theme_id] == child_theme.id }.first
        child_z = hrefs.select { |href| href[:theme_id] == z_child_theme.id }.first
        child_r = hrefs.select { |href| href[:theme_id] == child_remote.id }.first

        child_local_A =
          "<link href=\"#{child_a[:new_href]}\" data-theme-id=\"#{child_a[:theme_id]}\" data-theme-name=\"#{child_a[:theme_name]}\"/>"
        child_local_Z =
          "<link href=\"#{child_z[:new_href]}\" data-theme-id=\"#{child_z[:theme_id]}\" data-theme-name=\"#{child_z[:theme_name]}\"/>"
        child_remote_R =
          "<link href=\"#{child_r[:new_href]}\" data-theme-id=\"#{child_r[:theme_id]}\" data-theme-name=\"#{child_r[:theme_name]}\"/>"
        parent_local =
          "<link href=\"#{parent[:new_href]}\" data-theme-id=\"#{parent[:theme_id]}\" data-theme-name=\"#{parent[:theme_name]}\"/>"

        link_hrefs =
          manager.stylesheet_link_tag(:desktop_theme).gsub(
            'media="all" rel="stylesheet" data-target="desktop_theme" ',
            "",
          )

        expect(link_hrefs).to eq(
          [child_remote_R, child_local_A, child_local_Z, parent_local].join("\n").html_safe,
        )
      end

      it "output remote child, remote parent, local child" do
        remote2 = RemoteTheme.create!(remote_url: "https://github.com/org/remote-theme2")
        remote_main_theme =
          Fabricate(:theme, remote_theme: remote2, name: "remote main").tap do |t|
            t.set_field(target: :desktop, name: "scss", value: ".el{color: red;}")
            t.save!
          end

        remote_main_theme.add_relative_theme!(:child, z_child_theme)
        remote_main_theme.add_relative_theme!(:child, child_remote)

        manager = manager(remote_main_theme.id)
        hrefs = manager.stylesheet_details(:desktop_theme, "all")

        parent_r = hrefs.select { |href| href[:theme_id] == remote_main_theme.id }.first
        child_z = hrefs.select { |href| href[:theme_id] == z_child_theme.id }.first
        child_r = hrefs.select { |href| href[:theme_id] == child_remote.id }.first

        parent_remote =
          "<link href=\"#{parent_r[:new_href]}\" data-theme-id=\"#{parent_r[:theme_id]}\" data-theme-name=\"#{parent_r[:theme_name]}\"/>"
        child_local =
          "<link href=\"#{child_z[:new_href]}\" data-theme-id=\"#{child_z[:theme_id]}\" data-theme-name=\"#{child_z[:theme_name]}\"/>"
        child_remote =
          "<link href=\"#{child_r[:new_href]}\" data-theme-id=\"#{child_r[:theme_id]}\" data-theme-name=\"#{child_r[:theme_name]}\"/>"

        link_hrefs =
          manager.stylesheet_link_tag(:desktop_theme).gsub(
            'media="all" rel="stylesheet" data-target="desktop_theme" ',
            "",
          )
        expect(link_hrefs).to eq([child_remote, parent_remote, child_local].join("\n").html_safe)
      end
    end

    it "outputs tags for non-theme targets for theme component" do
      child_theme = Fabricate(:theme, component: true)

      hrefs = manager(child_theme.id).stylesheet_details(:desktop, "all")

      expect(hrefs.count).to eq(1) # desktop
    end

    it "does not output tags for component targets with no styles" do
      embedded_scss_child = Fabricate(:theme, component: true)
      embedded_scss_child.set_field(
        target: :common,
        name: "embedded_scss",
        value: ".scss{color: red;}",
      )
      embedded_scss_child.save!

      theme.add_relative_theme!(:child, embedded_scss_child)

      manager = manager(theme.id)

      hrefs = manager.stylesheet_details(:desktop_theme, "all")
      expect(hrefs.count).to eq(2) # theme + child_theme

      hrefs = manager.stylesheet_details(:embedded_theme, "all")
      expect(hrefs.count).to eq(3) # theme + child_theme + embedded_scss_child
    end

    it ".stylesheet_details can find components mobile SCSS when target is `:mobile_theme`" do
      child_with_mobile_scss = Fabricate(:theme, component: true)
      child_with_mobile_scss.set_field(target: :mobile, name: :scss, value: "body { color: red; }")
      child_with_mobile_scss.save!
      theme.add_relative_theme!(:child, child_with_mobile_scss)

      manager = manager(theme.id)
      hrefs = manager.stylesheet_details(:mobile_theme, "all")

      expect(hrefs.count).to eq(3)
      expect(hrefs.find { |h| h[:theme_id] == child_with_mobile_scss.id }).to be_present
    end

    it "does not output multiple assets for non-theme targets" do
      manager = manager()

      hrefs = manager.stylesheet_details(:admin, "all")
      expect(hrefs.count).to eq(1)

      hrefs = manager.stylesheet_details(:mobile, "all")
      expect(hrefs.count).to eq(1)
    end
  end

  describe "digest" do
    after { DiscoursePluginRegistry.reset! }

    it "can correctly account for plugins in default digest" do
      builder = Stylesheet::Manager::Builder.new(target: :desktop, manager: manager)
      digest1 = builder.digest

      DiscoursePluginRegistry.stylesheets["fake"] = Set.new(["fake_file"])
      builder = Stylesheet::Manager::Builder.new(target: :desktop, manager: manager)
      digest2 = builder.digest

      expect(digest1).not_to eq(digest2)
    end

    it "can correctly account for settings in theme's components" do
      theme = Fabricate(:theme)
      child = Fabricate(:theme, component: true)
      theme.add_relative_theme!(:child, child)

      child.set_field(target: :settings, name: :yaml, value: "childcolor: red")
      child.set_field(target: :common, name: :scss, value: "body {background-color: $childcolor}")
      child.save!

      manager = manager(theme.id)

      builder =
        Stylesheet::Manager::Builder.new(target: :desktop_theme, theme: theme, manager: manager)

      digest1 = builder.digest

      child.update_setting(:childcolor, "green")

      manager = manager(theme.id)

      builder =
        Stylesheet::Manager::Builder.new(target: :desktop_theme, theme: theme, manager: manager)

      digest2 = builder.digest

      expect(digest1).not_to eq(digest2)
    end

    let(:image) { file_from_fixtures("logo.png") }
    let(:image2) { file_from_fixtures("logo-dev.png") }

    it "can correctly account for theme uploads in digest" do
      theme = Fabricate(:theme)

      upload = UploadCreator.new(image, "logo.png").create_for(-1)
      field =
        ThemeField.create!(
          theme_id: theme.id,
          target_id: Theme.targets[:common],
          name: "logo",
          value: "",
          upload_id: upload.id,
          type_id: ThemeField.types[:theme_upload_var],
        )

      manager = manager(theme.id)

      builder =
        Stylesheet::Manager::Builder.new(target: :desktop_theme, theme: theme, manager: manager)

      digest1 = builder.digest
      field.destroy!

      upload = UploadCreator.new(image2, "logo.png").create_for(-1)
      field =
        ThemeField.create!(
          theme_id: theme.id,
          target_id: Theme.targets[:common],
          name: "logo",
          value: "",
          upload_id: upload.id,
          type_id: ThemeField.types[:theme_upload_var],
        )

      builder =
        Stylesheet::Manager::Builder.new(
          target: :desktop_theme,
          theme: theme.reload,
          manager: manager,
        )

      digest2 = builder.digest

      expect(digest1).not_to eq(digest2)
    end

    it "can generate digest with a missing upload record" do
      theme = Fabricate(:theme)

      upload = UploadCreator.new(image, "logo.png").create_for(-1)
      field =
        ThemeField.create!(
          theme_id: theme.id,
          target_id: Theme.targets[:common],
          name: "logo",
          value: "",
          upload_id: upload.id,
          type_id: ThemeField.types[:theme_upload_var],
        )

      upload2 = UploadCreator.new(image2, "icon.png").create_for(-1)
      field =
        ThemeField.create!(
          theme_id: theme.id,
          target_id: Theme.targets[:common],
          name: "icon",
          value: "",
          upload_id: upload2.id,
          type_id: ThemeField.types[:theme_upload_var],
        )

      manager = manager(theme.id)

      builder =
        Stylesheet::Manager::Builder.new(target: :desktop_theme, theme: theme, manager: manager)

      digest1 = builder.digest
      upload.delete

      builder =
        Stylesheet::Manager::Builder.new(
          target: :desktop_theme,
          theme: theme.reload,
          manager: manager,
        )

      digest2 = builder.digest

      expect(digest1).not_to eq(digest2)
    end

    it "returns different digest based on target" do
      theme = Fabricate(:theme)
      builder =
        Stylesheet::Manager::Builder.new(target: :desktop_theme, theme: theme, manager: manager)
      expect(builder.digest).to eq(builder.theme_digest)

      builder = Stylesheet::Manager::Builder.new(target: :color_definitions, manager: manager)
      expect(builder.digest).to eq(builder.color_scheme_digest)

      builder = Stylesheet::Manager::Builder.new(target: :admin, manager: manager)
      expect(builder.digest).to eq(builder.default_digest)

      builder = Stylesheet::Manager::Builder.new(target: :desktop, manager: manager)
      expect(builder.digest).to eq(builder.default_digest)
    end

    it "returns different digest based on hostname" do
      theme = Fabricate(:theme)

      SiteSetting.force_hostname = "host1.example.com"
      initial_theme_digest =
        Stylesheet::Manager::Builder.new(
          target: :desktop_theme,
          theme: theme,
          manager: manager,
        ).digest
      initial_color_scheme_digest =
        Stylesheet::Manager::Builder.new(target: :color_definitions, manager: manager).digest
      initial_default_digest =
        Stylesheet::Manager::Builder.new(target: :desktop, manager: manager).digest

      SiteSetting.force_hostname = "host2.example.com"
      new_theme_digest =
        Stylesheet::Manager::Builder.new(
          target: :desktop_theme,
          theme: theme,
          manager: manager,
        ).digest
      new_color_scheme_digest =
        Stylesheet::Manager::Builder.new(target: :color_definitions, manager: manager).digest
      new_default_digest =
        Stylesheet::Manager::Builder.new(target: :desktop, manager: manager).digest

      expect(initial_theme_digest).not_to eq(new_theme_digest)
      expect(initial_color_scheme_digest).not_to eq(new_color_scheme_digest)
      expect(initial_default_digest).not_to eq(new_default_digest)
    end
  end

  describe "color_scheme_digest" do
    fab!(:theme)

    it "updates digest when updating a color scheme" do
      scheme = ColorScheme.create_from_base(name: "Neutral", base_scheme_id: "Neutral")
      manager = manager(theme.id)

      builder =
        Stylesheet::Manager::Builder.new(
          target: :color_definitions,
          theme: theme,
          color_scheme: scheme,
          manager: manager,
        )

      digest1 = builder.color_scheme_digest

      ColorSchemeRevisor.revise(scheme, colors: [{ name: "primary", hex: "CC0000" }])

      digest2 = builder.color_scheme_digest

      expect(digest1).to_not eq(digest2)
    end

    it "updates digest when updating a theme's color definitions" do
      scheme = ColorScheme.base
      manager = manager(theme.id)

      builder =
        Stylesheet::Manager::Builder.new(
          target: :color_definitions,
          theme: theme,
          color_scheme: scheme,
          manager: manager,
        )

      digest1 = builder.color_scheme_digest

      theme.set_field(target: :common, name: :color_definitions, value: "body {color: brown}")
      theme.save!

      manager = manager(theme.id)

      builder =
        Stylesheet::Manager::Builder.new(
          target: :color_definitions,
          theme: theme,
          color_scheme: scheme,
          manager: manager,
        )

      digest2 = builder.color_scheme_digest

      expect(digest1).to_not eq(digest2)
    end

    it "updates digest when updating a theme component's color definitions" do
      scheme = ColorScheme.base
      manager = manager(theme.id)

      builder =
        Stylesheet::Manager::Builder.new(
          target: :color_definitions,
          theme: theme,
          color_scheme: scheme,
          manager: manager,
        )

      digest1 = builder.color_scheme_digest

      child_theme = Fabricate(:theme, component: true)
      child_theme.set_field(
        target: :common,
        name: "color_definitions",
        value: "body {color: fuchsia}",
      )
      child_theme.save!
      theme.add_relative_theme!(:child, child_theme)
      theme.save!

      manager = manager(theme.id)

      builder =
        Stylesheet::Manager::Builder.new(
          target: :color_definitions,
          theme: theme,
          color_scheme: scheme,
          manager: manager,
        )

      digest2 = builder.color_scheme_digest
      expect(digest1).to_not eq(digest2)

      child_theme.set_field(target: :common, name: "color_definitions", value: "body {color: blue}")
      child_theme.save!

      manager = manager(theme.id)

      builder =
        Stylesheet::Manager::Builder.new(
          target: :color_definitions,
          theme: theme,
          color_scheme: scheme,
          manager: manager,
        )

      digest3 = builder.color_scheme_digest
      expect(digest2).to_not eq(digest3)
    end

    it "updates digest when setting fonts" do
      manager = manager(theme.id)
      builder =
        Stylesheet::Manager::Builder.new(target: :desktop_theme, theme: theme, manager: manager)
      digest1 = builder.color_scheme_digest
      SiteSetting.base_font = DiscourseFonts.fonts[2][:key]
      digest2 = builder.color_scheme_digest

      expect(digest1).to_not eq(digest2)

      SiteSetting.heading_font = DiscourseFonts.fonts[4][:key]
      digest3 = builder.color_scheme_digest

      expect(digest3).to_not eq(digest2)
    end
  end

  describe "color_scheme_stylesheets" do
    it "returns something by default" do
      link = manager.color_scheme_stylesheet_link_tag
      expect(link).to include("color_definitions_base")
    end

    it "does not crash when no default theme is set" do
      SiteSetting.default_theme_id = -1
      link = manager.color_scheme_stylesheet_link_tag

      expect(link).to include("color_definitions_base")
    end

    it "loads base scheme when defined scheme id is missing" do
      link = manager.color_scheme_stylesheet_link_tag(125)
      expect(link).to include("color_definitions_base")
    end

    it "loads nothing when defined dark scheme id is missing" do
      link = manager.color_scheme_stylesheet_link_tag(125, "(prefers-color-scheme: dark)")
      expect(link).to eq("")
    end

    it "uses the correct color scheme from the default site theme" do
      cs = Fabricate(:color_scheme, name: "Funky")
      theme = Fabricate(:theme, color_scheme_id: cs.id)
      SiteSetting.default_theme_id = theme.id

      link = manager.color_scheme_stylesheet_link_tag()
      expect(link).to include("/stylesheets/color_definitions_funky_#{cs.id}_")
    end

    it "uses the correct color scheme when a non-default theme is selected and it uses the base 'Light' scheme" do
      cs = Fabricate(:color_scheme, name: "Not This")
      ColorSchemeRevisor.revise(cs, colors: [{ name: "primary", hex: "CC0000" }])
      default_theme = Fabricate(:theme, color_scheme_id: cs.id)
      SiteSetting.default_theme_id = default_theme.id

      user_theme = Fabricate(:theme, color_scheme_id: nil)

      link = manager(user_theme.id).color_scheme_stylesheet_link_tag(nil, "all")
      expect(link).to include("/stylesheets/color_definitions_base_")

      stylesheet =
        Stylesheet::Manager::Builder.new(
          target: :color_definitions,
          theme: user_theme,
          manager: manager,
        ).compile(force: true)

      expect(stylesheet).not_to include("--primary: #CC0000;")
      expect(stylesheet).to include("--primary: #222222;") # from base scheme
    end

    it "uses the correct scheme when a valid scheme id is used" do
      link = manager.color_scheme_stylesheet_link_tag(ColorScheme.first.id)
      slug = Slug.for(ColorScheme.first.name) + "_" + ColorScheme.first.id.to_s
      expect(link).to include("/stylesheets/color_definitions_#{slug}_")
    end

    it "does not fail with a color scheme name containing spaces and special characters" do
      cs = Fabricate(:color_scheme, name: 'Funky Bunch -_ @#$*(')
      theme = Fabricate(:theme, color_scheme_id: cs.id)
      SiteSetting.default_theme_id = theme.id

      link = manager.color_scheme_stylesheet_link_tag
      expect(link).to include("/stylesheets/color_definitions_funky-bunch_#{cs.id}_")
    end

    it "updates outputted colors when updating a color scheme" do
      scheme = ColorScheme.create_from_base(name: "Neutral", base_scheme_id: "Neutral")
      theme = Fabricate(:theme)
      manager = manager(theme.id)

      builder =
        Stylesheet::Manager::Builder.new(
          target: :color_definitions,
          theme: theme,
          color_scheme: scheme,
          manager: manager,
        )
      stylesheet = builder.compile

      ColorSchemeRevisor.revise(scheme, colors: [{ name: "primary", hex: "CC0000" }])

      builder2 =
        Stylesheet::Manager::Builder.new(
          target: :color_definitions,
          theme: theme,
          color_scheme: scheme,
          manager: manager,
        )

      stylesheet2 = builder2.compile

      expect(stylesheet).not_to eq(stylesheet2)
      expect(stylesheet2).to include("--primary: #CC0000;")
    end

    it "includes updated font definitions" do
      details1 = manager.color_scheme_stylesheet_details(nil, "all")

      SiteSetting.base_font = DiscourseFonts.fonts[2][:key]

      details2 = manager.color_scheme_stylesheet_details(nil, "all")
      expect(details1[:new_href]).not_to eq(details2[:new_href])
    end

    it "calls the preload callback when set" do
      preload_list = []
      cs = Fabricate(:color_scheme, name: "Funky")
      theme = Fabricate(:theme, color_scheme_id: cs.id)
      preload_callback = ->(href, type) { preload_list << [href, type] }

      expect {
        manager.color_scheme_stylesheet_link_tag(theme.id, "all", preload_callback)
      }.to change(preload_list, :size).by(1)
    end

    context "with theme colors" do
      let(:theme) do
        Fabricate(:theme).tap do |t|
          t.set_field(
            target: :common,
            name: "color_definitions",
            value: ":root {--special: rebeccapurple;}",
          )
          t.save!
        end
      end
      let(:scss_child) { ':root {--child-definition: #{dark-light-choose(#c00, #fff)};}' }
      let(:child) do
        Fabricate(:theme, component: true, name: "Child Theme").tap do |t|
          t.set_field(target: :common, name: "color_definitions", value: scss_child)
          t.save!
        end
      end

      let(:scheme) { ColorScheme.base }
      let(:dark_scheme) { ColorScheme.create_from_base(name: "Dark", base_scheme_id: "Dark") }

      it "includes theme color definitions in color scheme" do
        manager = manager(theme.id)

        stylesheet =
          Stylesheet::Manager::Builder.new(
            target: :color_definitions,
            theme: theme,
            color_scheme: scheme,
            manager: manager,
          ).compile(force: true)

        expect(stylesheet).to include("--special: rebeccapurple")
      end

      it "includes child color definitions in color schemes" do
        theme.add_relative_theme!(:child, child)
        theme.save!
        manager = manager(theme.id)

        stylesheet =
          Stylesheet::Manager::Builder.new(
            target: :color_definitions,
            theme: theme,
            color_scheme: scheme,
            manager: manager,
          ).compile(force: true)

        expect(stylesheet).to include("--special: rebeccapurple")
        expect(stylesheet).to include("--child-definition: #c00")
      end

      it "respects selected color scheme in child color definitions" do
        theme.add_relative_theme!(:child, child)
        theme.save!

        manager = manager(theme.id)

        stylesheet =
          Stylesheet::Manager::Builder.new(
            target: :color_definitions,
            theme: theme,
            color_scheme: dark_scheme,
            manager: manager,
          ).compile(force: true)

        expect(stylesheet).to include("--special: rebeccapurple")
        expect(stylesheet).to include("--child-definition: #fff")
      end

      it "fails gracefully for broken SCSS" do
        scss = "$test: $missing-var;"
        theme.set_field(target: :common, name: "color_definitions", value: scss)
        theme.save!

        manager = manager(theme.id)

        stylesheet =
          Stylesheet::Manager::Builder.new(
            target: :color_definitions,
            theme: theme,
            color_scheme: scheme,
            manager: manager,
          )

        expect { stylesheet.compile }.not_to raise_error
      end

      it "child theme SCSS includes the default theme's color scheme variables" do
        SiteSetting.default_theme_id = theme.id
        custom_scheme = ColorScheme.create_from_base(name: "Neutral", base_scheme_id: "Neutral")
        ColorSchemeRevisor.revise(custom_scheme, colors: [{ name: "primary", hex: "CC0000" }])
        theme.color_scheme_id = custom_scheme.id
        theme.save!

        scss = "body{ border: 2px solid $primary;}"
        child.set_field(target: :common, name: "scss", value: scss)
        child.save!

        manager = manager(theme.id)

        child_theme_manager =
          Stylesheet::Manager::Builder.new(target: :desktop_theme, theme: child, manager: manager)

        child_theme_manager.compile(force: true)

        child_css = File.read(child_theme_manager.stylesheet_fullpath)
        expect(child_css).to include("body{border:2px solid #c00}")
      end
    end

    context "with encoded slugs" do
      before { SiteSetting.slug_generation_method = "encoded" }
      after { SiteSetting.slug_generation_method = "ascii" }

      it "strips unicode in color scheme stylesheet filenames" do
        cs = Fabricate(:color_scheme, name: "Grün")
        cs2 = Fabricate(:color_scheme, name: "어두운")

        link = manager.color_scheme_stylesheet_link_tag(cs.id)
        expect(link).to include("/stylesheets/color_definitions_grun_#{cs.id}_")
        link2 = manager.color_scheme_stylesheet_link_tag(cs2.id)
        expect(link2).to include("/stylesheets/color_definitions_scheme_#{cs2.id}_")
      end
    end
  end

  describe ".precompile_css" do
    let(:core_targets) do
      %w[desktop mobile admin wizard desktop_rtl mobile_rtl admin_rtl wizard_rtl]
    end

    let(:theme_targets) { %i[desktop_theme mobile_theme] }

    before do
      STDERR.stubs(:write)
      StylesheetCache.destroy_all
      default_theme.set_default!
    end

    after do
      STDERR.unstub(:write)
      Stylesheet::Manager.rm_cache_folder
    end

    fab!(:scheme1) { ColorScheme.create!(name: "scheme1") }
    fab!(:scheme2) { ColorScheme.create!(name: "scheme2") }

    fab!(:user_theme) { Fabricate(:theme, user_selectable: true, color_scheme: scheme1) }
    fab!(:default_theme) { Fabricate(:theme, user_selectable: true, color_scheme: scheme2) }
    fab!(:child_theme) do
      Fabricate(:theme).tap do |t|
        t.component = true
        t.save!
        user_theme.add_relative_theme!(:child, t)
      end
    end
    fab!(:child_theme_with_css) do
      Fabricate(:theme).tap do |t|
        t.component = true
        t.set_field(target: :common, name: :scss, value: "body { background: green }")
        t.save!
        user_theme.add_relative_theme!(:child, t)
        default_theme.add_relative_theme!(:child, t)
      end
    end

    it "generates precompiled CSS - only core" do
      capture_output(:stderr) { Stylesheet::Manager.precompile_css }

      expect(StylesheetCache.pluck(:target)).to contain_exactly(*core_targets)
    end

    it "generates precompiled CSS - only themes" do
      output = capture_output(:stderr) { Stylesheet::Manager.precompile_theme_css }

      # Ensure we force compile each theme only once
      expect(output.scan(/#{child_theme_with_css.name}/).length).to eq(2)
      expect(StylesheetCache.count).to eq(22) # (3 themes * 2 targets) + 16 color schemes (2 themes * 8 color schemes (7 defaults + 1 theme scheme))
    end

    it "generates precompiled CSS - core and themes" do
      Stylesheet::Manager.precompile_css
      Stylesheet::Manager.precompile_theme_css

      results = StylesheetCache.pluck(:target)
      expect(results.size).to eq(30) # 11 core targets + 9 theme + 10 color schemes

      theme_targets.each do |tar|
        expect(
          results.count { |target| target =~ /^#{tar}_(#{user_theme.id}|#{default_theme.id})$/ },
        ).to eq(2)
      end
    end

    it "correctly generates precompiled CSS - core and themes and no default theme" do
      Theme.clear_default!

      Stylesheet::Manager.precompile_css
      Stylesheet::Manager.precompile_theme_css

      results = StylesheetCache.pluck(:target)
      expect(results.size).to eq(30) # 11 core targets + 9 theme + 10 color schemes

      expect(results).to include("color_definitions_#{scheme1.name}_#{scheme1.id}_#{user_theme.id}")
      expect(results).to include(
        "color_definitions_#{scheme2.name}_#{scheme2.id}_#{default_theme.id}",
      )

      # Check that sourceMappingURL includes __ws parameter
      content = StylesheetCache.last.content
      expect(content).to match(%r{# sourceMappingURL=[^/]+\.css\.map\?__ws=test\.localhost})
    end

    it "generates precompiled CSS with a missing upload" do
      image = file_from_fixtures("logo.png")
      upload = UploadCreator.new(image, "logo.png").create_for(-1)

      ThemeField.create!(
        theme_id: default_theme.id,
        target_id: Theme.targets[:common],
        name: "logo",
        value: "",
        upload_id: upload.id,
        type_id: ThemeField.types[:theme_upload_var],
      )

      default_theme.set_field(
        target: :common,
        name: :scss,
        value: "body { background: url($logo); border: 3px solid green; }",
      )

      default_theme.save!

      upload.destroy!

      Stylesheet::Manager.precompile_theme_css

      manager = manager(default_theme.id)
      theme_builder =
        Stylesheet::Manager::Builder.new(
          target: :desktop_theme,
          theme: default_theme,
          manager: manager,
        )
      css = File.read(theme_builder.stylesheet_fullpath)
      expect(css).to include("border:3px solid green}")
    end

    context "when there are enabled plugins" do
      let(:plugin1) do
        plugin1 = plugin_from_fixtures("my_plugin")
        plugin1.register_css "body { padding: 1px 2px 3px 4px; }"
        plugin1
      end

      let(:plugin2) do
        plugin2 = plugin_from_fixtures("scss_plugin")
        plugin2
      end

      before do
        Discourse.plugins << plugin1
        Discourse.plugins << plugin2
        plugin1.activate!
        plugin2.activate!
        Stylesheet::Importer.register_imports!
        StylesheetCache.destroy_all
      end

      after do
        Discourse.plugins.delete(plugin1)
        Discourse.plugins.delete(plugin2)
        Stylesheet::Importer.register_imports!
        DiscoursePluginRegistry.reset!
      end

      it "generates LTR and RTL CSS for plugins" do
        output = capture_output(:stderr) { Stylesheet::Manager.precompile_css }

        results = StylesheetCache.pluck(:target)
        expect(results).to contain_exactly(
          *core_targets,
          "my_plugin",
          "my_plugin_rtl",
          "scss_plugin",
          "scss_plugin_rtl",
        )

        expect(output.scan(/my_plugin$/).length).to eq(1)
        expect(output.scan(/my_plugin_rtl$/).length).to eq(1)
        expect(output.scan(/scss_plugin$/).length).to eq(1)
        expect(output.scan(/scss_plugin_rtl$/).length).to eq(1)

        plugin1_ltr_css = StylesheetCache.where(target: "my_plugin").pluck(:content).first
        plugin1_rtl_css = StylesheetCache.where(target: "my_plugin_rtl").pluck(:content).first

        expect(plugin1_ltr_css).to include("body{padding:1px 2px 3px 4px}")
        expect(plugin1_ltr_css).not_to include("body{padding:1px 4px 3px 2px}")
        expect(plugin1_rtl_css).to include("body{padding:1px 4px 3px 2px}")
        expect(plugin1_rtl_css).not_to include("body{padding:1px 2px 3px 4px}")

        plugin2_ltr_css = StylesheetCache.where(target: "scss_plugin").pluck(:content).first
        plugin2_rtl_css = StylesheetCache.where(target: "scss_plugin_rtl").pluck(:content).first

        expect(plugin2_ltr_css).to include(".pull-left{float:left}")
        expect(plugin2_ltr_css).not_to include(".pull-left{float:right}")
        expect(plugin2_rtl_css).to include(".pull-left{float:right}")
        expect(plugin2_rtl_css).not_to include(".pull-left{float:left}")
      end
    end
  end

  describe ".fs_asset_cachebuster" do
    it "returns a number in test/development mode" do
      expect(Stylesheet::Manager.fs_asset_cachebuster).to match(/\A.*:[0-9]+\z/)
    end

    context "with production mode enabled" do
      before { Stylesheet::Manager.stubs(:use_file_hash_for_cachebuster?).returns(true) }

      after do
        path = Stylesheet::Manager.send(:manifest_full_path)
        File.delete(path) if File.exist?(path)
      end

      it "returns a hash" do
        cachebuster = Stylesheet::Manager.fs_asset_cachebuster
        expect(cachebuster).to match(/\A.*:[0-9a-f]{40}\z/)
      end

      it "caches the value on the filesystem" do
        initial_cachebuster = Stylesheet::Manager.recalculate_fs_asset_cachebuster!
        Stylesheet::Manager.stubs(:list_files).never
        expect(Stylesheet::Manager.fs_asset_cachebuster).to eq(initial_cachebuster)
        expect(File.read(Stylesheet::Manager.send(:manifest_full_path))).to eq(initial_cachebuster)
      end

      it "updates the hash when a file changes" do
        original_files = Stylesheet::Manager.send(:list_files)
        initial_cachebuster = Stylesheet::Manager.recalculate_fs_asset_cachebuster!

        additional_file_path =
          "#{Rails.root}/spec/fixtures/plugins/scss_plugin/assets/stylesheets/colors.scss"
        Stylesheet::Manager.stubs(:list_files).returns(original_files + [additional_file_path])

        new_cachebuster = Stylesheet::Manager.recalculate_fs_asset_cachebuster!
        expect(new_cachebuster).not_to eq(initial_cachebuster)
      end
    end
  end
end
