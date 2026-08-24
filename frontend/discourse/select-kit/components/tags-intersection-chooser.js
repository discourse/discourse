import { action } from "@ember/object";
import { attributeBindings, classNames } from "@ember-decorators/component";
import { makeArray } from "discourse/lib/helpers";
import { originalTagName, tagPath } from "discourse/lib/tag-identity";
import DiscourseURL from "discourse/lib/url";
import MiniTagChooser from "discourse/select-kit/components/mini-tag-chooser";
import { pluginApiIdentifiers } from "discourse/select-kit/components/select-kit";

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
    const mainTag = this.mainTag;
    // Intersection routes are filtered by name server-side, so a localized
    // `name` cannot be used to build them.
    const mainTagName = mainTag && originalTagName(mainTag);
    const tagNames = tags.map((t) => originalTagName(t));

    if (mainTagName && tagNames.includes(mainTagName)) {
      const remainingTags = tagNames.filter((t) => t !== mainTagName);

      if (remainingTags.length >= 1) {
        DiscourseURL.routeTo(
          `/tags/intersection/${mainTagName}/${remainingTags.join("/")}`
        );
      } else {
        DiscourseURL.routeTo(tagPath(mainTag));
      }
    } else {
      if (tagNames.length >= 2) {
        DiscourseURL.routeTo(`/tags/intersection/${tagNames.join("/")}`);
      } else if (tagNames.length === 1) {
        DiscourseURL.routeTo(tagPath(tags[0]));
      } else {
        DiscourseURL.routeTo("/tags");
      }
    }
  }
}
