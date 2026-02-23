import { action } from "@ember/object";
import { attributeBindings, classNames } from "@ember-decorators/component";
import { makeArray } from "discourse/lib/helpers";
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
    const mainTagName = mainTag?.name;
    const tagNames = tags.map((t) => t.name ?? t);

    if (mainTagName && tagNames.includes(mainTagName)) {
      const remainingTags = tagNames.filter((t) => t !== mainTagName);

      if (remainingTags.length >= 1) {
        DiscourseURL.routeTo(
          `/tags/intersection/${mainTagName}/${remainingTags.join("/")}`
        );
      } else if (mainTag.id) {
        const slug = mainTag.slug || `${mainTag.id}-tag`;
        DiscourseURL.routeTo(`/tag/${slug}/${mainTag.id}`);
      } else {
        DiscourseURL.routeTo(`/tag/${mainTagName}`);
      }
    } else {
      if (tagNames.length >= 2) {
        DiscourseURL.routeTo(`/tags/intersection/${tagNames.join("/")}`);
      } else if (tagNames.length === 1) {
        DiscourseURL.routeTo(`/tag/${tagNames[0]}`);
      } else {
        DiscourseURL.routeTo("/tags");
      }
    }
  }
}
