import { tracked } from "@glimmer/tracking";
import { action, computed } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import DiscourseURL from "discourse/lib/url";
import ComboBoxComponent from "discourse/select-kit/components/combo-box";
import {
  pluginApiIdentifiers,
  selectKitOptions,
} from "discourse/select-kit/components/select-kit";

@classNames("tag-dropdown")
@selectKitOptions({
  caretDownIcon: "caret-down",
  caretUpIcon: "caret-up",
  filterable: true,
})
@pluginApiIdentifiers("tag-dropdown")
export default class TagDropdown extends ComboBoxComponent {
  valueProperty = "name";
  nameProperty = "name";

  @tracked _contentOverride;

  @computed("tags")
  get content() {
    if (this._contentOverride !== undefined) {
      return this._contentOverride;
    }
    return this.tags;
  }

  set content(value) {
    this._contentOverride = value;
  }

  @computed("tags.[]")
  get tagNames() {
    return (this.tags || []).map((t) => t.name);
  }

  @action
  onChange(tagName) {
    const tag = this.tags?.find((t) => t.name === tagName);
    if (tag) {
      DiscourseURL.routeToUrl(`/tag/${tag.name}/${tag.id}/edit/general`);
    }
  }
}
