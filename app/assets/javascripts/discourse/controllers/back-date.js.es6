import ModalFunctionality from 'discourse/mixins/modal-functionality';
import ObjectController from 'discourse/controllers/object';
import { categoryLinkHTML } from 'discourse/helpers/category-link';

export default ObjectController.extend(ModalFunctionality, {
    needs: ["topic"],
    post: null,

    _forwardAction(name) {
        const date = this.get('dateValue');
        const time = this.get('timeValue');
        const dateTime = date + ' ' + time ;
        this.get("controllers.topic").send(name, this.get('model'), dateTime);
        this.send("closeModal");
    },

    actions: {
        backDatePost() {this._forwardAction("changeTimeStamp")}
    }

});
