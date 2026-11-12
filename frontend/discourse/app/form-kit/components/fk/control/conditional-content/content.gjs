import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

const FKControlConditionalContentItem = <template>
  <div
    class={{dConcatClass
      "form-kit__conditional-display-content"
      (if (neq @name @activeName) "hidden")
    }}
  >
    {{yield}}
  </div>
</template>;

export default FKControlConditionalContentItem;
