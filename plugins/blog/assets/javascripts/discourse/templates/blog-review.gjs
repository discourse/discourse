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
  {{#if @model.publishedUrl}}
    <section class="blog-review__published">
      <h1 class="blog-review__published-title">{{i18n
          "blog.review.published_title"
        }}</h1>
      <p class="blog-review__published-body">{{i18n
          "blog.review.published_body"
        }}</p>
      <a
        class="btn btn-primary blog-review__published-link"
        href={{@model.publishedUrl}}
      >{{i18n "blog.review.read_article"}}</a>
    </section>
  {{else if @model.unavailable}}
    <DFlashMessage @flash={{i18n "blog.review.unavailable"}} @type="error" />
  {{else}}
    <BlogReview @review={{@model}} />
  {{/if}}
</template>
