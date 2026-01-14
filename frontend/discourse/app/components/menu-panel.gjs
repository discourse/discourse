const MenuPanel = <template>
  <div data-max-width="500" class="menu-panel" ...attributes>
    <div class="panel-body">
      <div class="panel-body-contents">
        {{yield}}
      </div>
    </div>
  </div>
</template>;

export default MenuPanel;
