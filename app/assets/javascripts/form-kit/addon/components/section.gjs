import concatClass from "discourse/helpers/concat-class";

const Section = <template>
  <div
    class={{concatClass
      "d-form__section"
      (if @node.context.horizontal "--landcaspe")
    }}
  >
    {{yield}}
  </div>
</template>;

export default Section;
