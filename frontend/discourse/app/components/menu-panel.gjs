const MenuPanel = <template>
  <div class="menu-panel" data-max-width="500" ...attributes>
    <div class="panel-body">
      <div class="panel-body-contents">
        {{yield}}
      </div>
    </div>
  </div>
</template>;

export default MenuPanel;
