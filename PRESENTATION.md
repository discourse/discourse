---
marp: true
theme: default
paginate: true
header: "Discourse: The Community Platform"
footer: "© 2025 Discourse Overview"
style: |
  section {
    background-color: #fff;
    color: #333;
  }
  h1, h2 {
    color: #0088cc;
  }
  a {
    color: #0088cc;
  }
---

<!-- _class: lead -->
# **Discourse**
## The Modern Community Platform

![bg right:40% 80%](https://www.discourse.org/a/img/discourse-logo.png)

---

# What is Discourse?

- 100% open-source community discussion platform
- Modern forum software for civilized discussion
- Designed for both small communities and large organizations
- Active development since 2013
- Combines traditional forum features with modern web capabilities

---

# Core Features

- 💬 **Discussion topics** with thread-based conversations
- ⚡️ **Real-time chat** functionality
- 🔍 **Powerful search** with advanced filtering
- 🏆 **Trust levels** and reputation system
- 📱 **Responsive design** for all devices
- 🔔 **Smart notifications** across multiple channels
- 🔧 **Extensive customization** options

---

# Architecture Overview

![bg right:50% 90%](https://i.imgur.com/L0ECpu0.png)

- **Backend**: Ruby on Rails (API)
- **Frontend**: Ember.js (SPA)
- **Database**: PostgreSQL
- **Caching**: Redis
- **Background Jobs**: Sidekiq

---

# Core Data Models

```
User ─┬─── Posts
      ├─── Topics
      └─── Groups

Topic ─┬─── Posts
       └─── Category

Category ─── Subcategories
```

- **Users**: Community members with trust levels
- **Topics**: Discussion threads containing posts
- **Posts**: Individual messages within topics
- **Categories**: Organization structure for topics
- **Groups**: Collections of users with permissions

---

# Plugin System

- Modular architecture allows extending any part of Discourse
- Each plugin has its own MVC structure
- Over 100 official plugins available
- Examples:
  - Discourse Chat Integration
  - Data Explorer (SQL analysis)
  - Discourse Solved (Q&A functionality)
  - Discourse AI (chatbots and assistants)
  - Discourse Calendar

---

# Development Environment

- Docker-based development setup
- Local development with Rails & Ember
- Comprehensive test suite (RSpec & QUnit)
- CI/CD with GitHub Actions

```bash
# Start development environment
pnpm dev
```

---

# Permission System

- **Guardian** system controls access to content
- Category and topic-level permissions
- Trust levels (0-4) determine user capabilities:
  - **TL0**: New user
  - **TL1**: Basic user
  - **TL2**: Member
  - **TL3**: Regular
  - **TL4**: Leader

---

# Mobile Experience

![bg right:40% 90%](https://i.imgur.com/t0W4mld.png)

- Fully responsive design
- Progressive Web App (PWA) support
- Mobile-optimized reading experience
- Touch-friendly interface
- Native-like performance

---

# Customization Options

- **Themes**: Complete visual customization
- **Site Settings**: 1000+ configurable options
- **API**: Full REST API for integration
- **Webhooks**: Integration with external services
- **Embedding**: Embed Discourse in other sites

---

# Official Hosting vs Self-Hosting

**Official Hosting**:
- Zero maintenance
- Automatic upgrades
- Expert support
- CDN & optimizations
- High availability

**Self-Hosting**:
- Complete control
- Custom modifications
- Data sovereignty
- Docker-based deployment

---

# Performance & Scalability

- Designed for high traffic communities
- Caching at multiple levels
- Background processing for intensive tasks
- PostgreSQL optimizations
- Redis for ephemeral data
- CDN compatibility
- High availability options for self-hosting

---

# Key Use Cases

- **Support Communities**
- **Team Discussions**
- **Public Forums**
- **Documentation & Knowledge Bases**
- **Q&A Sites**
- **Professional Communities**
- **Internal Company Communications**

---

# Real-World Examples

![bg 80%](https://i.imgur.com/Y3nj5HZ.png)

---

<!-- _class: lead -->
# Get Started with Discourse

- Official Website: [discourse.org](https://www.discourse.org/)
- GitHub Repository: [github.com/discourse/discourse](https://github.com/discourse/discourse)
- Community Forum: [meta.discourse.org](https://meta.discourse.org/)
- Documentation: [meta.discourse.org/c/documentation/56](https://meta.discourse.org/c/documentation/56)

---

<!-- _class: lead -->
# Thank You!

### Questions?