import Component from "@glimmer/component";
import { htmlSafe } from "@ember/template";
import { block } from "discourse/blocks";
import DButton from "discourse/components/d-button";

// eslint-disable-next-line ember/no-empty-glimmer-component-classes
@block("banner")
export default class BlockBanner extends Component {
  <template>
    <div class="block-banner__container">
      <div class="block-banner__contents">
        {{#if @title}}
          <h2 class="block-banner__title">
            {{htmlSafe @title}}</h2>
        {{/if}}
        {{#if @subtitle}}
          <span class="block-banner__subtitle">{{htmlSafe @subtitle}}</span>
        {{/if}}
      </div>
      {{#if @buttonLink}}
        <div class="block-banner__button">
          <DButton
            class="btn-primary"
            @icon={{@buttonIcon}}
            @href={{@buttonLink}}
            @translatedLabel={{@buttonLabel}}
          />
        </div>
      {{/if}}

    </div>
  </template>
}
