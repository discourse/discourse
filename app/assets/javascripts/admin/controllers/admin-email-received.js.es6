import AdminEmailIncomingsController from 'admin/controllers/admin-email-incomings';
import debounce from 'discourse/lib/debounce';
import IncomingEmail from 'admin/models/incoming-email';

export default AdminEmailIncomingsController.extend({
  filterIncomingEmails: debounce(function() {
    IncomingEmail.findAll(this.get("filter")).then(incomings => this.set("model", incomings));
  }, 250).observes("filter.{from,to,subject}")
});
