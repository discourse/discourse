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
          (and @sidebarEnabled (not (eq this.pageShellPrototype.left "hidden")))
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
            {{i18n "page_shell_prototype.left"}}
            <select
              name="left"
              value={{this.pageShellPrototype.left}}
              {{on "change" this.pageShellPrototype.change}}
            >
              <option
                selected={{eq this.pageShellPrototype.left "open"}}
                value="open"
              >{{i18n "page_shell_prototype.open"}}</option>
              <option
                selected={{eq this.pageShellPrototype.left "rail"}}
                value="rail"
              >{{i18n "page_shell_prototype.rail"}}</option>
              <option
                selected={{eq this.pageShellPrototype.left "hidden"}}
                value="hidden"
              >{{i18n "page_shell_prototype.hidden"}}</option>
            </select>
          </label>
          <label>
            {{i18n "page_shell_prototype.left_width"}}
            <input
              max="480"
              min="200"
              name="leftWidth"
              type="range"
              value={{this.pageShellPrototype.leftWidth}}
              {{on "input" this.pageShellPrototype.change}}
            />
            <output>{{this.pageShellPrototype.leftWidth}}</output>
          </label>
          <label>
            {{i18n "page_shell_prototype.right"}}
            <select
              disabled={{not this.pageShellPrototype.hasRightPanel}}
              name="right"
              value={{this.pageShellPrototype.right}}
              {{on "change" this.pageShellPrototype.change}}
            >
              <option
                selected={{eq this.pageShellPrototype.right "open"}}
                value="open"
              >{{i18n "page_shell_prototype.open"}}</option>
              <option
                selected={{eq this.pageShellPrototype.right "rail"}}
                value="rail"
              >{{i18n "page_shell_prototype.rail"}}</option>
              <option
                selected={{eq this.pageShellPrototype.right "hidden"}}
                value="hidden"
              >{{i18n "page_shell_prototype.hidden"}}</option>
            </select>
          </label>
          <label>
            {{i18n "page_shell_prototype.right_width"}}
            <input
              max="480"
              min="200"
              name="rightWidth"
              type="range"
              value={{this.pageShellPrototype.rightWidth}}
              {{on "input" this.pageShellPrototype.change}}
            />
            <output>{{this.pageShellPrototype.rightWidth}}</output>
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
        data-footer={{this.pageShellPrototype.footer}}
        data-left={{if @sidebarEnabled this.pageShellPrototype.left "hidden"}}
        data-right={{if
          this.pageShellPrototype.hasRightPanel
          this.pageShellPrototype.right
          "hidden"
        }}
        data-width={{this.pageShellPrototype.width}}
        style={{this.pageShellPrototype.style}}
        {{measurePageShellPrototype
          this.pageShellPrototype.width
          this.pageShellPrototype.left
          this.pageShellPrototype.right
          this.pageShellPrototype.leftWidth
          this.pageShellPrototype.rightWidth
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
              this.pageShellPrototype.hasRightPanel
              (not (eq this.pageShellPrototype.right "hidden"))
            )
          }}
            <div class="page-shell-prototype__right-slot">
              <aside
                aria-label={{i18n "page_shell_prototype.right"}}
                class="page-shell-prototype__right"
              >
                {{#if (eq this.pageShellPrototype.right "rail")}}
                  <button
                    class="btn btn-flat"
                    title={{i18n "page_shell_prototype.expand_right"}}
                    type="button"
                    {{on "click" this.pageShellPrototype.openRight}}
                  >
                    {{i18n "page_shell_prototype.expand"}}
                  </button>
                {{else}}
                  <h2>{{i18n "page_shell_prototype.right"}}</h2>
                  <p>{{i18n "page_shell_prototype.right_description"}}</p>
                {{/if}}
              </aside>
            </div>
          {{/if}}
          <div class="page-shell-prototype__footer">
            {{yield to="footer"}}
            {{#if @showFooter}}
              <div class="page-shell-prototype__footer-sample">
                {{i18n "page_shell_prototype.footer_description"}}
              </div>
            {{/if}}
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
