import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";

@tagName("h3")
export default class CategoryTitleLink extends Component {}

// icon name defined on prototype so it can be easily overridden in theme components
CategoryTitleLink.prototype.lockIcon = "lock";
