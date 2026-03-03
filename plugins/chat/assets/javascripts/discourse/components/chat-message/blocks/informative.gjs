import Element from "./element";

const Informative = <template>
  <div class="block__informative-wrapper">
    <div class="block__informative">
      {{#each @definition.elements as |elementDefinition|}}
        <div class="block__informative-item">
          <Element @definition={{elementDefinition}} />
        </div>
      {{/each}}
    </div>
  </div>
</template>;

export default Informative;
