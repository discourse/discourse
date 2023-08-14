import DefaultNavigation from "./default";
import { inject as service } from "@ember/service";

export default class NavigationCategories extends DefaultNavigation {
  @service composer;
}
