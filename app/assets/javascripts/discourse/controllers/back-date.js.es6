import ModalFunctionality from 'discourse/mixins/modal-functionality';
import ObjectController from 'discourse/controllers/object';
import { categoryLinkHTML } from 'discourse/helpers/category-link';

export default ObjectController.extend(ModalFunctionality, {
    needs: ["topic"],

    loading: true,
    post: null,
    pinnedGloballyCount: 0,
    bannerCount: 0,

    categoryLink: function() {
        return categoryLinkHTML(this.get("model.category"), { allowUncategorized: true });
    }.property("model.category"),

    unPinMessage: function() {
        return this.get("model.pinned_globally") ?
            I18n.t("topic.feature_topic.unpin_globally") :
            I18n.t("topic.feature_topic.unpin", { categoryLink: this.get("categoryLink") });
    }.property("categoryLink", "model.pinned_globally"),

    pinMessage: function() {
        return I18n.t("topic.feature_topic.pin", { categoryLink: this.get("categoryLink") });
    }.property("categoryLink"),

    alreadyPinnedMessage: function() {
        return I18n.t("topic.feature_topic.already_pinned", { categoryLink: this.get("categoryLink"), count: this.get("pinnedInCategoryCount") });
    }.property("categoryLink", "pinnedInCategoryCount"),

    onShow() {
    },

    _forwardAction(name) {
        const date = document.getElementById('date').value;
        const time = document.getElementById('time').value;
        const dateTime = date + ' ' + time ;
        this.get("controllers.topic").send(name, this.get('model'), dateTime);
        this.send("closeModal");
    },

    _confirmBeforePinning(count, name, action) {
        if (count < 4) {
            this._forwardAction(action);
        } else {
            this.send("hideModal");
            bootbox.confirm(
                I18n.t("topic.feature_topic.confirm_" + name, { count: count }),
                I18n.t("no_value"),
                I18n.t("yes_value"),
                    confirmed => confirmed ? this._forwardAction(action) : this.send("reopenModal")
            );
        }
    },

    actions: {
        backDatePost() {this._forwardAction("changeTimeStamp")}
    }

});
