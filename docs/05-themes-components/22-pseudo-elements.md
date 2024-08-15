---
title: Insert text or images anywhere on your site using CSS pseudo-elements
short_title: Pseudo-elements
id: pseudo-elements

---
So, you want to insert some text or image in your Discourse site.

Regarding the text in most cases it is sufficient to modify it from `/admin/customize/site_texts`.
Sometimes, however, it is our desire to add a sentence between two distinct blocks, rather than modifying one of the existing elements.

Let's see how to do it using the property `:before` and `:after` in CSS3.

### Basic steps
1. In order to work we will need to use the developer console present on the main browsers. To open it, just press F12.

    ![image|690x317,70%](/assets/pseudo-elements-1.png)  

2. Select the element where, `before` or `after`, you want to add text. 

    ![chooseelements|690x315,70%](/assets/pseudo-elements-2.gif) 

    As you can see, every time the mouse passes on an element it will be highlighted and the corresponding class will be automatically selected on HTML and CSS on the right. Before editing the Discourse stylesheet, do a live test, so after choosing the element on which to operate just click the :heavy_plus_sign: icon. These will add a new rule to the CSS that we can modify according to our needs. 

3. Start to edit. Add the suffix `:before` or `:after` to the class, and add a text using the `content` property. 

    Adding an image is a bit more complicated if you do not know the CSS, but it is good practice to follow a similar pattern:

       background-image: url(url-goes-here);
       background-repeat: no-repeat;
       background-size: your-value;
       content: ""
       width: your-value;
       height: your-value;
       display: inline-block 

   Before:

     ![image|690x318,70%](/assets/pseudo-elements-3.png) 

    And after:

    ![image|690x318,70%](/assets/pseudo-elements-4.png) 

    Remember that the text will appear wherever the specific class you have selected is used. Sometimes you need to specify on which element you want the new text to appear, adding the parent element to the CSS.

4. Customize it. Knowing a bit about CSS it is easy to customize the style of the text as you want.

    ![image|690x185,70%](/assets/pseudo-elements-5.png) 
 
       .fancy-title::after {
            content: "ANOTHER TEXT ""\f072";
            color: violet;
            font-family: Fontawesome;
            background: linear-gradient(to right, #7ce5df 27%,#f1da36 100%);
            font-size: 18px;
            padding: 2px 4px;
            border: 1px solid;
        }

5. Once satisfied, add your changes to the CSS of your site by [creating a theme component](https://meta.discourse.org/t/developer-s-guide-to-discourse-themes/93648).

----------------------

We proceed with some practical examples:

- **Topic Title**

    For some sites it may be useful to add an image, a banner or a personalized advertisement **before**  or **after** the title or each post.

    ![image|597x500,70%](/assets/pseudo-elements-6.jpeg) 

      #topic-title::before {
        background-image: url(your-URL-here);
        background-repeat: no-repeat;
        background-size: 750px 335px;
        width: 750px;
        height: 335px;
        display: inline-block;
        content: "";
      }

      #topic-title::after {
        background-image: url(your-URL-here);
        background-repeat: no-repeat;
        background-size: 800px 295px;
        width: 800px;
        height: 295px;
        display: inline-block;
        content: "";
      }

- **Topic Body**

   ![image|554x500,70%](/assets/pseudo-elements-7.png) 

        .topic-body.clearfix::before {
            background-image: url(your-URL-here);
            max-height: 2.8571em;
            width: 690px;
            height: 184px;
            background-size: auto 2.8571em;
            background-repeat: no-repeat;
            margin-left: 11px;
            margin-bottom: 0.25em;
        }

    Or **after**:

    ![image|483x500,70%](/assets/pseudo-elements-8.png) 

    Just change  `.topic-body.clearfix::before` to  `.topic-body.clearfix::after`. 
    In the same way, it is possible to add a plain text `before` or `after`:

      .topic-body.clearfix::before  { 
        content: "DISCOURSE ROCKS!";
        color: red;
        font-weight: bold;
        padding-left: 11px;
       }

    ![image|646x500,70%](/assets/pseudo-elements-9.png)  

    ![image|626x500,70%](/assets/pseudo-elements-10.png) 

- **Post Buttons**

    ![image|690x315,70%](/assets/pseudo-elements-11.png) 

    ![image|690x322,70%](/assets/pseudo-elements-12.png) 
   
      .nav.post-controls .actions::before {
        color: red;
        content: "Hello from Discourse";
    }

- **Timeline**

    ![image|248x500,70%](/assets/pseudo-elements-13.png)  

      .topic-timeline::before {
        color: red;
        content: "Hello World";
      }

      .topic-timeline::after {
        color: red;
        content: "Hello again";
      }

      .timeline-scroller-content::before {
        color: violet;
        content: "Hey,";
      }

       .timeline-scroller-content::after {
        color: violet;
        content: "It's me again!";
      }

      .timeline-container .topic-timeline .start-date::before {
        color: goldenrod;
        content: "Start Date ";
      }

      timeline-container .topic-timeline .start-date::after {
        color: goldenrod;
        content: " \f060";
        font-family: Fontawesome;
      }

      .widget-link.now-date::before {
        content: "\f061 ";
        color: burlywood;
        font-family: Fontawesome;
      }

      .widget-link.now-date::after {
        color: burlywood;
        content: " Now Date";
      }

- **Footer Buttons**

    ![image|690x185,70%](/assets/pseudo-elements-14.png) 

      #topic-footer-buttons::before {
        content: "THESE ARE FOOTER BUTTONS";
        color: indianred;
        border: 2px solid;
        padding: 3px;
      }

      #topic-footer-buttons::after {
        color: indianred;
        content: "CONTENT AFTER GO HERE";
        border: 2px solid;
      }

  In the latter case, it should be noted that the `:after` content is inserted after a text. If you do not need special customizations, it is advisable to change the original text via `/admin/customize/site_texts` instead of editing the CSS.

- **Suggested Topics**

    ![image|603x499,70%](/assets/pseudo-elements-15.png) 

      #suggested-topics::before {
        content: "";
        background-image: url(https://d11a6trkgmumsb.cloudfront.net/original/3X/1/0/101f03af29f12ea30e1226eb96a02c3ed2f6d2ef.png);
        width: 690px;
        height: 184px;
        background-size: 690px 184px;
        background-repeat: no-repeat;
        display: inline-block;
      }


      #suggested-topics::after {
        content: "";
        background-image: url(https://d11a6trkgmumsb.cloudfront.net/original/3X/1/0/101f03af29f12ea30e1226eb96a02c3ed2f6d2ef.png);
        width: 690px;
        height: 184px;
        background-size: 690px 184px;
        background-repeat: no-repeat;
        display: inline-block;
      }

- **Topic Actions**

   ![Screen Shot 2021-09-09 at 13.55.40|672x122, 75%](/assets/pseudo-elements-16.png)

    ```
    .widget-button.btn-flat.share.no-text.btn-icon::after {
        content: " Share";
    }

    .widget-button.btn-flat.toggle-like.like.no-text.btn-icon::after {
        content: " Like";
    }
    ```

Ref: https://meta.discourse.org/t/insert-text-disclaimer-anywhere-in-discourse/99009

---

> **Note:**  The pseudo-elements generated by  `::before`  and  `::after`  are [contained by the element's formatting box](https://www.w3.org/TR/CSS2/generate.html#before-after-content), and thus don't apply to  *[replaced elements](https://developer.mozilla.org/en-US/docs/Web/CSS/Replaced_element)*  such as [ `<img>` ](https://developer.mozilla.org/en-US/docs/Web/HTML/Element/img), or to [ `<br>` ](https://developer.mozilla.org/en-US/docs/Web/HTML/Element/br) elements.  Source: https://developer.mozilla.org/en-US/docs/Web/CSS/::after

In other words, this won't work for "self closed" elements that can't have child elements. It is intuitive to think the pseudo-elements are like: 

`{::before is here}<tag>text content</tag>{::after is here}`

when in reality it is 

`<tag>{::before is here}text content{::after is here}</tag>`
