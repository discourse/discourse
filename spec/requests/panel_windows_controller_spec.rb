# frozen_string_literal: true

RSpec.describe PanelWindowsController do
  fab!(:user)

  let(:key) { "dev-tools" }
  let(:doc) { Nokogiri.HTML5(response.body) }

  def window
    doc.at_css(".d-panel-dock-window")
  end

  describe "#show" do
    it "serves a document marked with the panel's key" do
      get "/panel-window/#{key}"

      expect(response.status).to eq(200)
      expect(doc.at_css("html")["data-d-panel-dock"]).to eq(key)
    end

    it "renders the mount, the note, both float outlets and the sprite container" do
      get "/panel-window/#{key}"

      expect(window).to be_present

      mount = window.at_css(".d-panel-dock-window__mount")
      expect(mount).to be_present
      expect(mount.name).to eq("main")

      # Both ids are resolved by float-kit against the window's own document, and
      # the class is what keeps the outlets out of the column layout. Neither is
      # decorative, so both are asserted.
      %w[d-menu-portals d-tooltip-portals].each do |id|
        outlet = window.at_css("##{id}")
        expect(outlet).to be_present, "expected ##{id} in the shell"
        expect(outlet["class"]).to include("d-panel-dock-window__portals")
      end

      sprites = window.at_css(".d-panel-dock-window__sprites")
      expect(sprites).to be_present
      expect(sprites.attributes).to have_key("hidden")
      expect(sprites.text.strip).to be_empty
    end

    it "renders the note empty, hidden, and as a well-formed live region" do
      get "/panel-window/#{key}"

      note = window.at_css(".d-panel-dock-window__reconnecting")
      expect(note).to be_present
      expect(note.attributes).to have_key("hidden")

      # A sibling of the mount, never a child: `.is-reconnecting` hides the mount,
      # so a nested note could never be shown.
      expect(note.parent["class"]).to include("d-panel-dock-window")

      status = note.at_css("[role='status']")
      expect(status).to be_present
      expect(status["aria-live"]).to eq("polite")
      expect(status["aria-atomic"]).to eq("true")

      # The opener writes the text when the event happens. A live region that is
      # already populated at load and merely unhidden does not reliably announce.
      expect(status.text.strip).to be_empty

      # The heading is the opposite case, and the reason the note is served at all:
      # it has to say what the window is once the page that owned it is gone, at
      # which point nothing is left to write it in.
      expect(note.at_css(".empty-state__title").text.strip).to eq(
        I18n.t("panel_dock.window_reconnecting_title"),
      )
    end

    it "places the shell's children in the order the opener expects" do
      get "/panel-window/#{key}"

      classes =
        window.element_children.map { |node| node["id"].presence || node["class"].to_s.split.first }

      expect(classes).to eq(
        %w[
          d-panel-dock-window__mount
          d-panel-dock-window__reconnecting
          d-menu-portals
          d-tooltip-portals
          d-panel-dock-window__sprites
        ],
      )
    end

    it "exposes exactly one main landmark" do
      get "/panel-window/#{key}"

      expect(doc.css("main").length).to eq(1)
    end

    it "runs no script of its own" do
      get "/panel-window/#{key}"

      # The shell is deliberately inert: everything in this window belongs to the
      # page that opened it. A script here would need a CSP nonce and would run in
      # a document with no application in it.
      expect(doc.css("script")).to be_empty
    end

    it "carries the site's stylesheets and both colour schemes" do
      get "/panel-window/#{key}"

      hrefs = doc.css("link[rel='stylesheet']").map { |link| link["href"] }
      expect(hrefs).to be_present
      expect(hrefs.any? { |href| href.include?("color_definitions") }).to eq(true)
    end

    it "carries the root and body classes the panel's CSS keys off" do
      get "/panel-window/#{key}"

      expect(doc.at_css("html")["lang"]).to be_present
      # `anon` is the cheapest observable member of `html_classes`.
      expect(doc.at_css("html")["class"]).to include("anon")
      expect(doc.at_css("body")["class"]).not_to be_nil
    end

    it "renders no application chrome" do
      get "/panel-window/#{key}"

      expect(doc.at_css("#main-outlet")).to be_nil
      expect(doc.at_css("header.d-header")).to be_nil
      expect(doc.at_css("#svg-sprites")).to be_nil
    end

    it "sets the robots header" do
      get "/panel-window/#{key}"

      expect(response.headers["X-Robots-Tag"]).to eq("noindex, nofollow")
    end

    it "never renders theme HTML, so a theme cannot break the shell" do
      theme = Fabricate(:theme)
      theme.set_field(target: :common, name: "head_tag", value: "<b>custom head</b>")
      theme.set_field(target: :common, name: "header", value: "custom header")
      theme.save!
      theme.set_default!

      get "/panel-window/#{key}"

      expect(response.body).not_to include("custom head")
      expect(response.body).not_to include("custom header")
    end

    describe "the opener relationship" do
      it "receives the same cross-origin-opener-policy as a normal page load" do
        # The opener's COOP is fixed when it loads. If this document's differs,
        # the browser puts them in different browsing context groups and severs
        # `window.opener` — which is the only thing the panel is rendered through.
        sign_in(user)

        get "/latest"
        spa_boot = response.headers["Cross-Origin-Opener-Policy"]

        get "/panel-window/#{key}"

        expect(response.headers["Cross-Origin-Opener-Policy"]).to eq(spa_boot)
      end
    end

    describe "the key" do
      it "accepts the keys the ui-kit actually ships" do
        %w[dev-tools styleguide-tabbed-dock styleguide-single-panel ember123].each do |valid|
          get "/panel-window/#{valid}"
          expect(response.status).to eq(200), "expected #{valid} to be served"
        end
      end

      it "refuses a key that could not survive a URL, a window name and a storage key" do
        # Percent-encoded rather than raw: Rack::Test rejects a bare space in the
        # URI before Rails routing runs, which would prove nothing about the
        # constraint under test.
        ["a/b", "-leading", "_leading", "with%20space", "a" * 65, ""].each do |invalid|
          get "/panel-window/#{invalid}"
          expect(response.status).to eq(404), "expected #{invalid.inspect} to be refused"
        end
      end
    end

    context "when the site requires login" do
      before { SiteSetting.login_required = true }

      it "redirects an anonymous reader rather than serving a shell" do
        get "/panel-window/#{key}"

        expect(response.status).to eq(302)
        expect(doc.at_css("html[data-d-panel-dock]")).to be_nil
      end

      it "still serves a signed-in reader" do
        sign_in(user)

        get "/panel-window/#{key}"

        expect(response.status).to eq(200)
      end
    end
  end
end
