import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";

class Tab {
  @tracked selected;

  constructor(title, content, selected) {
    this.title = title;
    this.content = content;
    this.selected = selected;
  }
}

export default class MarkdownTabs extends Component {
  @tracked tabs;

  constructor() {
    super(...arguments);
    this.tabs = this.args.tabs.map((tab) => {
      return new Tab(tab.title, tab.content, tab.selected);
    });
  }

  headerClass(tab) {
    return tab.selected
      ? "markdown-tabs__header selected"
      : "markdown-tabs__header";
  }

  panelClass(tab) {
    return tab.selected
      ? "markdown-tabs__panel selected"
      : "markdown-tabs__panel";
  }

  @action
  selectTab(tab, event) {
    this.tabs.forEach((t) => (t.selected = t === tab));
    event.preventDefault();
  }

  <template>
    <div class="markdown-tabs__headers" role="tablist">
      {{#each this.tabs as |tab|}}
        <div class={{this.headerClass tab}}>
          <a href {{on "click" (fn this.selectTab tab)}}>{{tab.title}}</a>
        </div>
      {{/each}}
    </div>
    <div class="markdown-tabs__panels">
      {{#each this.tabs as |tab|}}
        <div class={{this.panelClass tab}} role="tabpanel">
          {{htmlSafe tab.content}}
        </div>
      {{/each}}
    </div>
  </template>
}
