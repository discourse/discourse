import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import { discourseModule, exists } from "discourse/tests/helpers/qunit-helpers";
import Category from "discourse/models/category";
import Topic from "discourse/models/topic";
import hbs from "htmlbars-inline-precompile";

const createArgs = (topic) => {
  return {
    topic,
    openUpwards: "true",
    toggleMultiSelect: () => {},
    deleteTopic: () => {},
    recoverTopic: () => {},
    toggleClosed: () => {},
    toggleArchived: () => {},
    toggleVisibility: () => {},
    showTopicTimerModal: () => {},
    showFeatureTopic: () => {},
    showChangeTimestamp: () => {},
    resetBumpDate: () => {},
    convertToPublicTopic: () => {},
    convertToPrivateMessage: () => {},
  };
};

discourseModule(
  "Integration | Component | Widget | topic-admin-menu-button",
  function (hooks) {
    setupRenderingTest(hooks);

    componentTest("topic-admin-menu-button is present for admin/moderators", {
      template: hbs`{{mount-widget widget="topic-admin-menu-button" args=args}}`,

      beforeEach() {
        this.currentUser.setProperties({
          admin: true,
          moderator: true,
          id: 123,
        });
        const topic = Topic.create({ user_id: this.currentUser.id });
        topic.set("category_id", Category.create({ read_restricted: true }).id);
        this.siteSettings.allow_featured_topic_on_user_profiles = true;
        this.set("args", createArgs(topic));
      },

      test(assert) {
        assert.ok(exists(".toggle-admin-menu"), "admin wrench is present");
      },
    });

    componentTest(
      "topic-admin-menu-button hides for non-admin when there is no action",
      {
        template: hbs`{{mount-widget widget="topic-admin-menu-button" args=args}}`,

        beforeEach() {
          this.currentUser.setProperties({
            admin: false,
            moderator: false,
            id: 123,
          });
          const topic = Topic.create({ user_id: this.currentUser.id });
          topic.set(
            "category_id",
            Category.create({ read_restricted: true }).id
          );
          this.siteSettings.allow_featured_topic_on_user_profiles = true;
          this.set("args", createArgs(topic));
        },

        test(assert) {
          assert.ok(
            !exists(".toggle-admin-menu"),
            "admin wrench is not present"
          );
        },
      }
    );
  }
);
