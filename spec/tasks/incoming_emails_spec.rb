# frozen_string_literal: true

RSpec.describe "incoming emails tasks" do
  describe "email with attachment" do
    fab!(:incoming_email) { Fabricate(:incoming_email, raw: email(:attached_txt_file)) }

    it "updates record" do
      expect { invoke_rake_task("incoming_emails:truncate_long") }.to change {
        incoming_email.reload.raw
      }
    end
  end

  describe "short email without attachment" do
    fab!(:incoming_email) { Fabricate(:incoming_email, raw: email(:html_reply)) }

    it "does not update record" do
      expect { invoke_rake_task("incoming_emails:truncate_long") }.not_to change {
        incoming_email.reload.raw
      }
    end
  end
end
