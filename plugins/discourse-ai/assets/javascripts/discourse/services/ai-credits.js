import Service, { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { getAiCreditLimitMessage } from "../lib/ai-errors";

/**
 * Service for checking AI credit status across features.
 * Caching is handled server-side via Discourse.cache and HTTP cache headers.
 *
 * @class AiCreditsService
 */
export default class AiCredits extends Service {
  @service currentUser;

  // Only used for deduplicating concurrent in-flight requests
  #pendingRequests = new Map();

  /**
   * Check credit status for specific persona IDs.
   *
   * @param {number[]} personaIds - Array of persona IDs to check
   * @returns {Promise<Object>} - Credit status keyed by persona_id
   */
  async checkPersonaCredits(personaIds) {
    const result = await this.#fetchStatus({ persona_ids: personaIds });
    return result.personas || {};
  }

  /**
   * Check credit status for specific features.
   *
   * @param {string[]} featureNames - Array of feature names
   * @returns {Promise<Object>} - Credit status keyed by feature name
   */
  async checkFeatureCredits(featureNames) {
    const result = await this.#fetchStatus({ features: featureNames });
    return result.features || {};
  }

  /**
   * Check if a specific persona has credits available.
   *
   * @param {number} personaId - The persona ID to check
   * @returns {Promise<boolean>} - True if credits are available
   */
  async isPersonaCreditAvailable(personaId) {
    const result = await this.checkPersonaCredits([personaId]);
    const status = result[personaId];
    return status?.credit_status?.available ?? true;
  }

  /**
   * Check if a specific feature has credits available.
   *
   * @param {string} featureName - The feature name to check
   * @returns {Promise<boolean>} - True if credits are available
   */
  async isFeatureCreditAvailable(featureName) {
    const result = await this.checkFeatureCredits([featureName]);
    const status = result[featureName];
    return status?.credit_status?.available ?? true;
  }

  /**
   * Get detailed credit status for a persona.
   *
   * @param {number} personaId - The persona ID
   * @returns {Promise<Object|null>} - Full credit status object or null
   */
  async getPersonaCreditStatus(personaId) {
    const result = await this.checkPersonaCredits([personaId]);
    return result[personaId]?.credit_status || null;
  }

  /**
   * Get detailed credit status for a feature.
   *
   * @param {string} featureName - The feature name
   * @returns {Promise<Object|null>} - Full credit status object or null
   */
  async getFeatureCreditStatus(featureName) {
    const result = await this.checkFeatureCredits([featureName]);
    return result[featureName]?.credit_status || null;
  }

  /**
   * Check credit status for specific LLM model IDs.
   *
   * @param {number[]} llmModelIds - Array of LLM model IDs to check
   * @returns {Promise<Object>} - Credit status keyed by llm_model_id
   */
  async checkLlmModelCredits(llmModelIds) {
    const result = await this.#fetchStatus({ llm_model_ids: llmModelIds });
    return result.llm_models || {};
  }

  /**
   * Get detailed credit status for an LLM model.
   *
   * @param {number} llmModelId - The LLM model ID
   * @returns {Promise<Object|null>} - Full credit status object or null
   */
  async getLlmModelCreditStatus(llmModelId) {
    const result = await this.checkLlmModelCredits([llmModelId]);
    return result[llmModelId]?.credit_status || null;
  }

  /**
   * Get error message for credit limit based on user type.
   * Returns a raw string - wrap with htmlSafe() if needed for templates.
   *
   * @param {Object} creditStatus - Credit status object with reset times
   * @returns {string} - Localized error message
   */
  getCreditLimitMessage(creditStatus) {
    const resetTime =
      creditStatus?.reset_time_relative || creditStatus?.reset_time_formatted;

    return getAiCreditLimitMessage({
      resetTime,
      isAdmin: this.currentUser?.admin,
    });
  }

  /**
   * Fetches credit status from the API with request deduplication.
   * Automatically cleans up pending requests when complete or on error.
   * Caching is handled server-side via Discourse.cache and HTTP cache headers.
   *
   * @private
   * @param {Object} params - Request parameters
   * @param {number[]} [params.persona_ids] - Array of persona IDs to check
   * @param {string[]} [params.features] - Array of feature names to check
   * @param {number[]} [params.llm_model_ids] - Array of LLM model IDs to check
   * @returns {Promise<Object>} Promise resolving to credit status object
   */
  async #fetchStatus(params) {
    const cacheKey = JSON.stringify(params);

    // Deduplicate concurrent in-flight requests
    if (this.#pendingRequests.has(cacheKey)) {
      return this.#pendingRequests.get(cacheKey);
    }

    const request = ajax("/discourse-ai/credits/status", {
      type: "GET",
      data: params,
    })
      .then((result) => {
        this.#pendingRequests.delete(cacheKey);
        return result;
      })
      .catch((error) => {
        this.#pendingRequests.delete(cacheKey);
        throw error;
      });

    this.#pendingRequests.set(cacheKey, request);
    return request;
  }
}
