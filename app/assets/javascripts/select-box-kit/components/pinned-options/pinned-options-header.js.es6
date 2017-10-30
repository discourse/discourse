import DropdownSelectBoxHeaderComponent from "select-box-kit/components/dropdown-select-box/dropdown-select-box-header";
import computed from "ember-addons/ember-computed-decorators";
import { iconHTML } from 'discourse-common/lib/icon-library';

export default DropdownSelectBoxHeaderComponent.extend({
  classNames: "pinned-options-header",

  pinnedGlobally: Ember.computed.alias("options.pinnedGlobally"),
  pinned: Ember.computed.alias("options.pinned"),

  @computed("pinned", "pinnedGlobally")
  icon(pinned, pinnedGlobally) {
    const globally = pinnedGlobally ? "_globally" : "";
    const state = pinned ? `pinned${globally}` : "unpinned";

    return iconHTML(
      "thumb-tack",
      { class: (state === "unpinned" ? "unpinned" : null) }
    );
  },

  @computed("pinned", "pinnedGlobally")
  selectedName(pinned, pinnedGlobally) {
    const globally = pinnedGlobally ? "_globally" : "";
    const state = pinned ? `pinned${globally}` : "unpinned";
    const title = I18n.t(`topic_statuses.${state}.title`);

    return `${title}${iconHTML("caret-down")}`.htmlSafe();
  },
});
