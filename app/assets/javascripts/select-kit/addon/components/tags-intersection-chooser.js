import { action } from "@ember/object";
import { attributeBindings, classNames } from "@ember-decorators/component";
import { makeArray } from "discourse/lib/helpers";
import DiscourseURL from "discourse/lib/url";
import MiniTagChooser from "select-kit/components/mini-tag-chooser";
import { pluginApiIdentifiers } from "select-kit/components/select-kit";

@attributeBindings("selectKit.options.categoryId:category-id")
@classNames("tags-intersection-chooser")
@pluginApiIdentifiers("tags-intersection-chooser")
export default class TagsIntersectionChooser extends MiniTagChooser {
  mainTag = null;
  additionalTags = null;

  didReceiveAttrs() {
    super.didReceiveAttrs(...arguments);

    this.set(
      "value",
      makeArray(this.mainTag).concat(makeArray(this.additionalTags))
    );
  }

  @action
  onChange(tags) {
    if (tags.includes(this.mainTag)) {
      const remainingTags = tags.filter((t) => t !== this.mainTag);

      if (remainingTags.length >= 1) {
        DiscourseURL.routeTo(
          `/tags/intersection/${this.mainTag}/${remainingTags.join("/")}`
        );
      } else {
        DiscourseURL.routeTo("/tags");
      }
    } else {
      if (tags.length >= 2) {
        DiscourseURL.routeTo(`/tags/intersection/${tags.join("/")}`);
      } else {
        DiscourseURL.routeTo("/tags");
      }
    }
  }
}
