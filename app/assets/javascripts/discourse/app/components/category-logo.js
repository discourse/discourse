import Component from "@glimmer/component";
import { inject as service } from "@ember/service";

export default class CategoryLogo extends Component {
  @service session;

  get defaultCategoryLogo() {
    // use dark logo by default in edge case
    // when scheme is dark and dark logo is present
    if (
      this.session.defaultColorSchemeIsDark &&
      this.args.category.uploaded_logo_dark
    ) {
      return this.args.category.uploaded_logo_dark;
    }

    return this.args.category.uploaded_logo;
  }
}
