import Element from "./element";

const Actions = <template>
  <div class="block__actions-wrapper">
    <div class="block__actions">
      {{#each @definition.elements as |elementDefinition|}}
        <div class="block__action-wrapper">
          <div class="block__action">
            <Element
              @createInteraction={{@createInteraction}}
              @definition={{elementDefinition}}
            />
          </div>
        </div>
      {{/each}}
    </div>
  </div>
</template>;

export default Actions;
