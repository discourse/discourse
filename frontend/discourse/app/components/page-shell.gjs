import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { service } from "@ember/service";
import PageShellControls from "discourse/components/page-shell/controls";
import bodyClass from "discourse/helpers/body-class";
import measurePageShell from "discourse/modifiers/measure-page-shell";
import { i18n } from "discourse-i18n";

export default class PageShell extends Component {
  @service pageShell;

  <template>
    {{#if this.pageShell.enabled}}
      {{bodyClass
        "has-page-shell"
        (if (eq this.pageShell.width "full") "full-width-enabled")
        (if
          (and @sidebarEnabled (not (eq this.pageShell.navigation "hidden")))
          "has-sidebar-page"
        )
      }}

      <PageShellControls />

      {{yield to="beforeHeader"}}
      <div
        class="page-shell"
        data-context={{if
          this.pageShell.hasContextPanel
          this.pageShell.context
          "hidden"
        }}
        data-footer={{this.pageShell.footer}}
        data-navigation={{if
          @sidebarEnabled
          this.pageShell.navigation
          "hidden"
        }}
        data-width={{this.pageShell.width}}
        id="main-outlet-wrapper"
        {{measurePageShell
          this.pageShell.width
          this.pageShell.navigation
          this.pageShell.context
          this.pageShell.navigationWidth
          this.pageShell.contextWidth
        }}
      >
        {{yield to="header"}}
        <div class="page-shell__notices">
          {{yield to="beforeBody"}}
        </div>
        {{yield to="navigation"}}
        <main class="page-shell__main" id="main-outlet">
          {{yield to="beforeMain"}}
          <div class="page-shell__main-content">
            {{yield to="main"}}
          </div>
          {{yield to="afterMain"}}
        </main>
        <footer class="page-shell__footer">
          <div class="page-shell__footer-content">
            {{yield to="footer"}}
            {{#if @showFooter}}
              <div class="page-shell__footer-sample">
                {{i18n "page_shell.footer_description"}}
              </div>
            {{/if}}
          </div>
        </footer>
        {{#if
          (and
            this.pageShell.hasContextPanel
            (not (eq this.pageShell.context "hidden"))
          )
        }}
          <aside
            aria-label={{i18n "page_shell.context"}}
            class="page-shell__context"
          >
            <div class="page-shell__context-content">
              {{#if (eq this.pageShell.context "rail")}}
                <button
                  class="btn btn-flat"
                  title={{i18n "page_shell.expand_context"}}
                  type="button"
                  {{on "click" this.pageShell.openContext}}
                >
                  {{i18n "page_shell.expand"}}
                </button>
              {{else}}
                <h2>{{i18n "page_shell.context"}}</h2>
                <p>{{i18n "page_shell.context_description"}}</p>
              {{/if}}
            </div>
          </aside>
        {{/if}}
        {{yield to="composer"}}
      </div>
    {{else}}
      {{yield to="beforeHeader"}}
      {{yield to="header"}}
      {{yield to="beforeBody"}}
      <div class="wrap" id="main-outlet-wrapper" role="main">
        {{yield to="navigation"}}
        {{yield to="beforeMain"}}
        <div id="main-outlet">
          {{yield to="main"}}
        </div>
        {{yield to="afterMain"}}
        {{yield to="composer"}}
      </div>
      {{yield to="footer"}}
    {{/if}}
  </template>
}
