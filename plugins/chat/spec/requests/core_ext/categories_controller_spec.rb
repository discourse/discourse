# frozen_string_literal: true

RSpec.describe CategoriesController do
  describe "#destroy" do
    subject(:destroy_category) { delete "/categories/#{category.slug}.json" }

    fab!(:admin)
    fab!(:category) { Fabricate(:category, user: admin) }
    fab!(:user)

    context "when staff deletes a category without a channel" do
      before { sign_in(admin) }

      it "deletes the category" do
        expect { destroy_category }.to change { Category.count }.by(-1)
      end
    end

    context "when staff deletes a category with a channel" do
      let!(:channel) { Fabricate(:category_channel, chatable: category) }

      before { sign_in(admin) }

      context "when channel has no messages" do
        it "deletes the category" do
          expect { destroy_category }.to change { Category.count }.by(-1)
        end

        it "deletes the associated channel" do
          expect { destroy_category }.to change { Chat::CategoryChannel.count }.by(-1)
        end
      end

      context "when channel has messages" do
        before { Fabricate(:chat_message, chat_channel: channel) }

        it "does not delete the category" do
          expect { destroy_category }.not_to change { Category.count }
          expect(response).to be_forbidden
        end
      end
    end

    context "when a non-staff user deletes a category without a channel" do
      before { sign_in(user) }

      it "does not delete the category" do
        expect { destroy_category }.not_to change { Category.count }
        expect(response).to be_forbidden
      end
    end

    context "when a non-staff user deletes a category with a channel" do
      let!(:channel) { Fabricate(:category_channel, chatable: category) }

      before { sign_in(user) }

      context "when channel has no messages" do
        it "does not delete the category" do
          expect { destroy_category }.not_to change { Category.count }
          expect(response).to be_forbidden
        end
      end

      context "when channel has messages" do
        before { Fabricate(:chat_message, chat_channel: channel) }

        it "does not delete the category" do
          expect { destroy_category }.not_to change { Category.count }
          expect(response).to be_forbidden
        end
      end
    end
  end
end
