import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";

// Temporary controls for exercising the shell's layout states.
export default class PageShellControls extends Component {
  @service pageShell;

  <template>
    <details class="page-shell-controls">
      <summary>{{i18n "page_shell.title"}}</summary>
      <div class="page-shell-controls__fields">
        <label>
          {{i18n "page_shell.width"}}
          <select
            name="width"
            value={{this.pageShell.width}}
            {{on "change" this.pageShell.change}}
          >
            <option
              selected={{eq this.pageShell.width "centered"}}
              value="centered"
            >{{i18n "page_shell.centered"}}</option>
            <option
              selected={{eq this.pageShell.width "full"}}
              value="full"
            >{{i18n "page_shell.full"}}</option>
          </select>
        </label>
        <label>
          {{i18n "page_shell.resize"}}
          <select
            name="resize"
            value={{this.pageShell.resize}}
            {{on "change" this.pageShell.change}}
          >
            <option
              selected={{eq this.pageShell.resize "content"}}
              value="content"
            >{{i18n "page_shell.resize_content"}}</option>
            <option
              selected={{eq this.pageShell.resize "grow"}}
              value="grow"
            >{{i18n "page_shell.resize_grow"}}</option>
          </select>
        </label>
        <label>
          {{i18n "page_shell.navigation"}}
          <select
            name="navigation"
            value={{this.pageShell.navigation}}
            {{on "change" this.pageShell.change}}
          >
            <option
              selected={{eq this.pageShell.navigation "open"}}
              value="open"
            >{{i18n "page_shell.open"}}</option>
            <option
              selected={{eq this.pageShell.navigation "rail"}}
              value="rail"
            >{{i18n "page_shell.rail"}}</option>
            <option
              selected={{eq this.pageShell.navigation "hidden"}}
              value="hidden"
            >{{i18n "page_shell.hidden"}}</option>
          </select>
        </label>
        <label>
          {{i18n "page_shell.navigation_width"}}
          <input
            max="400"
            min="200"
            name="navigationWidth"
            type="range"
            value={{this.pageShell.navigationWidth}}
            {{on "input" this.pageShell.change}}
            {{on "change" this.pageShell.change}}
          />
          <output>{{this.pageShell.navigationWidth}}</output>
        </label>
        <label>
          {{i18n "page_shell.context"}}
          <select
            disabled={{not this.pageShell.hasContextPanel}}
            name="context"
            value={{this.pageShell.context}}
            {{on "change" this.pageShell.change}}
          >
            <option
              selected={{eq this.pageShell.context "open"}}
              value="open"
            >{{i18n "page_shell.open"}}</option>
            <option
              selected={{eq this.pageShell.context "hidden"}}
              value="hidden"
            >{{i18n "page_shell.hidden"}}</option>
          </select>
        </label>
        <label>
          {{i18n "page_shell.context_width"}}
          <input
            max={{this.pageShell.contextMaxWidth}}
            min="200"
            name="contextWidth"
            type="range"
            value={{this.pageShell.effectiveContextWidth}}
            {{on "input" this.pageShell.change}}
            {{on "change" this.pageShell.change}}
          />
          <output>{{this.pageShell.effectiveContextWidth}}</output>
        </label>
        <label>
          {{i18n "page_shell.footer"}}
          <select
            name="footer"
            value={{this.pageShell.footer}}
            {{on "change" this.pageShell.change}}
          >
            <option
              selected={{eq this.pageShell.footer "content"}}
              value="content"
            >{{i18n "page_shell.under_content"}}</option>
            <option
              selected={{eq this.pageShell.footer "row"}}
              value="row"
            >{{i18n "page_shell.full_row"}}</option>
            <option
              selected={{eq this.pageShell.footer "off"}}
              value="off"
            >{{i18n "page_shell.hidden"}}</option>
          </select>
        </label>
      </div>
    </details>
  </template>
}
