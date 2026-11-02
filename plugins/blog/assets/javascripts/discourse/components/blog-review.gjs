import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DFlashMessage from "discourse/ui-kit/d-flash-message";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class BlogReview extends Component {
  @tracked submitted = false;
  @tracked unavailable = false;

  get expiresAt() {
    return moment(this.args.review.expires_at).format(
      i18n("dates.long_with_year_no_time")
    );
  }

  get article() {
    // The server freezes and sanitizes this HTML when the editor issues the grant.
    return trustHTML(this.args.review.cooked);
  }

  @action
  async submit(data) {
    try {
      await ajax("/blog/review/feedback.json", {
        type: "POST",
        data: { review_token: this.args.review.token, feedback: data },
      });
      this.submitted = true;
    } catch (error) {
      if ([403, 404].includes(error.jqXHR?.status)) {
        this.unavailable = true;
      } else {
        popupAjaxError(error);
        throw error;
      }
    }
  }

  <template>
    <section class="blog-review">
      {{#if this.unavailable}}
        <DFlashMessage
          @flash={{i18n "blog.review.unavailable"}}
          @type="error"
        />
      {{else}}
        <div class="blog-review__banner">
          <span class="blog-review__badge">
            {{dIcon "file-lines"}}
            {{i18n "blog.review.reader_badge" version=@review.post_version}}
          </span>
          <span class="blog-review__expiry">
            {{dIcon "clock"}}
            {{i18n "blog.review.expires" date=this.expiresAt}}
          </span>
        </div>
        <article>
          <h1>{{@review.title}}</h1>
          <div class="blog-review__article cooked">{{this.article}}</div>
        </article>
        <section class="blog-review__feedback">
          <h2>{{i18n "blog.review.leave_feedback"}}</h2>
          {{#if this.submitted}}
            <DFlashMessage
              @flash={{i18n "blog.review.thanks"}}
              @type="success"
            />
          {{else}}
            <p>{{i18n "blog.review.feedback_privacy"}}</p>
            <Form @onSubmit={{this.submit}} as |form|>
              <form.Field
                @format="full"
                @name="message"
                @title={{i18n "blog.review.message"}}
                @type="textarea"
                @validation="required"
                as |field|
              ><field.Control maxlength="10000" @rows={{6}} /></form.Field>
              <form.Field
                @format="full"
                @name="name"
                @title={{i18n "blog.review.name"}}
                @type="input"
                as |field|
              ><field.Control
                  autocomplete="name"
                  maxlength="100"
                /></form.Field>
              <form.Field
                @format="full"
                @name="email"
                @title={{i18n "blog.review.email"}}
                @type="input"
                as |field|
              ><field.Control
                  autocomplete="email"
                  maxlength="254"
                  @type="email"
                /></form.Field>
              <form.Actions><form.Submit
                  @label="blog.review.send_feedback"
                /></form.Actions>
            </Form>
          {{/if}}
        </section>
      {{/if}}
    </section>
  </template>
}
