import concatClass from "discourse/helpers/concat-class";

const MenuPanel = <template>
  <div
    class={{concatClass "menu-panel" @panelClass @animationClass}}
    data-max-width="500"
  >
    <div class="panel-body">
      <div class="panel-body-contents">
        {{yield}}
      </div>
    </div>
  </div>
</template>;
export default MenuPanel;
