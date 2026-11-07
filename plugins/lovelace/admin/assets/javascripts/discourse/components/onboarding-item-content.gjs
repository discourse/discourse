import { Input } from "@ember/component";
import { on } from "@ember/modifier";

export default <template>
  <div class="lovelace-onboarding__item" ...attributes>
    {{#if @onToggle}}
      <label class="lovelace-onboarding__item-title">
        <Input
          @checked={{@checked}}
          @type="checkbox"
          {{on "change" @onToggle}}
        />
        <strong>{{@item.title}}</strong>
      </label>
    {{else}}
      <strong class="lovelace-onboarding__item-title">{{@item.title}}</strong>
    {{/if}}
    <p>{{@item.description}}</p>
  </div>
</template>
