import bodyClass from "discourse/helpers/body-class";
import hideApplicationFooter from "discourse/helpers/hide-application-footer";
import hideScrollableContent from "discourse/helpers/hide-scrollable-content";
import DFlashMessage from "discourse/ui-kit/d-flash-message";
import { i18n } from "discourse-i18n";
import BlogReview from "../components/blog-review.gjs";

export default <template>
  {{bodyClass "blog-review-page"}}
  {{hideApplicationFooter}}
  {{hideScrollableContent "above"}}
  {{hideScrollableContent "below"}}
  {{#if @model.unavailable}}
    <DFlashMessage @flash={{i18n "blog.review.unavailable"}} @type="error" />
  {{else}}
    <BlogReview @review={{@model}} />
  {{/if}}
</template>
