import Service, { service } from "@ember/service";
import { capitalize } from "@ember/string";
import Category from "discourse/models/category";
import { i18n } from "discourse-i18n";

const STORAGE_KEY = "categoryCreationNotification";

export default class CategoryCreationNotification extends Service {
  @service router;
  @service sessionStore;
  @service toasts;

  #pending;

  remember(categoryId, type, { reload }) {
    const notification = { categoryId, typeName: type?.title ?? type?.name };

    if (reload) {
      try {
        this.sessionStore.setObject({ key: STORAGE_KEY, value: notification });
      } catch {
        // Category creation still succeeds when browser storage is unavailable.
      }
    } else {
      this.#pending = notification;
    }
  }

  showForCategory(category) {
    const notification = this.#takeNotification(category.id);
    if (!notification) {
      return;
    }

    const { typeName } = notification;
    this.toasts.success({
      duration: "extra-long",
      data: {
        message: typeName
          ? i18n("category.creation_success.message_with_type", {
              typeName: capitalize(typeName),
            })
          : i18n("category.creation_success.message"),
        actions: [
          {
            label: i18n("category.creation_success.edit_settings"),
            class: "btn-default",
            action: ({ close }) => {
              close();
              this.router.transitionTo(
                "editCategory.tabs",
                Category.slugFor(category),
                "general"
              );
            },
          },
          {
            label: i18n("category.creation_success.create_another"),
            class: "btn-default",
            action: ({ close }) => {
              close();
              this.router.transitionTo("newCategory.setup");
            },
          },
        ],
      },
    });
  }

  #takeNotification(categoryId) {
    if (this.#pending?.categoryId === categoryId) {
      const notification = this.#pending;
      this.#pending = undefined;
      return notification;
    }

    try {
      const notification = this.sessionStore.getObject(STORAGE_KEY);
      if (notification?.categoryId === categoryId) {
        this.sessionStore.removeItem(STORAGE_KEY);
        return notification;
      }
    } catch {
      // Category navigation still works when browser storage is unavailable.
    }
  }
}
