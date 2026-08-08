import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { trustHTML } from "@ember/template";
import { modifier } from "ember-modifier";
import { or } from "discourse/truth-helpers";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import openLinksInNewTab from "discourse/plugins/discourse-calendar/discourse/modifiers/open-links-in-new-tab";

export default class DiscoursePostEventDescription extends Component {
  @tracked expanded = false;
  @tracked overflowing = false;

  detectOverflow = modifier((element) => {
    const check = () => {
      const textEl = element.querySelector(".event-description__text");
      if (textEl) {
        this.overflowing = textEl.scrollHeight > textEl.clientHeight;
      }
    };

    const observer = new ResizeObserver(check);
    observer.observe(element);

    return () => observer.disconnect();
  });

  toggle = (event) => {
    event.preventDefault();
    this.expanded = !this.expanded;
  };

  get showToggle() {
    return this.clamp && (this.overflowing || this.expanded);
  }

  get clamp() {
    return this.args.clamp ?? false;
  }

  get toggleLabel() {
    return this.expanded
      ? i18n("discourse_post_event.event_description.show_less")
      : i18n("discourse_post_event.event_description.show_more");
  }

  <template>
    {{#if (or @descriptionHtml @description)}}
      <section
        class="event__section event-description
          {{if this.clamp 'is-clamped'}}
          {{if this.expanded 'is-expanded'}}"
      >
        {{dIcon "file-lines"}}

        <div
          class="event-description__content"
          {{(if this.clamp this.detectOverflow)}}
        >
          <div
            class="event-description__text"
            {{openLinksInNewTab @descriptionHtml}}
          >
            {{#if @descriptionHtml}}
              {{trustHTML @descriptionHtml}}
            {{else}}
              {{@description}}
            {{/if}}
          </div>
          {{#if this.showToggle}}
            <a
              href
              class="event-description__toggle"
              {{on "click" this.toggle}}
            >{{this.toggleLabel}}</a>
          {{/if}}
        </div>
      </section>
    {{/if}}
  </template>
}
