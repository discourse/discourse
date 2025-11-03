import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { htmlSafe } from "@ember/template";
import { block } from "discourse/blocks";
import CategoryLogo from "discourse/components/category-logo";
import categoryLink from "discourse/helpers/category-link";
import Category from "discourse/models/category";

@block("featured-categories")
export default class BlockFeaturedCategories extends Component {
  @tracked categoryIds = this.args.categoryIds || [];

  @tracked featuredCategories = this.categoryIds.map((id) =>
    Category.findById(Number(id))
  );

  <template>
    <div class="block-featured-categories">
      <div class="block-featured-categories__container">

        <div class="block-featured-categories__list-container">
          {{#each this.featuredCategories as |category|}}
            <div class="block-featured-categories__category-container">
              <a
                class="block-featured-categories__category-link"
                href={{category.url}}
              >
                {{#if category.uploaded_logo.url}}
                  <CategoryLogo @category={{category}} />
                {{/if}}
                <h3 class="category-name">
                  {{categoryLink category}}
                </h3>
                <span class="category-description">{{htmlSafe
                    category.description_excerpt
                  }}</span>
              </a>
            </div>
          {{/each}}
        </div>
      </div>
    </div>
  </template>
}
