import { categoryBadgeHTML } from "discourse/helpers/category-link";
import RawHtml from "discourse/widgets/raw-html";

// Right now it's RawHTML. Eventually it should emit nodes
export default class CategoryLink extends RawHtml {
  constructor(attrs) {
    attrs.html = `<span>${categoryBadgeHTML(attrs.category, attrs)}</span>`;
    super(attrs);
  }
}
