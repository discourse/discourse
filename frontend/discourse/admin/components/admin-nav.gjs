const AdminNav = <template>
  <div class="admin-controls">
    <nav>
      <ul class="nav nav-pills">
        {{yield}}
      </ul>
    </nav>
  </div>
</template>;

export default AdminNav;
