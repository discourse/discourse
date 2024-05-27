import Component from "@glimmer/component";
import { assert } from "@ember/debug";
import { fn, hash } from "@ember/helper";
import { action, get } from "@ember/object";
import Label from "form-kit/components/label";
import concatClass from "discourse/helpers/concat-class";
import uniqueId from "discourse/helpers/unique-id";
import FormInput from "./input";

export default class FormErrors extends Component {
  <template>
    {{log "FormErrors" @id @errors}}
    <div id={{@id}} aria-live="assertive" ...attributes>
      {{#if (has-block)}}
        {{yield @errors}}
      {{else}}
        {{#each @errors as |e|}}
          {{#if e.message}}
            {{e.message}}<br />
          {{/if}}
        {{/each}}
      {{/if}}
    </div>
  </template>
}
