import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import I18n from "I18n";

export default class SubmitDealForm extends Component {
  @tracked title = "";
  @tracked body = "";
  @tracked originalPrice = "";
  @tracked currentPrice = "";
  @tracked dealUrl = "";
  @tracked storeName = "";
  @tracked couponCode = "";
  @tracked expiryDate = "";
  @tracked categoryId = "";
  @tracked tags = [];
  @tracked imageUrl = "";
  @tracked description = "";
  @tracked isSubmitting = false;
  
  @tracked validationErrors = [];
  
  get discountPercentage() {
    const original = parseFloat(this.originalPrice);
    const current = parseFloat(this.currentPrice);
    if (!original || !current || original <= current) return 0;
    return Math.round(((original - current) / original) * 100);
  }
  
  get isValid() {
    return (
      this.title.trim().length > 0 &&
      this.dealUrl.trim().length > 0 &&
      this.originalPrice.length > 0 &&
      this.currentPrice.length > 0 &&
      this.categoryId.length > 0 &&
      this.validationErrors.length === 0
    );
  }
  
  @action
  validateForm() {
    this.validationErrors = [];
    
    if (this.title.trim().length < 10) {
      this.validationErrors.push(I18n.t("tangyzen.deals.validation.title_too_short"));
    }
    
    if (!this.dealUrl.match(/^https?:\/\/.+/)) {
      this.validationErrors.push(I18n.t("tangyzen.deals.validation.invalid_url"));
    }
    
    const original = parseFloat(this.originalPrice);
    const current = parseFloat(this.currentPrice);
    
    if (!original || !current) {
      this.validationErrors.push(I18n.t("tangyzen.deals.validation.invalid_prices"));
    }
    
    if (current >= original) {
      this.validationErrors.push(I18n.t("tangyzen.deals.validation.current_must_be_lower"));
    }
    
    if (this.expiryDate) {
      const expiry = new Date(this.expiryDate);
      if (expiry <= new Date()) {
        this.validationErrors.push(I18n.t("tangyzen.deals.validation.expiry_in_past"));
      }
    }
  }
  
  @action
  async submitDeal() {
    this.validateForm();
    
    if (this.validationErrors.length > 0) {
      return;
    }
    
    this.isSubmitting = true;
    
    try {
      const dealData = {
        title: this.title,
        body: this.body || this.description,
        original_price: parseFloat(this.originalPrice),
        current_price: parseFloat(this.currentPrice),
        discount_percentage: this.discountPercentage,
        deal_url: this.dealUrl,
        store_name: this.storeName,
        coupon_code: this.couponCode,
        expiry_date: this.expiryDate || null,
        image_url: this.imageUrl,
        category_id: parseInt(this.categoryId),
        tag_names: this.tags
      };
      
      const result = await ajax("/tangyzen/deals", {
        method: "POST",
        data: dealData
      });
      
      // Success!
      this.resetForm();
      
      // Show success message
      this.appEvents.trigger("flash-message", {
        type: "success",
        message: I18n.t("tangyzen.deals.submitted_successfully")
      });
      
      // Navigate to the created topic
      if (result.topic_id) {
        window.location.href = `/t/${result.topic_id}`;
      }
      
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.isSubmitting = false;
    }
  }
  
  @action
  resetForm() {
    this.title = "";
    this.body = "";
    this.originalPrice = "";
    this.currentPrice = "";
    this.dealUrl = "";
    this.storeName = "";
    this.couponCode = "";
    this.expiryDate = "";
    this.categoryId = "";
    this.tags = [];
    this.imageUrl = "";
    this.description = "";
    this.validationErrors = [];
  }
  
  @action
  addTag(tag) {
    if (tag && !this.tags.includes(tag)) {
      this.tags = [...this.tags, tag];
    }
  }
  
  @action
  removeTag(tag) {
    this.tags = this.tags.filter(t => t !== tag);
  }
  
  @action
  cancel() {
    this.args.closeModal?.();
  }
}
