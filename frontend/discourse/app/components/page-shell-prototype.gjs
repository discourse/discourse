import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { service } from "@ember/service";
import bodyClass from "discourse/helpers/body-class";
import measurePageShellPrototype from "discourse/modifiers/measure-page-shell-prototype";
import { i18n } from "discourse-i18n";

export default class PageShellPrototype extends Component {
  @service pageShellPrototype;

  <template>
    {{#if this.pageShellPrototype.enabled}}
      {{bodyClass
        "page-shell-prototype-active"
        (if (eq this.pageShellPrototype.width "full") "full-width-enabled")
        (if
          (and
            @sidebarEnabled
            (not (eq this.pageShellPrototype.navigation "hidden"))
          )
          "has-sidebar-page"
        )
      }}

      <details class="shell-prototype-controls">
        <summary>{{i18n "page_shell_prototype.title"}}</summary>
        <div class="shell-prototype-controls__fields">
          <label>
            {{i18n "page_shell_prototype.width"}}
            <select
              name="width"
              value={{this.pageShellPrototype.width}}
              {{on "change" this.pageShellPrototype.change}}
            >
              <option
                selected={{eq this.pageShellPrototype.width "centered"}}
                value="centered"
              >{{i18n "page_shell_prototype.centered"}}</option>
              <option
                selected={{eq this.pageShellPrototype.width "full"}}
                value="full"
              >{{i18n "page_shell_prototype.full"}}</option>
            </select>
          </label>
          <label>
            {{i18n "page_shell_prototype.navigation"}}
            <select
              name="navigation"
              value={{this.pageShellPrototype.navigation}}
              {{on "change" this.pageShellPrototype.change}}
            >
              <option
                selected={{eq this.pageShellPrototype.navigation "open"}}
                value="open"
              >{{i18n "page_shell_prototype.open"}}</option>
              <option
                selected={{eq this.pageShellPrototype.navigation "rail"}}
                value="rail"
              >{{i18n "page_shell_prototype.rail"}}</option>
              <option
                selected={{eq this.pageShellPrototype.navigation "hidden"}}
                value="hidden"
              >{{i18n "page_shell_prototype.hidden"}}</option>
            </select>
          </label>
          <label>
            {{i18n "page_shell_prototype.navigation_width"}}
            <input
              max="480"
              min="200"
              name="navigationWidth"
              type="range"
              value={{this.pageShellPrototype.navigationWidth}}
              {{on "input" this.pageShellPrototype.change}}
            />
            <output>{{this.pageShellPrototype.navigationWidth}}</output>
          </label>
          <label>
            {{i18n "page_shell_prototype.context"}}
            <select
              disabled={{not this.pageShellPrototype.hasContextPanel}}
              name="context"
              value={{this.pageShellPrototype.context}}
              {{on "change" this.pageShellPrototype.change}}
            >
              <option
                selected={{eq this.pageShellPrototype.context "open"}}
                value="open"
              >{{i18n "page_shell_prototype.open"}}</option>
              <option
                selected={{eq this.pageShellPrototype.context "rail"}}
                value="rail"
              >{{i18n "page_shell_prototype.rail"}}</option>
              <option
                selected={{eq this.pageShellPrototype.context "hidden"}}
                value="hidden"
              >{{i18n "page_shell_prototype.hidden"}}</option>
            </select>
          </label>
          <label>
            {{i18n "page_shell_prototype.context_width"}}
            <input
              max="480"
              min="200"
              name="contextWidth"
              type="range"
              value={{this.pageShellPrototype.contextWidth}}
              {{on "input" this.pageShellPrototype.change}}
            />
            <output>{{this.pageShellPrototype.contextWidth}}</output>
          </label>
          <label>
            {{i18n "page_shell_prototype.footer"}}
            <select
              name="footer"
              value={{this.pageShellPrototype.footer}}
              {{on "change" this.pageShellPrototype.change}}
            >
              <option
                selected={{eq this.pageShellPrototype.footer "content"}}
                value="content"
              >{{i18n "page_shell_prototype.under_content"}}</option>
              <option
                selected={{eq this.pageShellPrototype.footer "row"}}
                value="row"
              >{{i18n "page_shell_prototype.full_row"}}</option>
              <option
                selected={{eq this.pageShellPrototype.footer "off"}}
                value="off"
              >{{i18n "page_shell_prototype.hidden"}}</option>
            </select>
          </label>
        </div>
      </details>

      <div
        class="page-shell-prototype"
        data-context={{if
          this.pageShellPrototype.hasContextPanel
          this.pageShellPrototype.context
          "hidden"
        }}
        data-footer={{this.pageShellPrototype.footer}}
        data-navigation={{if
          @sidebarEnabled
          this.pageShellPrototype.navigation
          "hidden"
        }}
        data-width={{this.pageShellPrototype.width}}
        {{measurePageShellPrototype
          this.pageShellPrototype.width
          this.pageShellPrototype.navigation
          this.pageShellPrototype.context
          this.pageShellPrototype.navigationWidth
          this.pageShellPrototype.contextWidth
        }}
      >
        {{yield to="beforeHeader"}}
        {{yield to="header"}}
        <div class="page-shell-prototype__before-body">
          {{yield to="beforeBody"}}
        </div>
        <div class="wrap" id="main-outlet-wrapper">
          {{yield to="body"}}
          {{#if
            (and
              this.pageShellPrototype.hasContextPanel
              (not (eq this.pageShellPrototype.context "hidden"))
            )
          }}
            <div class="page-shell-prototype__context-slot">
              <aside
                aria-label={{i18n "page_shell_prototype.context"}}
                class="page-shell-prototype__context"
              >
                {{#if (eq this.pageShellPrototype.context "rail")}}
                  <button
                    class="btn btn-flat"
                    title={{i18n "page_shell_prototype.expand_context"}}
                    type="button"
                    {{on "click" this.pageShellPrototype.openContext}}
                  >
                    {{i18n "page_shell_prototype.expand"}}
                  </button>
                {{else}}
                  <h2>{{i18n "page_shell_prototype.context"}}</h2>
                  <p>{{i18n "page_shell_prototype.context_description"}}</p>
                {{/if}}
              </aside>
            </div>
          {{/if}}
          <div class="page-shell-prototype__footer">
            <div class="page-shell-prototype__footer-content">
              {{yield to="footer"}}
              {{#if @showFooter}}
                <div class="page-shell-prototype__footer-sample">
                  {{i18n "page_shell_prototype.footer_description"}}
                </div>
              {{/if}}
            </div>
          </div>
        </div>
      </div>
    {{else}}
      {{yield to="beforeHeader"}}
      {{yield to="header"}}
      {{yield to="beforeBody"}}
      <div class="wrap" id="main-outlet-wrapper" role="main">
        {{yield to="body"}}
      </div>
      {{yield to="footer"}}
    {{/if}}
  </template>
}
