import UserMenu from "discourse/components/user-menu/menu";

// Core's user menu (notifications, messages, bookmarks), opened from the user
// panel's bell. Its profile tab is behind the user's name instead.
const UserMenuPopover = <template>
  <div class="concord-user-menu">
    <UserMenu @closeUserMenu={{@close}} />
  </div>
</template>;

export default UserMenuPopover;
