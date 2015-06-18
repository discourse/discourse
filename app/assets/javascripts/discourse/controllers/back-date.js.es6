import ModalFunctionality from 'discourse/mixins/modal-functionality';
import ObjectController from 'discourse/controllers/object';

export default ObjectController.extend(ModalFunctionality, {
    content: {},
    needs: ["topic"],


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
