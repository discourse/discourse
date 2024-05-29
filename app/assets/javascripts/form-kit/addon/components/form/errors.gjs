import Component from "@glimmer/component";

export default class FormErrors extends Component {
  <template>
    <div id={{@id}} aria-live="assertive" ...attributes>
      {{#if (has-block)}}
        {{yield @errors}}
      {{else}}
        {{#each @errors as |e|}}
          {{#if e}}
            {{e}}<br />
          {{/if}}
        {{/each}}
      {{/if}}
    </div>
  </template>
}
