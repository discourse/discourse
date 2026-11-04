declare module "discourse/admin/models/admin-user" {
  interface AdminUserFields {
    /** Only sent for eligible bots viewed by admins while chat is enabled. */
    chat_discoverable?: boolean;
  }
}

export {};
