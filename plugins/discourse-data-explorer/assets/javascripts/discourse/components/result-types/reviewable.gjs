import { LinkTo } from "@ember/routing";

const Reviewable = <template>
  {{#let (reviewableId @ctx.value) as |id|}}
    {{#if id}}
      <LinkTo @model={{id}} @route="review.show">{{@ctx.value}}</LinkTo>
    {{else}}
      {{@ctx.value}}
    {{/if}}
  {{/let}}
</template>;

export default Reviewable;

function reviewableId(value) {
  if (typeof value !== "number" && typeof value !== "string") {
    return null;
  }

  const id = Number(value);
  return Number.isSafeInteger(id) && id > 0 ? id : null;
}
