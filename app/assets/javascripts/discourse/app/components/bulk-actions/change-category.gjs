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

<p>{{i18n "topics.bulk.choose_new_category"}}</p>

<p>
  <CategoryChooser
    @value={{this.categoryId}}
    @onChange={{fn (mut this.categoryId)}}
  />
</p>

<ConditionalLoadingSpinner @condition={{@loading}}>
  <DButton
    @action={{this.changeCategory}}
    @label="topics.bulk.change_category"
  />
</ConditionalLoadingSpinner>