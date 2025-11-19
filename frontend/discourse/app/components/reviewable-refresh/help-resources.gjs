import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

<template>
  <div class="review-item__resources">
    <h3 class="review-item__aside-title">{{i18n "review.need_help"}}</h3>
    <ul class="review-resources__list">
      <li class="review-resources__item">
        <span class="review-resources__icon">
          {{icon "book"}}
        </span>
        <a
          href="https://meta.discourse.org/t/-/63116"
          class="review-resources__link"
        >
          {{i18n "review.help.moderation_guide"}}
        </a>
      </li>
      <li class="review-resources__item">
        <span class="review-resources__icon">
          {{icon "book"}}
        </span>
        <a
          href="https://meta.discourse.org/t/-/123464"
          class="review-resources__link"
        >
          {{i18n "review.help.flag_priorities"}}
        </a>
      </li>
      <li class="review-resources__item">
        <span class="review-resources__icon">
          {{icon "book"}}
        </span>
        <a
          href="https://meta.discourse.org/t/-/343541"
          class="review-resources__link"
        >
          {{i18n "review.help.spam_detection"}}
        </a>
      </li>
    </ul>
  </div>
</template>
