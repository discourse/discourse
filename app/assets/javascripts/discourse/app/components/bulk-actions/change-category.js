import Component from "@glimmer/component";
import { action } from "@ember/object";

export default class ChangeCategory extends Component {
  categoryId = 0;

  @action
  async changeCategory() {
    await this.args.forEachPerformed(
      {
        type: "change_category",
        category_id: this.categoryId,
      },
      (t) => t.set("category_id", this.categoryId)
    );
  }
}
